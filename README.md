# PSSensio - Sensio WebAPI in PowerShell


This works as a simple weblistner for running commands to control lights in Sensio Controller.
By using Homebridge plugin; homebridge-http it will integrates with Apple Home Kit.
PSSensio is listening on TCP Port 80 (http) by default, and have preloaded PowerShell functions to control Sensio Controller. PSSensio will accept common PowerShell commands as well, if that please.


PSSensio is preloaded with four functions:
* Set-Sensio (Set value of dimmer switch)
* Get-Sensio (Get value of dimmer switch)
* Set-SensioRele (Set value of rele switch)
* Get-SensioRele (Get value of rele switch)

## Command examples:

#### Get/Set-Sensio
	
    http://<IP-Adr.-RunningPSSensio>/?command=Set-Sensio -RemoteHost <IP-Adr.-SENSIOCONTROLLER> -ID D_DownlightsLightSwitch -Power 100
    http://<IP-Adr.-RunningPSSensio>/?command=Set-Sensio -RemoteHost <IP-Adr.-SENSIOCONTROLLER> -ID D_DownlightsLightSwitch -Power 0
    http://<IP-Adr.-RunningPSSensio>/?command=Get-Sensio -RemoteHost <IP-Adr.-SENSIOCONTROLLER> -ID D_DownlightsLightSwitch

#### Get/Set-SensioRelse

    http://<IP-Adr.-RunningPSSensio>/?command=Set-SensioRele -RemoteHost <IP-Adr.-SENSIOCONTROLLER> -ID B_R_ReleLight -Power ON
    http://<IP-Adr.-RunningPSSensio>/?command=Set-SensioRele -RemoteHost <IP-Adr.-SENSIOCONTROLLER> -ID B_R_ReleLight -Power OFF
    http://<IP-Adr.-RunningPSSensio>/?command=Get-SensioRele
    

!!! Do not expose PSSensio port directly out on the internet (internal use only) !!! 


## Build & Run Container:
Download the reopo and run the following command, else get it from here: https://hub.docker.com/r/5vein/pssensio

CD to root:

	docker build .

Build docker image:

	docker build -t pssensio .

Get the image id: 

	docker images

Run image by id:

	docker run -d -p 80:80 <ID from above command>
