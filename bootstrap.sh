#!/bin/bash

echo ">> Install common tools" && \
sudo apt-get update && \
sudo apt-get install -y vim wget htop lsof && \

echo ">> Set check file system after 5 mounts" && \
sudo tune2fs -c 5 "$(mount | awk '$3 == "/" {print $1}')" && \

# https://raspberrypi.stackexchange.com/questions/84390/how-to-permanently-disable-swap-on-raspbian-stretch-lite
# turn off swap
echo ">> turn off swap" && \
sudo dphys-swapfile swapoff && sudo dphys-swapfile uninstall && sudo systemctl disable dphys-swapfile && \
sudo sed -i '1!b;s/$/ noswap/' /boot/cmdline.txt && \

echo ">> Install unattended-upgrades" && \
sudo apt-get install -y unattended-upgrades && \

# Update the unattended-upgrades to what's offered upstream and add a blacklist with packages that touches /boot (always read-only).
# Fixes https://bugs.launchpad.net/raspbian/+bug/1375919
echo ">> Fix /etc/apt/apt.conf.d/50unattended-upgrades" && \
curl https://raw.githubusercontent.com/mvo5/unattended-upgrades/a41a4214/data/50unattended-upgrades.Raspbian | sudo tee /etc/apt/apt.conf.d/50unattended-upgrades > /dev/null && \
sudo sed -i '/Unattended-Upgrade::Package-Blacklist {/a\ \ \ \ // Skip packages that touches /boot\n\ \ \ \ "raspberrypi-kernel";\n\ \ \ \ "raspberrypi-bootloader";\n' /etc/apt/apt.conf.d/50unattended-upgrades && \

# Make disk readonly

echo ">> Redirect /tmp to tmpfs" && \
sudo mv /tmp /tmp- && sudo mkdir /tmp && \
sudo mount -t tmpfs -o nosuid,nodev tmpfs /tmp && \
[ ! -z "$(sudo ls -1 /tmp-)" ] && sudo mv /tmp-/* /tmp/ || true && \
[ ! -z "$(sudo ls -a1 /tmp- | grep -e "^\.[^\.]")" ] && sudo mv /tmp-/.[!.]* /tmp/ || true && \
sudo rmdir /tmp- && \
echo "tmpfs  /tmp              tmpfs  nosuid,nodev  0  0" | sudo tee -a /etc/fstab > /dev/null && \

echo ">> Redirect /var/lib/dhcp to tmpfs" && \
sudo mv /var/lib/dhcp /var/lib/dhcp- && sudo mkdir /var/lib/dhcp && \
sudo mount -t tmpfs -o nosuid,nodev tmpfs /var/lib/dhcp && \
[ ! -z "$(sudo ls -1 /var/lib/dhcp-)" ] && sudo mv /var/lib/dhcp-/* /var/lib/dhcp/ || true && \
[ ! -z "$(sudo ls -a1 /var/lib/dhcp- | grep -e "^\.[^\.]")" ] && sudo mv /var/lib/dhcp-/.[!.]* /var/lib/dhcp/ || true && \
sudo rmdir /var/lib/dhcp- && \
echo "tmpfs  /var/lib/dhcp     tmpfs  nosuid,nodev  0  0" | sudo tee -a /etc/fstab > /dev/null && \

echo ">> Redirect /var/lib/dhcpcd5 to tmpfs" && \
sudo mv /var/lib/dhcpcd5 /var/lib/dhcpcd5- && sudo mkdir /var/lib/dhcpcd5 && \
sudo mount -t tmpfs -o nosuid,nodev tmpfs /var/lib/dhcpcd5 && \
[ ! -z "$(sudo ls -1 /var/lib/dhcpcd5-)" ] && sudo mv /var/lib/dhcpcd5-/* /var/lib/dhcpcd5/ || true && \
[ ! -z "$(sudo ls -a1 /var/lib/dhcpcd5- | grep -e "^\.[^\.]")" ] && sudo mv /var/lib/dhcpcd5-/.[!.]* /var/lib/dhcpcd5/ || true && \
sudo rmdir /var/lib/dhcpcd5- && \
echo "tmpfs  /var/lib/dhcpcd5  tmpfs  nosuid,nodev  0  0" | sudo tee -a /etc/fstab > /dev/null && \

echo ">> Redirect /var/log to tmpfs (restarts rsyslog)" && \
sudo systemctl stop rsyslog.service && \
sudo mv /var/log /var/log- && sudo mkdir /var/log && \
sudo mount -t tmpfs -o nosuid,nodev tmpfs /var/log && \
[ ! -z "$(sudo ls -1 /var/log-)" ] && sudo mv /var/log-/* /var/log/ || true && \
[ ! -z "$(sudo ls -a1 /var/log- | grep -e "^\.[^\.]")" ] && sudo mv /var/log-/.[!.]* /var/log/ || true && \
sudo rmdir /var/log- && \
echo "tmpfs  /var/log          tmpfs  nosuid,nodev  0  0" | sudo tee -a /etc/fstab > /dev/null && \
sudo systemctl start rsyslog.service && \
sudo systemctl restart rsyslog.service && \

echo ">> Redirect /var/tmp to tmpfs" && \
sudo mv /var/tmp /var/tmp- && sudo mkdir /var/tmp && \
sudo mount -t tmpfs -o nosuid,nodev tmpfs /var/tmp && \
[ ! -z "$(sudo ls -1 /var/tmp-)" ] && sudo mv /var/tmp-/* /var/tmp/ || true && \
[ ! -z "$(sudo ls -a1 /var/tmp- | grep -e "^\.[^\.]")" ] && sudo mv /var/lib/dhcpcd5-/.[!.]* /var/lib/dhcpcd5/ || true && \
sudo rmdir /var/tmp- && \
echo "tmpfs  /var/tmp          tmpfs  nosuid,nodev  0  0" | sudo tee -a /etc/fstab > /dev/null && \

echo ">> Install /sbin/remount" && \
echo "#!/bin/bash

# A remount script that only set the root filesystem back to readonly
# if the tag matches. Avoid the filesystem being set to readonly
# if it was set read-write manually.

# Author: 2019 Tim Guan-tin Chien <timdream@gmail.com>

if [ -z \"\$1\" ]; then
    echo \"Usage: remount ro|rw [tag]\"
    echo -n \"Current mount options: \"
    awk '\$2 == \"/\" {print \$4}' /etc/mtab
    exit 1
fi

TAG=\${2:-user}

if awk '\$2 == \"/\" {print \$4}' /etc/mtab | grep \"\$1\" -q; then
    # Currently in the desired state.
    echo \$(date): \"\$1\" \"\$TAG\" \"<skipped (1)>\" >> /var/log/remount.log
    exit
fi

if [ \"\$1\" = \"ro\" -a ! -f \"/var/run/remount-\$TAG\" ]; then
    # Was never set to read-write under this tag.
    # Skip to prevent re-entry.
    echo \$(date): \"\$1\" \"\$TAG\" \"<skipped (2)>\" >> /var/log/remount.log
    exit
fi

mount -o remount,\"\$1\" /
ERRNO=\$?
if [ \$ERRNO != 0 ]; then
    echo \$(date): \"\$1\" \"\$TAG\" \"<failed. lsof: \$(lsof +f -- / | tail -n+2 | awk '\$4 ~ /([wu]|DEL)\$/ { print \$1 }' | uniq | xargs echo)>\" >> /var/log/remount.log
    exit \$ERRNO
fi

echo \$(date): \"\$1\" \"\$TAG\" >> /var/log/remount.log

if [ \"\$1\" = \"rw\" ]; then
    touch \"/var/run/remount-\$TAG\"
else
    rm -f \"/var/run/remount-\$TAG\"
fi
" | sudo tee /sbin/remount > /dev/null && \
sudo chmod +x /sbin/remount && \

echo ">> Set /etc/cron.hourly/fake-hwclock to use /sbin/remount" && \
sudo sed -i '/fake-hwclock save/i \ \ /sbin/remount rw fake-hwclock' /etc/cron.hourly/fake-hwclock && \
sudo sed -i '/fake-hwclock save/a \ \ /sbin/remount ro fake-hwclock' /etc/cron.hourly/fake-hwclock && \

echo ">> Set /lib/systemd/system/systemd-random-seed.service to use /sbin/remount" && \
sudo sed -i '/^ExecStop=\/lib/i ExecStop=/sbin/remount rw systemd-random-seed' /lib/systemd/system/systemd-random-seed.service && \
sudo sed -i '/^ExecStop=\/lib/a ExecStop=/sbin/remount ro systemd-random-seed' /lib/systemd/system/systemd-random-seed.service && \

echo ">> Set /lib/systemd/system/apt-daily.service to use /sbin/remount" && \
sudo sed -i '/^ExecStart=\/usr/i ExecStartPre=/sbin/remount rw apt-daily' /lib/systemd/system/apt-daily.service && \
sudo sed -i '/^ExecStart=\/usr/a ExecStartPost=/sbin/remount ro apt-daily' /lib/systemd/system/apt-daily.service && \

echo ">> Set /lib/systemd/system/apt-daily-upgrade.service to use /sbin/remount" && \
sudo sed -i '/^ExecStart=\/usr/i ExecStartPre=/sbin/remount rw apt-daily-upgrade' /lib/systemd/system/apt-daily-upgrade.service && \
sudo sed -i '/^ExecStart=\/usr/a ExecStartPost=/sbin/remount ro apt-daily-upgrade' /lib/systemd/system/apt-daily-upgrade.service && \

echo ">> Set dhclient-script to use remount" && \
echo "# This script must be sourced *before* /etc/dhcp/dhclient-enter-hooks.d/resolvconf
# This is ensured by /sbin/dhclient-script since it lists files
# with `run-parts --list /etc/dhcp/dhclient-enter-hooks.d`.

remount rw dhclient-hook
" | sudo tee /etc/dhcp/dhclient-enter-hooks.d/000-remount > /dev/null && \

echo "remount ro dhclient-hook
" | sudo tee /etc/dhcp/dhclient-exit-hooks.d/zzz-remount > /dev/null && \

sudo systemctl daemon-reload && \

echo ">> Add \"ro\" to /boot/cmdline.txt for kernel" && \
sudo sed -i '1!b;s/$/ ro/' /boot/cmdline.txt && \

echo ">> Add \"ro\" to /etc/fstab" && \
awk '$3 ~ "(ext4|vfat)"{ $4=$4",ro" }1 ' /etc/fstab | column -t > /tmp/fstab.tmp && \
cat /tmp/fstab.tmp  | sudo tee /etc/fstab > /dev/null && \
rm /tmp/fstab.tmp && \

echo ">> Set kernel to reboot upon panic" && \
echo kernel.panic = 10 | sudo tee /etc/sysctl.d/01-panic.conf > /dev/null && \

echo ">> Actually set the file system readonly" && \
sudo mount -o remount,ro /boot && \
sudo lsof +f -- / | awk '$4 ~ /([wu]|DEL)$/ { print $0 }' && \
sudo mount -o remount,ro / && \

echo ">> Done!"
