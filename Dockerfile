FROM mcr.microsoft.com/powershell:latest
LABEL Name=PSSensio Version=0.0.1
COPY src/config /config
# RUN apt-get -y update && apt-get install -y curl && sh -c "/config/dotnet-install.sh"

# Update image and install Curl
RUN apt-get -y update 
RUN apt-get install -y curl

# Install dotnet for Powershell
RUN sh -c "/config/dotnet-install.sh"

# Expose Port 80 (TCP)
EXPOSE 80/tcp

CMD ["pwsh", "/config/PS-httpListner/httpListner_Sensio.ps1" ]
# sh /config/startup.sh   # same as done in RUN.

