# Packer project to build OpenVPN AMI

This project will build an OpenVPN AMI enabled with two factor authentication. Launch this AMI with the following user data fields separated by a ";".

* Server DNS name - the externally accessible fully qualified name of the VPN server.
* VPN port - the port over which the virtual private network connection is made.
* VPN subnet - the subnet of the virtual private network.
* VPN netmask - the netmask of the virtual private network.
* SSH password - an SSH password that can be used to SSH into the VPN server.
* VPC CIDR - the CIDR of the LAN to connect to via VPN.
* Internal LAN netmask - the netmask of the LAN.
* Domain name - the domain within which the resources are hosted.
* Organization name - a name identifying the organization the resources belong to.
* Description - a long description for the organization.
* Tunnel all traffic - a value of "yes" will configure the server to tunnel all traffic including web requests from the client.
