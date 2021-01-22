#!/bin/bash

[ -f "/sbin/remount" ] && sudo remount rw openvpn || true && \

echo ">> Install common tools" && \
sudo apt-get install -y dig && \

echo ">> Stop OpenVPN UDP service" && \

sudo systemctl stop openvpn-server@server.service && \

echo ">> Modify OpenVPN server config" && \

sudo sed -i 's/ifconfig-pool-persist ipp.txt/ifconfig-pool-persist \/var\/tmp\/openvpn-ipp-udp.txt/' /etc/openvpn/server/server.conf && \
sudo sed -i 's/status openvpn-status.log/status \/var\/tmp\/openvpn-status-udp.log/' /etc/openvpn/server/server.conf && \
sudo sed -i '/local/d' /etc/openvpn/server/server.conf && \
sudo sed -i 's/server 10.8.0.0 255.255.255.0/server 10.8.0.0 255.255.255.128/' /etc/openvpn/server/server.conf && \
sudo rm -f /etc/openvpn/server/ipp.txt /etc/openvpn/server/openvpn-status.log && \

echo ">> Modify OpenVPN client config" && \

sudo sed -i '/proto udp/d' /root/client.ovpn && \
sudo sed -i '/proto udp/d' /etc/openvpn/server/client-common.txt && \
sudo sed -i "s/^remote \(.*\)/&\n& tcp-client/" /root/client.ovpn && \
sudo sed -i "s/^remote \(.*\)/&\n& tcp-client/" /etc/openvpn/server/client-common.txt && \

echo ">> Copy OpenVPN UDP server config to TCP server" && \

sudo cp /etc/openvpn/server/server.conf /etc/openvpn/server/server-tcp.conf && \
sudo sed -i 's/udp/tcp/g' /etc/openvpn/server/server-tcp.conf && \
sudo sed -i 's/server 10.8.0.0 255.255.255.128/server 10.8.0.128 255.255.255.128/' /etc/openvpn/server/server-tcp.conf && \

echo ">> Enable and start OpenVPN TCP service" && \

sudo systemctl enable --now openvpn-server@server-tcp.service && \

echo ">> Restart OpenVPN UDP service" && \

sudo systemctl start openvpn-server@server.service && \

# Not using script installed by openvpn-iptables because it is tie to the LAN IP at the time of installation
echo ">> Remove OpenVPN iptables service" && \

sudo systemctl disable --now openvpn-iptables.service && \
sudo rm -f /etc/systemd/system/openvpn-iptables.service && \

echo ">> Install iptables crontab" && \

echo "#!/bin/bash

echo ============================================== | sudo tee -a /dev/tty1 >> /var/log/iptables-cron.log
date | sudo tee -a /dev/tty1 >> /var/log/iptables-cron.log
echo ============================================== | sudo tee -a /dev/tty1 >> /var/log/iptables-cron.log

# Check interface
__IFACE=\$(route -4 | grep default | head -n 1 | awk '{print \$8}')
printf \"Interface: %s\n\" \"\$__IFACE\" | sudo tee -a /dev/tty1 >> /var/log/iptables-cron.log
[ -z \"\$__IFACE\" ] && exit

# Print the IP address
__IP=\$(ifconfig \$__IFACE | grep \"inet \" | awk '{print \$2}')
printf \"LAN IP: %s\n\" \"\$__IP\" | sudo tee -a /dev/tty1 >> /var/log/iptables-cron.log
[ -z \"\$__IP\" ] && exit

# OpenVPN
if [ -z \"\$(iptables -t nat -L | grep 10.8.0.0 | grep \$__IP)\" ]; then
  echo \"Setup iptables\" | sudo tee -a /dev/tty1 >> /var/log/iptables-cron.log
  iptables -t nat -F | sudo tee -a /dev/tty1 >> /var/log/iptables-cron.log
  iptables -t nat -A POSTROUTING -s 10.8.0.0/24 ! -d 10.8.0.0/24 -j SNAT --to \"\$__IP\" | sudo tee -a /dev/tty1 >> /var/log/iptables-cron.log
  iptables -t nat -L | sudo tee -a /dev/tty1 >> /var/log/iptables-cron.log
else
  echo \"Setup iptables skipped\" | sudo tee -a /dev/tty1 >> /var/log/iptables-cron.log
fi

echo | sudo tee -a /dev/tty1 >> /dev/null
" | sudo tee /etc/cron.hourly/iptables > /dev/null && \
sudo chmod +x /etc/cron.hourly/iptables && \

# Also make us run when dhcp renews
sudo ln -s /etc/cron.hourly/iptables /etc/dhcp/dhclient-exit-hooks.d/zzz-iptables && \

[ -f "/sbin/remount" ] && sudo remount ro openvpn || true
