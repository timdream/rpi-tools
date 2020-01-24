#!/bin/bash

[ -f "/sbin/remount" ] && sudo remount rw ddns || true && \

echo ">> Install /etc/cron.hourly/ddns" && \
echo "#!/bin/bash

echo ============================================== | sudo tee -a /dev/tty1 >> /var/log/ddns-crontab.log
date | sudo tee -a /dev/tty1 >> /var/log/ddns-crontab.log
echo ============================================== | sudo tee -a /dev/tty1 >> /var/log/ddns-crontab.log

# Check interface
__IFACE=\$(route -4 | grep default | head -n 1 | awk '{print \$8}')
printf \"Interface: %s\n\" \"\$__IFACE\" | sudo tee -a /dev/tty1 >> /var/log/ddns-crontab.log
[ -z \"\$__IFACE\" ] && exit

# Print the IP address
__IP=\$(ifconfig \$__IFACE | grep \"inet \" | awk '{print \$2}')
printf \"LAN IP: %s\n\" \"\$__IP\" | sudo tee -a /dev/tty1 >> /var/log/ddns-crontab.log
[ -z \"\$__IP\" ] && exit

# Print the external IP address
__EXTERNAL_IP=\$(dig -4 @208.67.222.222 ANY myip.opendns.com +short)
printf \"External IP: %s\n\" \"\$__EXTERNAL_IP\" | sudo tee -a /dev/tty1 >> /var/log/ddns-crontab.log
[ -z \"\$__EXTERNAL_IP\" ] && exit

# Dynamic DNS
if [[ \"\$(dig -4 @208.67.222.222 A _________ +short)\" != \"\$__EXTERNAL_IP\" ]]; then
  echo -n \"Dynamic DNS: \" | sudo tee -a /dev/tty1 >> /var/log/ddns-crontab.log
  curl -s \"https://dynamicdns.park-your-domain.com/update?host=_________&domain=____________&password=___________________\" | sudo tee -a /dev/tty1 >> /var/log/ddns-crontab.log
  echo | sudo tee -a /dev/tty1 >> /var/log/ddns-crontab.log
else
  echo \"Dynamic DNS skipped\" | sudo tee -a /dev/tty1 >> /var/log/ddns-crontab.log
fi

echo | sudo tee -a /dev/tty1 >> /dev/null
" | sudo tee /etc/cron.hourly/ddns > /dev/null && \
sudo chmod +x /etc/cron.hourly/ddns && \

# Also make us run when dhcp renews
sudo ln -s /etc/cron.hourly/ddns /etc/dhcp/dhclient-exit-hooks.d/zzz-ddns && \

[ -f "/sbin/remount" ] && sudo remount ro ddns || true
