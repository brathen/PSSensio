##########################################################################################################
<#

FIXED:
- "Setting power state to on", a Apple HomeKit bug that always sends a value 100 after dimvalue
- Set-SensioRele now working with new functions
- Speed up read time abnormaly by reading files insted of telnet.
- errorsjekk for at det kun skal godta integer på powervalue, men ser ut til å feile noen ganger for det.
- Lagt inn Start-Sensio med catch loop, dersom den skulle tryne.. mulig blir mer robust...
- now running as a docker container

	# Help and info:
	# ---------------------------------------------------------------------------------

	# alternate you can add more to the telnet by separting the commands with comma
	# [String[]]$Commands = @("TelCom1","TelCom2","TelCom3","TelCom4"),
	
	# in one case we do the "oneline" command
	# [String[]]$Commands = @($SensioSend),

	# or as we do it, we split it up in the commands for use in functions
	# valid string to build (exapmle):   new_state 2250 100/m

	# ---------------------------------------------------------------------------------
		
		
#>
###########################################################################################################

# Startup -  setting Windows Title
# ---------------------------------------------------------------------------------------------------------
# $host.ui.RawUI.WindowTitle = "Sensio - (Homebridge)  --  HttpListner"


# Ignore all errors in a script, If error ocure, it will kill the telnet session. 
# ---------------------------------------------------------------------------------------------------------
$ErrorActionPreference = "SilentlyContinue"


# Container config path
# ---------------------------------------------------------------------------------------------------------
$ScriptRoot = "/config/PS-httpListner"
write-host $ScriptRoot

Function ConvertTo-HashTable {
# ----------------------------------------------------------------------------------------------------------------------------------------
    Param (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [Object]$InputObject,
        [string[]]$ExcludeTypeName = @("ListDictionaryInternal", "Object[]"),
        [ValidateRange(1, 10)][Int]$MaxDepth = 4
    )

    Process {

        Write-Verbose "Converting to hashtable $($InputObject.GetType())"
        $propNames = $InputObject.psobject.Properties | Select-Object -ExpandProperty Name
        $hash = @{}
        $propNames | % {
            if ($InputObject.$_ -ne $null) {
                if ($InputObject.$_ -is [string] -or (Get-Member -MemberType Properties -InputObject ($InputObject.$_) ).Count -eq 0) {
                    $hash.Add($_, $InputObject.$_)
                }
                else {
                    if ($InputObject.$_.GetType().Name -in $ExcludeTypeName) {
                        Write-Verbose "Skipped $_"
                    }
                    elseif ($MaxDepth -gt 1) {
                        $hash.Add($_, (ConvertTo-HashTable -InputObject $InputObject.$_ -MaxDepth ($MaxDepth - 1)))
                    }
                }
            }
        }
        $hash
    }
} # Function end

Function Start-HTTPListener {
# ----------------------------------------------------------------------------------------------------------------------------------------
    <#
    .Synopsis
        Creates a new HTTP Listener accepting PowerShell command line to execute
    .Description
        Creates a new HTTP Listener enabling a remote client to execute PowerShell command lines using a simple REST API.
        This function requires running from an elevated administrator prompt to open a port.

        Use Ctrl-C to stop the listener.  You'll need to send another web request to allow the listener to stop since
        it will be blocked waiting for a request.
    .Parameter Port
        Port to listen, default is 80
    .Parameter URL
        URL to listen, default is /
    .Parameter Auth
        Authentication Schemes to use, default is IntegratedWindowsAuthentication
    .Example
        Start-HTTPListener -Port 80 -Url PowerShell
        Invoke-WebRequest -Uri "http://localhost:80/PowerShell?command=get-service winmgmt&format=text" -UseDefaultCredentials | Format-List *
    #>
    
    Param (
        [Parameter()]
        [Int] $Port = 80,

        [Parameter()]
        [String] $Url = "",
        
        [Parameter()]
        [System.Net.AuthenticationSchemes] $Auth = [System.Net.AuthenticationSchemes]::IntegratedWindowsAuthentication
    )

    Process {
        $ErrorActionPreference = "Stop"

        if ($Url.Length -gt 0 -and -not $Url.EndsWith('/')) {
            $Url += "/"
        }

        $listener = New-Object System.Net.HttpListener
        $prefix = "http://*:$Port/$Url"
        $listener.Prefixes.Add($prefix)
        $listener.AuthenticationSchemes = $Auth 
        try {
            $listener.Start()
            while ($true) {
                $statusCode = 200
                Write-Warning "Note that thread is blocked waiting for a request.  After using Ctrl-C to stop listening, you need to send a valid HTTP request to stop the listener cleanly."
                Write-Warning "Sending 'exit' command will cause listener to stop immediately"
                Write-Verbose "Listening on $port..."
                $context = $listener.GetContext()
                $request = $context.Request

                if (!$request.IsAuthenticated) {
                    if (-not $request.QueryString.HasKeys()) {
                        $commandOutput = "SYNTAX: command=<string> format=[JSON|TEXT|XML|NONE|CLIXML]"
                        $Format = "TEXT"
                    }
                    else {

                        $command = $request.QueryString.Item("command")
                        if ($command -eq "exit") {
                            Write-Verbose "Received command to exit listener"
                            return
                        }

                        $Format = $request.QueryString.Item("format")
                        if ($Format -eq $Null) {
                            $Format = "JSON"
                        }

                        Write-Verbose "Command = $command"
                        Write-Verbose "Format = $Format"

                        try {
                            $script = $ExecutionContext.InvokeCommand.NewScriptBlock($command)                        
                            $commandOutput = & $script
                        }
                        catch {
                            $commandOutput = $_ | ConvertTo-HashTable
                            $statusCode = 500
                        }
                    }
                    $commandOutput = switch ($Format) {
                        TEXT { $commandOutput | Out-String ; break } 
                        JSON { $commandOutput | ConvertTo-JSON; break }
                        XML { $commandOutput | ConvertTo-XML -As String; break }
                        CLIXML { [System.Management.Automation.PSSerializer]::Serialize($commandOutput) ; break }
                        default { "Invalid output format selected, valid choices are TEXT, JSON, XML, and CLIXML"; $statusCode = 501; break }
                    }
                }

                Write-Verbose "Response:"
                if (!$commandOutput) {
                    $commandOutput = [string]::Empty
                }
                Write-Verbose $commandOutput

                $response = $context.Response
                $response.StatusCode = $statusCode
                $buffer = [System.Text.Encoding]::UTF8.GetBytes($commandOutput)

                $response.ContentLength64 = $buffer.Length
                $output = $response.OutputStream
                $output.Write($buffer, 0, $buffer.Length)
                $output.Close()
            }
        }
        finally {
            $listener.Stop()
        }
    }
} # Function end




Function Set-Sensio { 
# ----------------------------------------------------------------------------------------------------------------------------------------

    Param (
        [Parameter(ValueFromPipeline = $true)]
        [string]$ID = "$null",
        [string]$Power = "$null",
        [String[]]$Commands = @("new_state $ID $Power" ),
        [string]$RemoteHost = "$null",
        [string]$Port = "23",
        [int]$WaitTime = 250
    )
		
    # Must define CacheFile becuse AppleHomeKit always sends a value 100 after its dim value, this is a hack to get a round this.
    $CacheID = "$PSScriptRoot/Cache/$ID"

		
    # Error check if string ($Power) contains numeric value in PowerShell?
    Write-Host "Geting Power: $Power"
    IF ($Power -match "[0-9]") {


        #    # Must define CacheFile becuse AppleHomeKit always sends a value 100 after its dim value, this is a hack to get a round this.
        #    $CacheID = "$PSScriptRoot/Cache/$ID"

        # Creates Cache folder if it doesn't exist 
        $path = "$PSScriptRoot/Cache"
        If (!(test-path $path)) {
            New-Item -ItemType Directory -Force -Path $path
        }

        # Here is where the 2 sec timer swtich comes in
        $CachePower = Get-ChildItem $CacheID -ErrorAction SilentlyContinue | where { $_.LastWriteTime -Gt (get-date).AddSeconds(-2) -and -not $_.psiscontainer } | ForEach-Object { Get-Content $_ -TotalCount 1 } 


        Write-Host "---------------------------------"
        Write-Host "VERBOSE:"
        Write-Host "---------------------------------"
        Write-Host "CacheID: $CacheID"
        Write-Host "ID: $ID"
        Write-Host "CachePower: $CachePower"
        Write-Host "Power: $Power"
        Write-Host "---------------------------------"
        

        IF ($Power -eq 100 -and $CachePower -ne $null ) {
            Write-Host "IF statement running:" -ForegroundColor DarkBlue -BackgroundColor White
            Write-host "Set-Sensio: " (get-date).DateTime (get-date).Millisecond -ForegroundColor DarkBlue -BackgroundColor White
            Write-host "HomeKit sending a `"Setting power state to on`" from Homebridge for $ID" -ForegroundColor DarkBlue -BackgroundColor White
            Write-Host "Keeping the same powervalue as before and do nothing: CachePower ($CachePower)" -ForegroundColor DarkBlue -BackgroundColor White
                
            # ------------------------------------------
            # $CachePower is the Correct HERE !!
            # for speed up ReadingValue in HomeKit, the CachePower value goes back for faster lockup
            $CachePower > $CacheID
            # ------------------------------------------
        } 

        Else {
            Write-host ">-----------------------------------------------------------------" -ForegroundColor White -BackgroundColor Magenta
            Write-host "Set-Sensio: " (get-date).DateTime (get-date).Millisecond -ForegroundColor White -BackgroundColor Magenta
            Write-host "Set-Sensio Command: " $Commands -ForegroundColor White -BackgroundColor Magenta

            # Attach to the remote device, setup streaming requirements
            $Socket = New-Object System.Net.Sockets.TcpClient($RemoteHost, $Port)
            If ($Socket) {
                $Stream = $Socket.GetStream()
                $Writer = New-Object System.IO.StreamWriter($Stream)
                $Buffer = New-Object System.Byte[] 1024 
                $Encoding = New-Object System.Text.AsciiEncoding

                # Now start issuing the commands
                ForEach ($Command in $Commands) {   
                    $Writer.WriteLine($Command) 
                    $Writer.Flush()
                    Start-Sleep -Milliseconds $WaitTime
                }
                # All commands issued, but since the last command is usually going to be the longest let's wait a little longer for it to finish
                Start-Sleep -Milliseconds ($WaitTime * 3)
                $Result = ""
                #Save all the results
                While ($Stream.DataAvailable) {
                    $Read = $Stream.Read($Buffer, 0, 1024) 
                    $Result += ($Encoding.GetString($Buffer, 0, $Read))
                }
            }
            Else {   
                $Result = "Unable to connect to host: $($RemoteHost):$Port"
            }
            # ------------------------------------------
            # $Power is the Correct HERE !!
            # for speed up ReadingValue in HomeKit, the CachePower value goes back for faster lockup
            $Power > $CacheID
            # ------------------------------------------
        }

    } # Error check if ID or Power is NULL      
    Else {
        Write-host ""
        Write-host "ERROR: Set-Sensio: " (get-date).DateTime (get-date).Millisecond -ForegroundColor White -BackgroundColor Red
        Write-host "ERROR: Set-Sensio Command: " $Commands -ForegroundColor White -BackgroundColor Red
        Write-host "INFO: setting CacheID to 0"
        0 > $CacheID
				}
} # Function end



Function Get-Sensio {
# ----------------------------------------------------------------------------------------------------------------------------------------
#This is still in Bata for the Homebridge prodject, (working with powershell itself....)

    Param (
        [Parameter(ValueFromPipeline = $true)]
        [string]$ID = "$null",
        [String[]]$Commands = @("status $ID" ),
        [string]$RemoteHost = "$null",
        [string]$Port = "23",
        [int]$WaitTime = 250
    )

    Write-host ">-----------------------------------------------------------------" -ForegroundColor Black -BackgroundColor Green
    Write-host "Get-Sensio: " (get-date).DateTime (get-date).Millisecond -ForegroundColor Black -BackgroundColor Green
    Write-host "Get-Sensio Command: " $Commands -ForegroundColor Black -BackgroundColor Green


    # DIRTY WORKAROUND TO SPEED UP THE READ PROCESS, USING THE CACHE_ID TO GET VALUE IF NOT USED FOR A WHILE
    $CacheID = "$PSScriptRoot/Cache/$ID"

    # Creates Cache folder if it doesn't exist 
    $path = "$PSScriptRoot/Cache"
    If (!(test-path $path)) {
        New-Item -ItemType Directory -Force -Path $path
    }

    # Here is where the 120 MIN timer swtich comes in
    [int]$CachePower = Get-ChildItem $CacheID -ErrorAction SilentlyContinue | Where-Object { $_.LastWriteTime -Gt (get-date).AddMinutes(-120) -and -not $_.psiscontainer } | ForEach-Object { Get-Content $_ -TotalCount 1 } 
				
				# write-host $CachePower
    # Here is where the 30 SEC timer swtich comes in, FOR DEBUGGING
    # $CachePower = Get-ChildItem $CacheID -ErrorAction SilentlyContinue | Where-Object {$_.LastWriteTime -Gt (get-date).AddSeconds(-30) -and -not $_.psiscontainer} | ForEach-Object {Get-Content $_ -TotalCount 1} 
        
				## får ikke or til å spille på lag, må lage to if'er
    IF ($null -ne $CachePower) {
        IF ($CachePower -match "[0-9]") {
            Write-host "Read File"
            Write-Host $CachePower -ForegroundColor Black -BackgroundColor Gray
            Write-Output $CachePower
            # $Power = $CachePower
            # [String[]]$Commands = @("new_state $ID $Power")
        }
    } 
    Else {
        #Attach to the remote device, setup streaming requirements
        $Socket = New-Object System.Net.Sockets.TcpClient($RemoteHost, $Port)
        If ($Socket) {
            $Stream = $Socket.GetStream()
            $Writer = New-Object System.IO.StreamWriter($Stream)
            $Buffer = New-Object System.Byte[] 1024 
            $Encoding = New-Object System.Text.AsciiEncoding

            #Now start issuing the commands
            ForEach ($Command in $Commands) {   
                $Writer.WriteLine($Command) 
                $Writer.Flush()
                Start-Sleep -Milliseconds $WaitTime
            }
            #All commands issued, but since the last command is usually going to be the longest let's wait a little longer for it to finish
            Start-Sleep -Milliseconds ($WaitTime * 3)
            $Result = ""
            #Save all the results
            While ($Stream.DataAvailable) {
                $Read = $Stream.Read($Buffer, 0, 1024) 
                $Result += ($Encoding.GetString($Buffer, 0, $Read))
            }
        }
        Else {   
            $Result = "Unable to connect to host: $($RemoteHost):$Port"
        }
            

        # *********************************************************************************************************
        # Getting the State for requested ID as interger:
        $Status = $Result | Out-String


        [String]$State = $Status.Split("`n") | Select-String -pattern "$ID *" | Select-Object -first 1
        [int]$brightnesslvl = $State.Split()[-2]

                        
        # debug
        Write-Host $State -ForegroundColor Yellow


        $script:CurrentState = $brightnesslvl
        
        # Verbose Brightness level value:
        Write-host $brightnesslvl -ForegroundColor Black -BackgroundColor Gray
        Write-Output $brightnesslvl
        # *********************************************************************************************************
                
        # ------------------------------------------
        # Writing the value back for faster lockup
        $brightnesslvl > $CacheID
        # ------------------------------------------
    }

} # Function end



Function Set-SensioRele {
# ----------------------------------------------------------------------------------------------------------------------------------------

    Param (
        [Parameter(ValueFromPipeline = $true)]
        [string]$ID = "$null",
        [string]$Power = "$null",
        [String[]]$Commands = @("new_state $ID`_$Power" ),
        [string]$RemoteHost = "$null",
        [string]$Port = "23",
        [int]$WaitTime = 250
    )

    # Error check if string ($Power) contains Valid Value?
    IF ($Power -like "ON" -or $Power -like "OFF") {

        Write-host ">-----------------------------------------------------------------" -ForegroundColor White -BackgroundColor Magenta
        Write-host "Set-SensioRele: " (get-date).DateTime (get-date).Millisecond -ForegroundColor White -BackgroundColor Magenta
        Write-host "Set-SensioRele Command: " $Commands -ForegroundColor White -BackgroundColor Magenta

        # Attach to the remote device, setup streaming requirements
        $Socket = New-Object System.Net.Sockets.TcpClient($RemoteHost, $Port)
        If ($Socket) {
            $Stream = $Socket.GetStream()
            $Writer = New-Object System.IO.StreamWriter($Stream)
            $Buffer = New-Object System.Byte[] 1024 
            $Encoding = New-Object System.Text.AsciiEncoding

            # Now start issuing the commands
            ForEach ($Command in $Commands) {   
                $Writer.WriteLine($Command) 
                $Writer.Flush()
                Start-Sleep -Milliseconds $WaitTime
            }
            # All commands issued, but since the last command is usually going to be the longest let's wait a little longer for it to finish
            Start-Sleep -Milliseconds ($WaitTime * 3)
            $Result = ""
            #Save all the results
            While ($Stream.DataAvailable) {
                $Read = $Stream.Read($Buffer, 0, 1024) 
                $Result += ($Encoding.GetString($Buffer, 0, $Read))
            }
        }
        Else {   
            $Result = "Unable to connect to host: $($RemoteHost):$Port"
        }
    } # Error check if ID or Power is NULL      
    Else {
        Write-host ""
        Write-host "ERROR: Set-Sensio: " (get-date).DateTime (get-date).Millisecond -ForegroundColor White -BackgroundColor Red
        Write-host "ERROR: Set-Sensio Command: " $Commands -ForegroundColor White -BackgroundColor Red
        ##	Write-host "INFO: Remov Cache file"
        ##	0 > $CacheID
				}
} # Function end



Function Get-SensioRele {
# ----------------------------------------------------------------------------------------------------------------------------------------
#This is still in Bata for the Homebridge prodject, (working with powershell itself....)

    Param (
        [Parameter(ValueFromPipeline = $true)]
        [string]$ID = "$null",
        [String[]]$Commands = @("status $ID" ),
        [string]$RemoteHost = "$null",
        [string]$Port = "23",
        [int]$WaitTime = 250
    )

    Write-host ">-----------------------------------------------------------------" -ForegroundColor Black -BackgroundColor Green
    Write-host "Get-SensioRele: " (get-date).DateTime (get-date).Millisecond -ForegroundColor Black -BackgroundColor Green
    Write-host "Get-SensioRele Command: " $Commands -ForegroundColor Black -BackgroundColor Green


    # Attach to the remote device, setup streaming requirements
    $Socket = New-Object System.Net.Sockets.TcpClient($RemoteHost, $Port)
    If ($Socket) {
        $Stream = $Socket.GetStream()
        $Writer = New-Object System.IO.StreamWriter($Stream)
        $Buffer = New-Object System.Byte[] 1024 
        $Encoding = New-Object System.Text.AsciiEncoding

        # Now start issuing the commands
        ForEach ($Command in $Commands) {   
            $Writer.WriteLine($Command) 
            $Writer.Flush()
            Start-Sleep -Milliseconds $WaitTime
        }
        # All commands issued, but since the last command is usually going to be the longest let's wait a little longer for it to finish
        Start-Sleep -Milliseconds ($WaitTime * 3)
        $Result = ""
        #Save all the results
        While ($Stream.DataAvailable) {
            $Read = $Stream.Read($Buffer, 0, 1024) 
            $Result += ($Encoding.GetString($Buffer, 0, $Read))
        }
    }
    Else {   
        $Result = "Unable to connect to host: $($RemoteHost):$Port"
    }
    

    # *********************************************************************************************************
    # Getting the State for requested ID as interger:
    $Status = $Result | Out-String
        
    [String]$State = $Status.Split("`n") | Select-String -pattern "$ID *" | Select-Object -first 1
    [int]$brightnesslvl = $State.Split()[-3]

    # debug
    Write-Host $State -ForegroundColor Yellow

    $script:CurrentState = $brightnesslvl

    # Verbose Brightness level value:
    Write-host $brightnesslvl -ForegroundColor Black -BackgroundColor Gray
    Write-Output $brightnesslvl

    # *********************************************************************************************************

} # Function end



Function Start-Sensio {
# ----------------------------------------------------------------------------------------------------------------------------------------
    Try {
        Start-HTTPListener -Port 80 -Auth Anonymous # | Out-Null -ErrorAction SilentlyContinue
    }
    Catch {
        Start-HTTPListener -Port 80 -Auth Anonymous # | Out-Null -ErrorAction SilentlyContinue
    }
}  # Function end






##########################################################################################################################################
Start-Sensio | Out-Null -ErrorAction SilentlyContinue
##########################################################################################################################################



