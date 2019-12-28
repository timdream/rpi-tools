# rpi-tools

My own assorted script (manual or automated) to prepare for Raspberry Pi images & to command booted up Raspberry Pi.

Likely not going to support future versions once I am done with my current project, but should be helpful for people who is looking.

## Step-by-step guide to build your own VPN service

Here are the things you need to get your device up and running.

### Step 1: Get a Raspberry Pi and SSH connection

You don’t need a fancy new model just for OpenVPN. A smaller one would work. Install [Raspbian](https://www.raspberrypi.org/downloads/raspbian/) on the SD card. You will need some way to get it to connect to network and SSH turned on.

* Check the [SSH documentation](https://www.raspberrypi.org/documentation/remote-access/ssh/) to figure out how to enable SSH including on headless configuration
* Also, [Setting up a Raspberry Pi headless](https://www.raspberrypi.org/documentation/configuration/wireless/headless.md) contain more information including setting up WiFi before the first boot.

### Step 2: Bootstrap

This part is hopefully written as a shell script, if it works. It does the following:

* Install common tools
* Turn off swap, stopping more disk writes.
* ~~Install `unattended-upgrades`, so the OS is kept up-to-date with security fixes on its own.~~ [Raspberry Pi does not offer a separate security label, there is no way to setup `unattended-upgrades` without accepting all package updates](https://www.raspberrypi.org/forums/viewtopic.php?p=1191453&sid=bb8f274806ee652e5fa8efa41f479da8#p1191453)
* Set the file system to be readonly and move all the mutable states to `tmpfs`. This is done so that an unexpected power cycle won’t corrupt the file system and prevent the device from booting up. **This is very important in order for devices that is hard to service.**
* Also installed a `remount` command-line tool for easy toggle between read-write and read-only.

To execute `bootstrap.sh` on it, run this on your terminal:

```
ssh pi@raspberrypi.local -o UserKnownHostsFile=./known_hosts bash < ./bootstrap.sh
```

where `raspberrypi.local` should be the mDNS hostname of your device in the same LAN. You are more than welcome to comment out the section that you don't need before running the script.

### Step 3: Setup OpenVPN server

We will setup two daemons so the service will be available over TCP and UDP.
To do that:

1. Run [openvpn-install](https://github.com/Nyr/openvpn-install) on the device. Choose protocol/port TCP/443.
2. Turn it off temporary with `sudo systemctl stop openvpn@server.service`.
2. Copy `/etc/openvpn/server.conf` to `/etc/openvpn/server-udp.conf`, .
3. Modify `/etc/openvpn/server-udp.conf` so that the 2nd server listens to UDP/1194.
4. Modify `server 10.8.0.0 255.255.255.0` to `server 10.8.0.0 255.255.255.128` in `/etc/openvpn/server.conf` so that TCP server gives out address starting `10.8.0.128`.
5. Modify the `status` line on both files to be `status /var/log/openvpn-status-tcp.log` and `status /var/log/openvpn-status-udp.log` so it doesn't try to write into the read-only filesystem.
6. Likewise, modify the `ifconfig-pool-persist` line to be `ifconfig-pool-persist /var/tmp/openvpn-ipp-tcp.txt` and `ifconfig-pool-persist /var/tmp/openvpn-ipp-udp.txt`.
7. Modify the line start with `remote` in `client.ovpn` to two lines, one `remote <hostname> 1194` and the other `remote <hostname> 443 tcp-client`. We will put the TCP server as the second preference because UDP is faster.

The `<hostname>` should be the hostname where the device can be reached externally. See step 4 for more detail.

`openvpn-install` is very good at setting up one-off things in the system like `iptable` rules and kernel forwarding option. I don't know if the rule will stick after reboot, but if is not, `openvpn.sh` has the same things.

Regardless, you will need `openvpn.sh` to setup the Dynamic DNS and the `systemd` script for the UDP server, and more (see below.)

### Step 4: External incoming network access

To gain access to the machine inside an ordinary home network setup, you'll need three things

1. Track the external IP via Dynamic DNS
2. Set the router IPv4 NAT to forward the incoming ports to a specific LAN IP
3. Get the device to be on that specific LAN IP

Note that even though the device may receive an IPv6 address, most home routers block all incoming IPv6 connections and there is not way to configure it otherwise. Until that changes, we will keep working with IPv4.

To setup a Dynamic DNS, you will need a Dynamic DNS service. It may be the DNS come with your domain registrar, for example [Namecheap](https://www.namecheap.com). It may be a free service where you `CNAME` your subdomain hostname to the dynamic record. You could use the hostname provided by the dyanmic DNS service directly. Regardless, you will need to figure out the URL that `curl` should hit and edit `openvpn.sh` to fill that in. The script will set it up in the crontab to run every hour.

The NAT port forwarding and LAN IP setup is substitute￼d with UPnP (Universal Plug and Play). Just ensure that UPnP is turned on on the router. The script will try to configure it every hour and forward the port listed in the script. You can skip this part if you are sure that you can achieve (2) and (3) by manually configure the router, and the router configuration will stick.

Again, modify the script and comment out the part that you don't need before execute `openvpn.sh`.

### Step 5: GitHub Gist

This part is completely optional. I have a heartbeat script living on the gist that I wish the device to run every hour. This is the way to achieve it; it's documented in `gist.sh`.

### Step 6: The client

On macOS I recommend [TunnelBlick](https://tunnelblick.net). On iOS there is [OpenVPN Connect](https://apps.apple.com/us/app/openvpn-connect/id590379981). Don't download software from unofficial source and always keep it up-to-date!

### Step 7: Verify

Reboot the device. Once it come back, you should have

1. Two OpenVPN daemon up and running. You can verify that with `sudo systemctl status openvpn@server.service` and `sudo systemctl status openvpn@server-udp.service`.
2. The system filesystem should be read-only. You can verify that by running `remount` and see if it says `Current mount options: ro` instead of `rw`.

Run `/etc/cron.hourly/vpn` on your own to trigger Dynamic DNS and UPnP update: `sudo /etc/cron.hourly/vpn`, after that you can verify that the external incomming connection works. The script saves its output at `/var/log/vpn.log`.

Do `echo /etc/cron.hourly/vpn | sudo tee -a /etc/rc.local` to have script run once upon boot, not just hourly. Noted that WiFi may not connect at that time.

To test the OpenVPN server on the TCP port, stop the UDP server and try to connect the client with it. The UDP server should timeout and the client should fallback to TCP.

**Remember to change the SSH password!**

## Usage

This part of the doc is not that useful if you read the step-by-step guide.

### bootstrap.sh

After getting your Raspberry Pi booted up and SSH turned on, do this
to execute `bootstrap.sh` on it.

```
ssh pi@raspberrypi.local -o UserKnownHostsFile=./known_hosts bash < ./bootstrap.sh
```

### openvpn.sh

Setup an OpenVPN environment. Expects two OpenVPN configs at `/etc/openvpn/server-udp.conf` and `/etc/openvpn/server.conf`. Please modify the script to add your own Dynamic DNS secret and change the assumptions before running.

```
ssh pi@raspberrypi.local -o UserKnownHostsFile=./known_hosts bash < ./openvpn.sh
```

### gist.sh

Setup an hourly crontab to run a script from GitHub Gist.

```
ssh pi@raspberrypi.local -o UserKnownHostsFile=./known_hosts bash < ./gist.sh
```

### wifi.sh

Not really useful if you already have connectivity to it. Just a note on how to modify the disk image to enable Wifi before first boot.

### QEMU image

This part of the tool allow you to quickly emulate a device without having access to an actual device.
The resulting image cannot be flashed into an SD card.

1. Install qemu and wget: `brew install qemu wget`.
2. Run `make`
3. The resulting disk image can be found in `dist`.
4. Boot up the device with `make boot`.

## References

* [RPI Qemu](https://gist.github.com/hfreire/5846b7aa4ac9209699ba#gistcomment-2833377)
* [How to Setup QEMU Output to Console and Automate Using Shell Script](https://fadeevab.com/how-to-setup-qemu-output-to-console-and-automate-using-shell-script/)
* [Makefile cheatsheet](https://devhints.io/makefile)
* [Turn on SSH](https://www.raspberrypi.org/documentation/remote-access/ssh/)
* [Moniter a string in shell until it is found](https://superuser.com/a/900134)
* [Protect your Raspberry PI SD card, use Read-Only filesystem](https://hallard.me/raspberry-pi-read-only/): very useful but the assumptions on directories are outdated.
* [ReadonlyRoot](https://wiki.debian.org/ReadonlyRoot): Also generic but useful.
* [OpenVPN road warrior installer for Debian, Ubuntu and CentOS](https://github.com/Nyr/openvpn-install).
