#!/bin/bash

# Settings needed to restore an OpenVPN installation.
# You would put your own /etc/openvpn back first.
#
# To set up a new one, use https://github.com/Nyr/openvpn-install
# or https://github.com/timdream/openvpn-install (which is outdated and too complex)

sudo apt-get install -y miniupnpc openvpn iptables openssl ca-certificates && \
echo 'net.ipv4.ip_forward=1' | sudo tee /etc/sysctl.d/30-openvpn-forward.conf  > /dev/null && \
echo 1 | sudo tee /proc/sys/net/ipv4/ip_forward  > /dev/null && \
sudo systemctl enable openvpn@server.service && \
sudo systemctl enable openvpn@server-udp.service && \
sudo systemctl start openvpn@server.service && \
sudo systemctl start openvpn@server-udp.service
