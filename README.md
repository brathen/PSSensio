Text cleanup coming...

# Build (cd to root)
docker build .

# Build with Tag (cd to root)
docker build -t pssensio .

# List Images
docker images

# Run with image id
docker run -d -p 80:80 9b089f59fd96

# remove image
docker rmi


<#
##########################################################################################################################################
##########################################################################################################################################
# COMMAND HELP:

    $RemoteHost = "192.168.3.162"
    $ID = "D_DownlightsStue"


    # Getting the current state
    Get-Sensio -RemoteHost $RemoteHost -ID "$ID"
    Write-Host "`nCurrent State for ID: `"$ID`" is: $CurrentState" -ForegroundColor green
    
    # Flashing the lights...
    Set-Sensio -RemoteHost $RemoteHost -ID "$ID" -Power 0
    Sleep -Seconds 1
    Set-Sensio -RemoteHost $RemoteHost -ID "$ID" -Power 100
    Sleep -Seconds 1
    Set-Sensio -RemoteHost $RemoteHost -ID "$ID" -Power $CurrentState


    URL WEB TEST:
    http://localhost/?command=ipconfig
    http://192.168.3.8/?command=Set-Sensio -RemoteHost 192.168.3.162 -ID D_DownlightsStue -Power 100
    http://192.168.3.8/?command=Get-Sensio -RemoteHost 192.168.3.162 -ID D_DownlightsStue



	"on_url": "http://192.168.3.50:2222/?command=Set-Sensio -RemoteHost 192.168.3.150 -ID D_DownlightsGang -Power 100",
	"off_url": "http://192.168.3.50:2222/?command=Set-Sensio -RemoteHost 192.168.3.150 -ID D_DownlightsGang -Power 0",
	"status_url": "http://192.168.3.50:2222/?command=Get-Sensio -RemoteHost 192.168.3.150 -ID D_DownlightsGang",
	
http://192.168.3.50:2222//?command=Set-Sensio -RemoteHost 192.168.3.150 -ID D_DownlightsGang -Power 100
http://192.168.3.50:2222//?command=Set-Sensio -RemoteHost 192.168.3.150 -ID D_DownlightsGang -Power 40
http://192.168.3.50:2222//?command=Set-Sensio -RemoteHost 192.168.3.150 -ID D_DownlightsGang -Power 10
http://192.168.3.50:2222//?command=Get-Sensio -RemoteHost 192.168.3.150 -ID D_DownlightsGang


	"off_url": "http://192.168.3.50:2222//?command=Set-Sensio -RemoteHost 192.168.3.150 -ID D_DownlightsGang -Power 0",
	"status_url": "http://192.168.3.50:2222//?command=Get-Sensio -RemoteHost 192.168.3.150 -ID D_DownlightsGang",

	
	
http://192.168.3.50:2222/

    Command Web Test
    Set-Sensio -RemoteHost 192.168.3.162 -ID D_DownlightsStue -Power 100
    Get-Sensio -RemoteHost 192.168.3.162 -ID D_DownlightsStue

##########################################################################################################################################
##########################################################################################################################################
#>

