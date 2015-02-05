#!/bin/bash

apt-get -y update
apt-get install -y whois openvpn easy-rsa libpam-google-authenticator zip

service openvpn stop

hn=$(hostname)

server_info=$(curl http://169.254.169.254/latest/user-data)
vpn_server=$(echo $server_info | awk -F';' '{ print $1 }')
vpn_server_port=$(echo $server_info | awk -F';' '{ print $2 }')
vpn_subnet=$(echo $server_info | awk -F';' '{ print $3 }')
vpn_netmask=$(echo $server_info | awk -F';' '{ print $4 }')
vpn_ssh_passwd=$(echo $server_info | awk -F';' '{ print $5 }')
vpn_lan_subnet=$(echo $server_info | awk -F';' '{ print $6 }')
vpn_lan_netmask=$(echo $server_info | awk -F';' '{ print $7 }')
vpn_server_description="$(echo $server_info | awk -F';' '{ print $8 }')"
vpn_server_domain=$(echo $server_info | awk -F';' '{ print $9 }')

vpn_subnet_ip=${vpn_subnet/\/*/}
vpn_lan_subnet_ip=${vpn_lan_subnet/\/*/}

echo "export vpn_server=$vpn_server" > /etc/openvpn/serverinfo
echo "export vpn_server_port=$vpn_server_port" >> /etc/openvpn/serverinfo
echo "export vpn_server_description=\"$vpn_server_description\"" >> /etc/openvpn/serverinfo
echo "export vpn_server_domain=$vpn_server_domain" >> /etc/openvpn/serverinfo

mkdir -p /etc/openvpn/easy-rsa/
pushd /etc/openvpn/easy-rsa/

cp -r /usr/share/easy-rsa/* /etc/openvpn/easy-rsa/

sed -i 's|export KEY_COUNTRY=\".*\"|export KEY_COUNTRY="US"|' vars
sed -i 's|export KEY_PROVINCE=\".*\"|export KEY_PROVINCE="DE"|' vars
sed -i 's|export KEY_CITY=\".*\"|export KEY_CITY="Wilmington"|' vars
sed -i 's|export KEY_ORG=\".*\"|export KEY_ORG="Leapvest"|' vars
sed -i 's|export KEY_EMAIL=\".*\"|export KEY_EMAIL="support@leapvest.com"|' vars
sed -i 's|export KEY_CN=\".*\"|export KEY_CN="Leapvest_AWS_VPN"|' vars
sed -i 's|export KEY_NAME=\".*\"|export KEY_NAME="Leapvest_AWS_VPN"|' vars
sed -i 's|export KEY_OU=\".*\"|export KEY_OU="Leapvest_AWS_VPN"|' vars

for f in $(ls build*); do sed -i "s|\-\-interact ||" $f; done

source vars
./clean-all
./build-ca
./build-key-server $hn
./build-dh

cp keys/$hn.crt keys/$hn.key keys/ca.crt keys/dh2048.pem /etc/openvpn/

cp /usr/share/doc/openvpn/examples/sample-config-files/server.conf.gz /etc/openvpn/
gzip -d /etc/openvpn/server.conf.gz

openvpn --genkey --secret /etc/openvpn/ta.key

sed -i "s/^port .*/port $vpn_server_port/" /etc/openvpn/server.conf
sed -i "s/^server .*/server $vpn_subnet_ip $vpn_netmask/" /etc/openvpn/server.conf
sed -i "s/^ca .*\.crt/ca ca.crt/" /etc/openvpn/server.conf
sed -i "s/^cert .*\.crt/cert $hn.crt/" /etc/openvpn/server.conf
sed -i "s/^key .*\.key/key $hn.key/" /etc/openvpn/server.conf
sed -i "s/^dh .*\.pem/dh dh2048.pem/" /etc/openvpn/server.conf
sed -i "s/^;tls-auth/tls-auth/" /etc/openvpn/server.conf
sed -i "s/^;cipher AES-128-CBC/cipher AES-256-CBC/" /etc/openvpn/server.conf

echo -e "\n# Internal LAN" >> /etc/openvpn/server.conf
echo -e "topology subnet" >> /etc/openvpn/server.conf
echo -e "push \"route $vpn_lan_subnet_ip $vpn_lan_netmask\"" >> /etc/openvpn/server.conf

echo -e "\n# Enable Multi-Factor Authentication" >> /etc/openvpn/server.conf
echo -e "plugin /usr/lib/openvpn/openvpn-plugin-auth-pam.so openvpn" >> /etc/openvpn/server.conf

echo -e "\n# Prevent re-authorization every 3600 seconds" >> /etc/openvpn/server.conf
echo -e "reneg-sec 0" >> /etc/openvpn/server.conf

echo -e "auth required /lib/security/pam_google_authenticator.so" > /etc/pam.d/openvpn

popd

sed -i "s/^.*net.ipv4.ip_forward=.*/net.ipv4.ip_forward=1/" /etc/sysctl.conf
sed -i "s/^.*net.ipv6.conf.all.forwarding=.*/net.ipv6.conf.all.forwarding=1/" /etc/sysctl.conf
sysctl -p

# Allow traffic initiated from VPN to access LAN
iptables -I FORWARD -i tun0 -o eth0 -s $vpn_subnet -d $vpn_lan_subnet -m conntrack --ctstate NEW -j ACCEPT

# Allow traffic initiated from VPN to access "the world"
iptables -I FORWARD -i tun0 -o eth0 -s $vpn_subnet -m conntrack --ctstate NEW -j ACCEPT

# Allow traffic initiated from LAN to access "the world"
iptables -I FORWARD -i eth0 -o eth0 -s $vpn_lan_subnet -m conntrack --ctstate NEW -j ACCEPT

# Allow established traffic to pass back and forth
iptables -I FORWARD -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT

# Notice that -I is used, so when listing it (iptables -vxnL) it
# will be reversed.  This is intentional in this demonstration.

# Masquerade traffic from VPN to "the world" -- done in the nat table
iptables -t nat -I POSTROUTING -o eth0 -s $vpn_subnet -j MASQUERADE

# Masquerade traffic from LAN to "the world"
iptables -t nat -I POSTROUTING -o eth0 -s $vpn_lan_subnet -j MASQUERADE

iptables-save > /etc/openvpn/iptables-dump.ipt

cat /dev/null > /var/log/syslog
service openvpn start

password=$(mkpasswd $vpn_ssh_passwd)
usermod --password $password ubuntu

sed -i "s/# PAM configuration for the Secure Shell service/# PAM configuration for the Secure Shell service\n\nauth required \/lib\/security\/pam_google_authenticator.so/" /etc/pam.d/sshd
sed -i "s/^ChallengeResponseAuthentication .*/ChallengeResponseAuthentication yes/" /etc/ssh/sshd_config
service ssh restart

touch /root/.openvpn_installed
