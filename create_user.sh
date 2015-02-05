#!/bin/bash

if [ -z "$1" ] || [ -z "$2" ]; then
    echo -e "\nUsage: ./create_user.sh user password\n"
    exit 1
fi

user=$1

dest_dir=/home/ubuntu/${user}/tunnelblick
mkdir -p "$dest_dir"

pushd /etc/openvpn/easy-rsa/

source /etc/openvpn/serverinfo
source vars

./build-key $user
cp keys/${user}.crt keys/${user}.key "$dest_dir"
cp /etc/openvpn/ca.crt /etc/openvpn/ta.key "$dest_dir"
cp /usr/share/doc/openvpn/examples/sample-config-files/client.conf "$dest_dir/client.conf"

sed -i "s/^remote .*/remote $vpn_server $vpn_server_port/" "$dest_dir/client.conf"
sed -i "s/^ca .*\.crt/ca ca.crt/" "$dest_dir/client.conf"
sed -i "s/^cert .*\.crt/cert $user.crt/" "$dest_dir/client.conf"
sed -i "s/^key .*\.key/key $user.key/" "$dest_dir/client.conf"
sed -i "s/^;tls-auth/tls-auth/" "$dest_dir/client.conf"
sed -i "s/^;cipher .*/cipher AES-256-CBC/" "$dest_dir/client.conf"

echo -e "\n# Enable Multi-Factor Authentication" >> "$dest_dir/client.conf"
echo -e "auth-user-pass" >> "$dest_dir/client.conf"

echo -e "\n# Prevent the password file from being cached" >> "$dest_dir/client.conf"
echo -e "auth-nocache" >> "$dest_dir/client.conf"

echo -e "\n# Prevent re-authorization every 3600 seconds" >> "$dest_dir/client.conf"
echo -e "reneg-sec 0" >> "$dest_dir/client.conf"

popd

if [ ! -d /home/ubuntu/vpnconfigs ]; then
    mkdir -p /home/ubuntu/vpnconfigs
    chown ubuntu:ubuntu /home/ubuntu/vpnconfigs
fi

pushd /home/ubuntu/${user}
mv tunnelblick "$vpn_server_description"
zip -r /home/ubuntu/vpnconfigs/$user.tblk.zip "$vpn_server_description"
popd
rm -fr /home/ubuntu/${user}

userdel $user > /dev/null 2>&1
rm -fr /home/$user

password=$(mkpasswd $2)
useradd $user -p $password
mkdir -p /home/$user

google-authenticator -f -t -d -r 3 -R 30 -w 8 -l "${user}@${vpn_server_domain}" -s /home/$user/.google_authenticator
cp /home/ubuntu/vpnconfigs/$user.tblk.zip /home/$user

chown -R $user:$user /home/$user

cp /home/$user/.google_authenticator /home/ubuntu/vpnconfigs/$user.secret
chown ubuntu:ubuntu /home/ubuntu/vpnconfigs/$user.tblk.zip
chown ubuntu:ubuntu /home/ubuntu/vpnconfigs/$user.secret
