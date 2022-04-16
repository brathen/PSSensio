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
	
    http://<IP-Adr.-RunningPSSensio>/?command=Set-Sensio -RemoteHost <IP-Adr.-SENSIOCONTROLLER> -ID D_<LightSwitchName> -Power 100
    http://<IP-Adr.-RunningPSSensio>/?command=Set-Sensio -RemoteHost <IP-Adr.-SENSIOCONTROLLER> -ID D_<LightSwitchName> -Power 0
    http://<IP-Adr.-RunningPSSensio>/?command=Get-Sensio -RemoteHost <IP-Adr.-SENSIOCONTROLLER> -ID D_<LightSwitchName>

#### Get/Set-SensioRelse

    http://<IP-Adr.-RunningPSSensio>/?command=Set-SensioRele -RemoteHost <IP-Adr.-SENSIOCONTROLLER> -ID B_R_<ReleLightName> -Power ON
    http://<IP-Adr.-RunningPSSensio>/?command=Set-SensioRele -RemoteHost <IP-Adr.-SENSIOCONTROLLER> -ID B_R_<ReleLightName> -Power OFF
    http://<IP-Adr.-RunningPSSensio>/?command=Get-SensioRele -RemoteHost <IP-Adr.-SENSIOCONTROLLER> -ID R_<ReleLightName>


!!! Do not expose PSSensio port directly out on the internet (internal use only) !!! 


## Usage
Download the reopo and run the following command, else get it from here: https://hub.docker.com/r/5vein/pssensio

	docker run -d --name=pssensio -p 80:80 --restart unless-stopped 5vein/pssensio

### Build&Run from GitRepo:
CD to root:

	docker build .

Build docker image:

	docker build -t pssensio .

Get the image id: 

	docker images

Run image by id:

	docker run -d -p 80:80 <ID from above command>

## homebridge-http example:

        {
            "accessory": "Http",
            "switchHandling": "yes",
            "http_method": "GET",
            "on_url": "http://10.10.10.10/?command=Set-Sensio -RemoteHost 10.10.10.11 -ID D_BedRoom -Power 100",
            "off_url": "http://10.10.10.10/?command=Set-Sensio -RemoteHost 10.10.10.11 -ID D_BedRoom -Power 0",
            "status_url": "http://10.10.10.10/?command=Get-Sensio -RemoteHost 10.10.10.11 -ID D_BedRoom",
            "service": "Light",
            "brightnessHandling": "yes",
            "brightness_url": "http://10.10.10.10/?command=Set-Sensio -RemoteHost 10.10.10.11 -ID D_BedRoom -Power %b",
            "brightnesslvl_url": "http://10.10.10.10/?command=Get-Sensio -RemoteHost 10.10.10.11 -ID D_BedRoom",
            "sendimmediately": "",
            "username": "",
            "password": "",
            "name": "Bedroom"
        },
        {
            "accessory": "Http",
            "switchHandling": "yes",
            "http_method": "GET",
            "on_url": "http://10.10.10.10/?command=Set-SensioRele -RemoteHost 10.10.10.11 -ID B_R_OutDoorWall -Power ON",
            "off_url": "http://10.10.10.10/?command=Set-SensioRele -RemoteHost 10.10.10.11 -ID B_R_OutDoorWall -Power OFF",
            "status_url": "http://10.10.10.10/?command=Get-SensioRele -RemoteHost 10.10.10.11 -ID R_OutDoorWall",
            "username": "",
            "password": "",
            "name": "Outdoor"
        }
