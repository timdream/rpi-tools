#!/bin/bash

echo country=US | sudo tee -a /mnt/sdb2/etc/wpa_supplicant/wpa_supplicant.conf > /dev/null && \

echo "network={
    ssid=\"______________\"
    psk=\"_________\"
}

network={
    ssid=\"___________\"
    psk=\"___________\"
}" | sudo tee -a /mnt/sdb2/etc/wpa_supplicant/wpa_supplicant.conf > /dev/null
