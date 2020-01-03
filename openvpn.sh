#!/bin/bash

# Settings needed to restore an OpenVPN installation.
# You would put your own /etc/openvpn back first.
#
# To set up a new one, use https://github.com/Nyr/openvpn-install
# or https://github.com/timdream/openvpn-install (which is outdated and too complex)

echo ">> Install common tools" && \
sudo apt-get install -y miniupnpc openvpn iptables openssl ca-certificates && \
echo 'net.ipv4.ip_forward=1' | sudo tee /etc/sysctl.d/30-openvpn-forward.conf  > /dev/null && \
echo 1 | sudo tee /proc/sys/net/ipv4/ip_forward  > /dev/null && \
sudo systemctl enable openvpn@server.service && \
sudo systemctl enable openvpn@server-udp.service && \
sudo systemctl start openvpn@server.service && \
sudo systemctl start openvpn@server-udp.service && \

echo ">> Install /etc/cron.hourly/vpn" && \
echo "#!/bin/bash

echo ============================================== | sudo tee -a /dev/tty1 >> /var/log/vpn.log
date | sudo tee -a /dev/tty1 >> /var/log/vpn.log
echo ============================================== | sudo tee -a /dev/tty1 >> /var/log/vpn.log

# Check interface
__IFACE=\$(route -4 | grep default | head -n 1 | awk '{print \$8}')
printf \"Interface: %s\n\" \"\$__IFACE\" | sudo tee -a /dev/tty1 >> /var/log/vpn.log
[ -z \"\$__IFACE\" ] && exit

# Print the IP address
__IP=\$(ifconfig \$__IFACE | grep \"inet \" | awk '{print \$2}')
printf \"LAN IP: %s\n\" \"\$__IP\" | sudo tee -a /dev/tty1 >> /var/log/vpn.log
[ -z \"\$__IP\" ] && exit

# Print the external IP address
__EXTERNAL_IP=\$(dig -4 @resolver1.opendns.com ANY myip.opendns.com +short)
printf \"External IP: %s\n\" \"\$__EXTERNAL_IP\" | sudo tee -a /dev/tty1 >> /var/log/vpn.log
[ -z \"\$__EXTERNAL_IP\" ] && exit

# Dynamic DNS
echo -n \"Dynamic DNS: \" >> /tmp/vpn.log
curl -s \"https://dynamicdns.park-your-domain.com/update?host=_________&domain=____________&password=___________________\" | sudo tee -a /dev/tty1 >> /var/log/vpn.log
echo | sudo tee -a /dev/tty1 >> /var/log/vpn.log

# uPnP (SSH & OpenVPN UDP + TCP)
if [[ -z \"\$(ssh-keyscan -p 8022 \$__EXTERNAL_IP 2>/dev/null)\" ]]; then
  echo \"Setup uPnP\" | sudo tee -a /dev/tty1 >> /var/log/vpn.log
  upnpc -d 8022 TCP | sudo tee -a /dev/tty1 >> /var/log/vpn.log
  upnpc -d 28022 TCP | sudo tee -a /dev/tty1 >> /var/log/vpn.log
  upnpc -d 443 TCP | sudo tee -a /dev/tty1 >> /var/log/vpn.log
  upnpc -d 1194 UDP | sudo tee -a /dev/tty1 >> /var/log/vpn.log

  upnpc -a \"\$__IP\" 22 8022 TCP | sudo tee -a /dev/tty1 >> /var/log/vpn.log
  upnpc -a \"\$__IP\" 22 28022 TCP | sudo tee -a /dev/tty1 >> /var/log/vpn.log
  upnpc -r 1194 UDP 443 TCP | sudo tee -a /dev/tty1 >> /var/log/vpn.log
fi

# OpenVPN
if [ -z \"\$(iptables -t nat -L | grep 10.8.0.0)\" ]; then
  echo \"Setup iptables\" | sudo tee -a /dev/tty1 >> /var/log/vpn.log
  iptables -t nat -A POSTROUTING -s 10.8.0.0/24 ! -d 10.8.0.0/24 -j SNAT --to \"\$__IP\" | sudo tee -a /dev/tty1 >> /var/log/vpn.log
fi

echo | sudo tee -a /dev/tty1 >> /dev/null
" | sudo tee /etc/cron.hourly/vpn > /dev/null && \
sudo chmod +x /etc/cron.hourly/vpn && \

# Insert call to /etc/cron.hourly/vpn to /etc/rc.local.
# Also, remount to read-write a bit and call resolvconf -u so we can write /etc/resolv.conf.
# sleep 10 to wait for network become ready.
sudo sed -i '/exit/i # VPN and resolv.conf\nsleep 10\n\nremount rw resolvconf\nresolvconf -u\nremount ro resolvconf\n\n/etc/cron.hourly/vpn\n' /etc/rc.local
