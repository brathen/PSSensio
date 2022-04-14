#!/bin/sh
echo "Configure your Container" 
## -------------------------------------------------
## entrypoint: sh /config/startup.sh
## This is for developing debugging...
## -------------------------------------------------
apt-get update 
apt-get upgrade -y 
apt-get install curl -y 
sh -c "/config/dotnet-install.sh" 
pwsh "/config/PS-httpListner/httpListner_Sensio.ps1" 
