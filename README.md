# rpi-tools

Step-by-step scripts to semi-automatically setup an OpenVPN server on Raspberry Pi.

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
* Install `unattended-upgrades` and ask it to automatically install all package updates except for known packages that touches `/boot`.
* Set the file system to be readonly and move all the mutable states to `tmpfs`. This is done so that an unexpected power cycle won’t corrupt the file system and prevent the device from booting up. **This is very important in order for devices that is hard to service.**
* Also installed a `remount` command-line tool for easy toggle between read-write and read-only.

To execute `bootstrap.sh` on it, run this on your terminal:

```
ssh pi@raspberrypi.local -o UserKnownHostsFile=./known_hosts bash < ./bootstrap.sh
```

where `raspberrypi.local` should be the mDNS hostname of your device in the same LAN. You are more than welcome to comment out the section that you don't need before running the script.

### Step 3: OpenVPN servers

We'll setup two services so the connection will be more reliable.

### Step 3.1: Setup the UDP OpenVPN server

We will setup the first OpenVPN server by running the [openvpn-install](https://github.com/Nyr/openvpn-install) script on the device.

```
wget https://raw.githubusercontent.com/Nyr/openvpn-install/92d90dac/openvpn-install.sh -O - | ssh pi@raspberrypi.local -o UserKnownHostsFile=./known_hosts -- "cat > /tmp/openssh-install.sh"
ssh pi@raspberrypi.local -o UserKnownHostsFile=./known_hosts "sudo remount rw"
ssh pi@raspberrypi.local -o UserKnownHostsFile=./known_hosts "sudo bash /tmp/openssh-install.sh"
ssh pi@raspberrypi.local -o UserKnownHostsFile=./known_hosts "sudo remount ro"
```

When prompted, set the OpenVPN server to use UDP/443, and a proper external hostname (see section 4.2 on dynamic DNS), and name the client file as `client`.
We will use the HTTPS/QUIC port to establish our TLS connection to avoid blockage.

### Step 3.2: Setup the TCP OpenVPN server

This script will do the following

* Stop the UDP OpenVPN server
* Make the necessary adjustment on the configuration file.
* Copy the config to add a TCP server and also make the necessary adjustment.
* Modify the client file.
* Remove the iptables systemd script and replace it with a crontab.

```
ssh pi@raspberrypi.local -o UserKnownHostsFile=./known_hosts bash < ./openvpn.sh
```

### Step 4: External incoming network access

To gain access to the machine inside an ordinary home network setup, you'll need three things

1. Track the external IP via Dynamic DNS
2. Set the router IPv4 NAT to forward the incoming ports to a specific LAN IP
3. Get the device to be on that specific LAN IP

Note that even though the device may receive an IPv6 address, most home routers block all incoming IPv6 connections and there is not way to configure it otherwise. Until that changes, we will keep working with IPv4.

### Step 4.1: NAT port forwarding or UPnP

The NAT port forwarding and LAN IP setup is substitute￼d with UPnP (Universal Plug and Play). Just ensure that UPnP is turned on on the router. The script will try to configure it every hour and forward the port listed in the script. You can skip this part if you are sure that you can achieve (2) and (3) by manually configure the router, and the router configuration will stick.

```
ssh pi@raspberrypi.local -o UserKnownHostsFile=./known_hosts bash < ./upnp.sh
```

### Step 4.2: Dynamic DNS

To setup a Dynamic DNS, you will need a Dynamic DNS service. It may be the DNS come with your domain registrar, for example [Namecheap](https://www.namecheap.com). It may be a free service where you `CNAME` your subdomain hostname to the dynamic record. You could use the hostname provided by the dyanmic DNS service directly. Regardless, you will need to figure out the URL that `curl` should hit and edit `ddns.sh` to fill that in. The script will set it up in the crontab to run every hour.

```
ssh pi@raspberrypi.local -o UserKnownHostsFile=./known_hosts bash < ./ddns.sh
```

### Step 5: GitHub Gist

This part is completely optional. I have a heartbeat script living on the gist that I wish the device to run every hour. This is the way to achieve it; it's documented in `gist.sh`.

```
ssh pi@raspberrypi.local -o UserKnownHostsFile=./known_hosts bash < ./gist.sh
```

### Step 6: The client

With everything done you should have a `/root/client.ovpn` that you can import into any OpenVPN client.

```
ssh pi@raspberrypi.local -o UserKnownHostsFile=./known_hosts sudo cat /root/client.ovpn > ./client.ovpn
```

On macOS I recommend [TunnelBlick](https://tunnelblick.net). On iOS there is [OpenVPN Connect](https://apps.apple.com/us/app/openvpn-connect/id590379981). Don't download software from unofficial source and always keep it up-to-date!

macOS Client options I am using:

* Connect: Manually
* Set DNS/WINS: Set nameserver
* OpenVPN version: Default (2.4.7 - OpenSSL v1.0.2t)
* VPN log level: OpenVPN level 3 - normal output

* Monitor network settings: checked
* Route all IPv4 traffic through the VPN: checked
* Disable IPv6 unless the VPN server is accessed using IPv6: checked
* Check if appearant public IP address changed after connecting: checked

iOS Client options I am using:

* Seamless Tunnel: checked
* VPN Protocol: Adaptive
* IPv6: IPv4-Only Tunnel
* Connection Timeout: 30 sec
* Allow Compression (insecure): Full
* AES-CBC Cipher Algorithm: checked
* Minimum TLS Version: Profile Default
* DNS Fallback: not checked
* Connect Via: Any network
* Layer 2 Reachability: checked

### Step 7: Verify

Reboot the device. Once it come back, you should have

1. Two OpenVPN daemon up and running. You can verify that with `sudo systemctl status openvpn@server.service` and `sudo systemctl status openvpn@server-tcp.service`.
2. The system filesystem should be read-only. You can verify that by running `remount` and see if it says `Current mount options: ro` instead of `rw`.

Run `/etc/cron.hourly/iptables` to trigger iptables check: `sudo /etc/cron.hourly/iptables`. There should be exactly one rule in the `nat` table. Inspect the output of `sudo iptables -t nat -L POSTROUTING`.

Run `/etc/cron.hourly/upnp` and `/etc/cron.hourly/ddns` on your own to trigger UPnP update: `sudo /etc/cron.hourly/vpn && sudo /etc/cron.hourly/ddns`, after that you can verify that the external incomming connection works. The scripts save thier outputs at `/var/log/upnp.log` and `/var/log/ddns.log`.

To test the OpenVPN server on the TCP port, stop the UDP server and try to connect the client with it. The UDP server should timeout and the client should fallback to TCP.

**Remember to change the SSH password!** Noted that `fail2ban` is not setup because it won't be able to tell the remote IP addresses behind an NAT.

Typing `remount` will give you current mount option of the root filesystem, and usage.
`bootstrap.sh` would patch a few scripts for them to remount the disk read-write temporary, but sometimes, `remount` may fail to set the disk to read-only again.
When that happens, the offending processes *may* be identified in `/var/log/remount.log`.
It would be wise to have some monitoring in place to verify the current disk state.
I am doing that in my Gist which runs hourly.

## Testing

These script are developed with a QEMU image builder and test scripts controlled by a `Makefile`.
The resulting image cannot be flashed into an SD card.
OpenVPN service don't actually work on the emulation because of native configuration, but it is useful enough to verify the script.

1. Install qemu and wget: `brew install qemu wget`.
2. Run `make`
3. The resulting disk image can be found in `dist`.
4. Boot up the device with `make boot`.
5. On a separate terminal, test out each of the script with the following commands: `make test-bootstrap`, `make test-openvpn-install`, `make test-openvpn`, `make test-upnp`, `make test-ddns`, and `make test-gist`.

## References

* [RPI Qemu](https://gist.github.com/hfreire/5846b7aa4ac9209699ba#gistcomment-2833377)
* [How to Setup QEMU Output to Console and Automate Using Shell Script](https://fadeevab.com/how-to-setup-qemu-output-to-console-and-automate-using-shell-script/)
* [Makefile cheatsheet](https://devhints.io/makefile)
* [Turn on SSH](https://www.raspberrypi.org/documentation/remote-access/ssh/)
* [Moniter a string in shell until it is found](https://superuser.com/a/900134)
* [Protect your Raspberry PI SD card, use Read-Only filesystem](https://hallard.me/raspberry-pi-read-only/): very useful but the assumptions on directories are outdated.
* [ReadonlyRoot](https://wiki.debian.org/ReadonlyRoot): Also generic but useful.
* [OpenVPN road warrior installer for Debian, Ubuntu and CentOS](https://github.com/Nyr/openvpn-install).
* [Configuring `unattended-upgrades` on Raspbian Stretch](https://raspberrypi.stackexchange.com/a/74973)
* [Test UDP connection](https://serverfault.com/a/733921)
