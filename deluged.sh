#!/bin/bash

sudo apt-get install -y deluged deluge-console &&
sudo mv /var/lib/deluged /mnt/sda1/ &&
sudo ln -sf /mnt/sda1/deluged /var/lib/deluged &&
ln -sf /mnt/sda1/deluged /home/pi/deluged &&
sudo adduser pi debian-deluged &&
sudo update-rc.d deluged disable &&
sudo sed -i s/=0/=1/ /etc/default/deluged &&
echo "#!/bin/bash

if [ ! -f /var/run/deluged.pid ]; then
  sudo mkdir -p /var/log/deluged
  sudo chmod 777 /var/log/deluged
  sudo systemctl start deluged
  sleep 5
fi

sudo -u debian-deluged deluge-console --config=/var/lib/deluged/config" > /home/pi/deluge &&
chmod +x /home/pi/deluge
