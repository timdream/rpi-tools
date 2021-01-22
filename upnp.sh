#!/bin/bash

[ -f "/sbin/remount" ] && sudo remount rw upnp || true && \

echo ">> Install miniupnpc" && \
sudo apt-get install -y miniupnpc && \

echo ">> Install /etc/cron.hourly/upnp" && \
echo "#!/bin/bash

echo ============================================== | sudo tee -a /dev/tty1 >> /var/log/upnp-crontab.log
date | sudo tee -a /dev/tty1 >> /var/log/upnp-crontab.log
echo ============================================== | sudo tee -a /dev/tty1 >> /var/log/upnp-crontab.log

# Check interface
__IFACE=\$(route -4 | grep default | head -n 1 | awk '{print \$8}')
printf \"Interface: %s\n\" \"\$__IFACE\" | sudo tee -a /dev/tty1 >> /var/log/upnp-crontab.log
[ -z \"\$__IFACE\" ] && exit

# Print the IP address
__IP=\$(ifconfig \$__IFACE | grep \"inet \" | awk '{print \$2}')
printf \"LAN IP: %s\n\" \"\$__IP\" | sudo tee -a /dev/tty1 >> /var/log/upnp-crontab.log
[ -z \"\$__IP\" ] && exit

# Print the external IP address
__EXTERNAL_IP=\$(curl -s https://api.ipify.org)
printf \"External IP: %s\n\" \"\$__EXTERNAL_IP\" | sudo tee -a /dev/tty1 >> /var/log/upnp-crontab.log
[ -z \"\$__EXTERNAL_IP\" ] && exit

# uPnP
if [[ -z \"\$(ssh-keyscan -p 8022 \$__EXTERNAL_IP 2>/dev/null)\" ]]; then
  echo \"Setup uPnP\" | sudo tee -a /dev/tty1 >> /var/log/upnp-crontab.log
  # OpenVPN and SSH
  upnpc -d 8022 TCP 28022 TCP 443 TCP 443 UDP | sudo tee -a /dev/tty1 >> /var/log/upnp-crontab.log
  upnpc -e \"ssh\" -a \"\$__IP\" 22 8022 TCP | sudo tee -a /dev/tty1 >> /var/log/upnp-crontab.log
  upnpc -e \"ssh\" -a \"\$__IP\" 22 28022 TCP | sudo tee -a /dev/tty1 >> /var/log/upnp-crontab.log
  upnpc -e \"openvpn\" -r 443 UDP 443 TCP | sudo tee -a /dev/tty1 >> /var/log/upnp-crontab.log

  # mosh
  if [[ \"\$(which mosh-server)\" ]]; then
    upnpc -d 61000 UDP 61001 UDP
    upnpc -e \"mosh\" -r 61000 UDP 61001 UDP
  fi
else
  echo \"Setup uPnP skipped\" | sudo tee -a /dev/tty1 >> /var/log/upnp-crontab.log
fi

echo | sudo tee -a /dev/tty1 >> /dev/null
" | sudo tee /etc/cron.hourly/upnp > /dev/null && \
sudo chmod +x /etc/cron.hourly/upnp && \

# Also make us run when dhcp renews
sudo ln -s /etc/cron.hourly/upnp /etc/dhcp/dhclient-exit-hooks.d/zzz-upnp && \

[ -f "/sbin/remount" ] && sudo remount ro upnp || true
