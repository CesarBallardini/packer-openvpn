# Packer project to build OpenVPN AMI

This project will build an OpenVPN AMI enabled with two factor authentication. Launch this AMI with the following user data fields separated by a ";".

* Server DNS name
* VPN port
* VPN subnet
* VPN netmask
* SSH password
* VPC CIDR
* Internal LAN netmask
* Domain name
* Organization name
* Description
