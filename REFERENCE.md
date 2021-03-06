# References

These are current configuration I am using, not necessary the results of the the scripts here, given that `openvpn-install` will change.
I've also manually adding my changes from time to time.

## OpenVPN server

### `/etc/openvpn/server.conf`

```
port 443
proto tcp
dev tun
sndbuf 0
rcvbuf 0
ca ca.crt
cert server.crt
key server.key
dh dh.pem
auth SHA512
tls-auth ta.key 0
topology subnet
server 10.8.0.128 255.255.255.128
ifconfig-pool-persist /var/tmp/openvpn-ipp-tcp.txt
push "redirect-gateway def1 bypass-dhcp"
push "dhcp-option DNS 8.8.8.8"
push "dhcp-option DNS 8.8.4.4"
keepalive 10 120
cipher AES-256-CBC
comp-lzo
user nobody
group nogroup
persist-key
persist-tun
status /var/log/openvpn-status-tcp.log
verb 3
crl-verify crl.pem
```

### `/etc/openvpn/server-udp.conf`

```
port 443
proto udp
dev tun
sndbuf 0
rcvbuf 0
ca ca.crt
cert server.crt
key server.key
dh dh.pem
auth SHA512
tls-auth ta.key 0
topology subnet
server 10.8.0.0 255.255.255.128
ifconfig-pool-persist /var/tmp/openvpn-ipp-udp.txt
push "redirect-gateway def1 bypass-dhcp"
push "dhcp-option DNS 8.8.8.8"
push "dhcp-option DNS 8.8.4.4"
keepalive 10 120
cipher AES-256-CBC
comp-lzo
user nobody
group nogroup
persist-key
persist-tun
status /var/log/openvpn-status-udp.log
verb 3
crl-verify crl.pem
```

### `client.ovpn`

```
client
dev tun
sndbuf 0
rcvbuf 0
remote example.com 443
remote example.com 443 tcp-client
resolv-retry infinite
nobind
persist-key
persist-tun
remote-cert-tls server
auth SHA512
cipher AES-256-CBC
compress lzo
key-direction 1
verb 3
<ca>
-----BEGIN CERTIFICATE-----
...
-----END CERTIFICATE-----
</ca>
<cert>
Certificate:
...
-----BEGIN CERTIFICATE-----
...
-----END CERTIFICATE-----
</cert>
<key>
-----BEGIN PRIVATE KEY-----
...
-----END PRIVATE KEY-----
</key>
<tls-auth>
#
# 2048 bit OpenVPN static key
#
-----BEGIN OpenVPN Static key V1-----
...
-----END OpenVPN Static key V1-----
</tls-auth>
```

### Version

```
$ /usr/sbin/openvpn --version
OpenVPN 2.4.0 arm-unknown-linux-gnueabihf [SSL (OpenSSL)] [LZO] [LZ4] [EPOLL] [PKCS11] [MH/PKTINFO] [AEAD] built on Oct 14 2018
library versions: OpenSSL 1.0.2u  20 Dec 2019, LZO 2.08
Originally developed by James Yonan
Copyright (C) 2002-2017 OpenVPN Technologies, Inc. <sales@openvpn.net>
Compile time defines: enable_async_push=no enable_comp_stub=no enable_crypto=yes enable_crypto_ofb_cfb=yes enable_debug=yes enable_def_auth=yes enable_dependency_tracking=no enable_dlopen=unknown enable_dlopen_self=unknown enable_dlopen_self_static=unknown enable_fast_install=yes enable_fragment=yes enable_iproute2=yes enable_libtool_lock=yes enable_lz4=yes enable_lzo=yes enable_maintainer_mode=no enable_management=yes enable_multi=yes enable_multihome=yes enable_pam_dlopen=no enable_password_save=yes enable_pedantic=no enable_pf=yes enable_pkcs11=yes enable_plugin_auth_pam=yes enable_plugin_down_root=yes enable_plugins=yes enable_port_share=yes enable_selinux=no enable_server=yes enable_shared=yes enable_shared_with_static_runtimes=no enable_silent_rules=no enable_small=no enable_static=yes enable_strict=no enable_strict_options=no enable_systemd=yes enable_werror=no enable_win32_dll=yes enable_x509_alt_username=yes with_crypto_library=openssl with_gnu_ld=yes with_mem_check=no with_plugindir='${prefix}/lib/openvpn' with_sysroot=no
$ apt show openvpn
Package: openvpn
Version: 2.4.0-6+deb9u3
Priority: optional
Section: net
Maintainer: Alberto Gonzalez Iniesta <agi@inittab.org>
Installed-Size: 1,048 kB
Depends: debconf (>= 0.5) | debconf-2.0, libc6 (>= 2.15), liblz4-1 (>= 0.0~r113), liblzo2-2, libpam0g (>= 0.99.7.1), libpkcs11-helper1 (>= 1.11), libssl1.0.2 (>= 1.0.2d), libsystemd0, init-system-helpers (>= 1.18~), iproute2, lsb-base (>= 3.0-6)
Recommends: easy-rsa
Suggests: openssl, resolvconf
Homepage: http://www.openvpn.net/
Download-Size: 440 kB
APT-Manual-Installed: yes
APT-Sources: http://raspbian.raspberrypi.org/raspbian stretch/main armhf Packages
Description: virtual private network daemon
 OpenVPN is an application to securely tunnel IP networks over a
 single UDP or TCP port. It can be used to access remote sites, make
 secure point-to-point connections, enhance wireless security, etc.
 .
 OpenVPN uses all of the encryption, authentication, and certification
 features provided by the OpenSSL library (any cipher, key size, or
 HMAC digest).
 .
 OpenVPN may use static, pre-shared keys or TLS-based dynamic key exchange. It
 also supports VPNs with dynamic endpoints (DHCP or dial-up clients), tunnels
 over NAT or connection-oriented stateful firewalls (such as Linux's iptables).
```

## Kernel settings

### `sudo iptables -t nat -L`

```
$ sudo iptables -t nat -L
Chain PREROUTING (policy ACCEPT)
target     prot opt source               destination

Chain INPUT (policy ACCEPT)
target     prot opt source               destination

Chain OUTPUT (policy ACCEPT)
target     prot opt source               destination

Chain POSTROUTING (policy ACCEPT)
target     prot opt source               destination
SNAT       all  --  10.8.0.0/24         !10.8.0.0/24          to:192.168.0.18
```

### `sudo cat /proc/sys/net/ipv4/ip_forward`

```
$ sudo cat /proc/sys/net/ipv4/ip_forward
1
```

## External connectivity

### Example `/var/log/vpn.log` section

The uPnP part is verbose and probably indicating that my router here is a bit broken, even though it works.

```
==============================================
Mon 30 Dec 18:17:07 GMT 2019
==============================================
Interface: eth0
LAN IP: 192.168.0.18
External IP: 123.123.123.123
Dynamic DNS: <?xml version="1.0"?><interface-response><Command>SETDNSHOST</Command><Language>eng</Language><IP>123.123.123.123</IP><ErrCount>0</ErrCount><ResponseCount>0</ResponseCount><Done>true</Done><debug><![CDATA[]]></debug></interface-response>
Setup uPnP
upnpc : miniupnpc library test client. (c) 2005-2014 Thomas Bernard
Go to http://miniupnp.free.fr/ or http://miniupnp.tuxfamily.org/
for more information.
List of UPNP devices found on the network :
 desc: http://192.168.100.1:5000/rootDesc.x
 st: urn:schemas-upnp-org:device:InternetGatewayDevice:1

UPnP device found. Is it an IGD ? : http://192.168.100.1:5000/
Trying to continue anyway
Local LAN ip address : 192.168.0.18
UPNP_DeletePortMapping() returned : 0
upnpc : miniupnpc library test client. (c) 2005-2014 Thomas Bernard
Go to http://miniupnp.free.fr/ or http://miniupnp.tuxfamily.org/
for more information.
List of UPNP devices found on the network :
 desc: http://192.168.100.1:5000/rootDesc.x
 st: urn:schemas-upnp-org:device:InternetGatewayDevice:1

UPnP device found. Is it an IGD ? : http://192.168.100.1:5000/
Trying to continue anyway
Local LAN ip address : 192.168.0.18
UPNP_DeletePortMapping() returned : 0
upnpc : miniupnpc library test client. (c) 2005-2014 Thomas Bernard
Go to http://miniupnp.free.fr/ or http://miniupnp.tuxfamily.org/
for more information.
List of UPNP devices found on the network :
 desc: http://192.168.100.1:5000/rootDesc.x
 st: urn:schemas-upnp-org:device:InternetGatewayDevice:1

UPnP device found. Is it an IGD ? : http://192.168.100.1:5000/
Trying to continue anyway
Local LAN ip address : 192.168.0.18
UPNP_DeletePortMapping() returned : 0
upnpc : miniupnpc library test client. (c) 2005-2014 Thomas Bernard
Go to http://miniupnp.free.fr/ or http://miniupnp.tuxfamily.org/
for more information.
List of UPNP devices found on the network :
 desc: http://192.168.100.1:5000/rootDesc.x
 st: urn:schemas-upnp-org:device:InternetGatewayDevice:1

UPnP device found. Is it an IGD ? : http://192.168.100.1:5000/
Trying to continue anyway
Local LAN ip address : 192.168.0.18
UPNP_DeletePortMapping() returned : 0
upnpc : miniupnpc library test client. (c) 2005-2014 Thomas Bernard
Go to http://miniupnp.free.fr/ or http://miniupnp.tuxfamily.org/
for more information.
List of UPNP devices found on the network :
 desc: http://192.168.100.1:5000/rootDesc.x
 st: urn:schemas-upnp-org:device:InternetGatewayDevice:1

UPnP device found. Is it an IGD ? : http://192.168.100.1:5000/
Trying to continue anyway
Local LAN ip address : 192.168.0.18
ExternalIPAddress = 123.123.123.123
InternalIP:Port = 192.168.0.18:22
external 123.123.123.123:8022 TCP is redirected to internal 192.168.0.18:22 (duration=0)
upnpc : miniupnpc library test client. (c) 2005-2014 Thomas Bernard
Go to http://miniupnp.free.fr/ or http://miniupnp.tuxfamily.org/
for more information.
List of UPNP devices found on the network :
 desc: http://192.168.100.1:5000/rootDesc.x
 st: urn:schemas-upnp-org:device:InternetGatewayDevice:1

UPnP device found. Is it an IGD ? : http://192.168.100.1:5000/
Trying to continue anyway
Local LAN ip address : 192.168.0.18
ExternalIPAddress = 123.123.123.123
InternalIP:Port = 192.168.0.18:22
external 123.123.123.123:28022 TCP is redirected to internal 192.168.0.18:22 (duration=0)
upnpc : miniupnpc library test client. (c) 2005-2014 Thomas Bernard
Go to http://miniupnp.free.fr/ or http://miniupnp.tuxfamily.org/
for more information.
List of UPNP devices found on the network :
 desc: http://192.168.100.1:5000/rootDesc.x
 st: urn:schemas-upnp-org:device:InternetGatewayDevice:1

UPnP device found. Is it an IGD ? : http://192.168.100.1:5000/
Trying to continue anyway
Local LAN ip address : 192.168.0.18
ExternalIPAddress = 123.123.123.123
InternalIP:Port = 192.168.0.18:443
external 123.123.123.123:443 UDP is redirected to internal 192.168.0.18:443 (duration=0)
ExternalIPAddress = 123.123.123.123
InternalIP:Port = 192.168.0.18:443
external 123.123.123.123:443 TCP is redirected to internal 192.168.0.18:443 (duration=0)
Setup iptables
```

### `ssh-keyscan -p 8022 $(dig -4 @resolver1.opendns.com ANY myip.opendns.com +short)`

Verify UPnP/NAT port forwarding works externally for SSH port

```
$ ssh-keyscan -p 8022 $(dig -4 @resolver1.opendns.com ANY myip.opendns.com +short)
# 123.123.123.123:8022 SSH-2.0-OpenSSH_7.4p1 Raspbian-10+deb9u7
[123.123.123.123]:8022 ssh-rsa AAAA.....
# 123.123.123.123:8022 SSH-2.0-OpenSSH_7.4p1 Raspbian-10+deb9u7
[123.123.123.123]:8022 ecdsa-sha2-nistp256 AAAAE.....=
# 123.123.123.123:8022 SSH-2.0-OpenSSH_7.4p1 Raspbian-10+deb9u7
[123.123.123.123]:8022 ssh-ed25519 AAAAC3......
```

### `openssl s_client -connect $(dig -4 @resolver1.opendns.com ANY myip.opendns.com +short):443`

Verify UPnP/NAT port forwarding works externally for TCP:443.

```$ openssl s_client -connect $(dig -4 @resolver1.opendns.com ANY myip.opendns.com +short):443
CONNECTED(00000003)
write:errno=0
---
no peer certificate available
---
No client certificate CA names sent
---
SSL handshake has read 0 bytes and written 176 bytes
Verification: OK
---
New, (NONE), Cipher is (NONE)
Secure Renegotiation IS NOT supported
Compression: NONE
Expansion: NONE
No ALPN negotiated
SSL-Session:
    Protocol  : TLSv1.2
    Cipher    : 0000
    Session-ID:
    Session-ID-ctx:
    Master-Key:
    PSK identity: None
    PSK identity hint: None
    SRP username: None
    Start Time: 1577734223
    Timeout   : 7200 (sec)
    Verify return code: 0 (ok)
    Extended master secret: no
---
```

### `upnpc -l`

This should list all redirections.

```
$ upnpc -l
upnpc : miniupnpc library test client. (c) 2005-2014 Thomas Bernard
Go to http://miniupnp.free.fr/ or http://miniupnp.tuxfamily.org/
for more information.
List of UPNP devices found on the network :
 desc: http://192.168.100.1:5000/rootDesc.x
 st: urn:schemas-upnp-org:device:InternetGatewayDevice:1

UPnP device found. Is it an IGD ? : http://192.168.100.1:5000/
Trying to continue anyway
Local LAN ip address : 192.168.0.18
Connection Type : IP_Routed
Status : Connected, uptime=1646419s, LastConnectionError : ERROR_NONE
  Time started : Sun Dec 15 01:56:10 2019
MaxBitRateDown : 4200000 bps (4.2 Mbps)   MaxBitRateUp 4200000 bps (4.2 Mbps)
ExternalIPAddress = 123.123.123.123
 i protocol exPort->inAddr:inPort description remoteHost leaseTime
 0 UDP  5353->192.168.0.15:5353  'NAT-PMP 5353 udp' '' 4384
 1 UDP  4500->192.168.0.15:4500  'NAT-PMP 4500 udp' '' 4384
 2 TCP  8022->192.168.0.18:22    'libminiupnpc' '' 0
 3 TCP 28022->192.168.0.18:22    'libminiupnpc' '' 0
 4 UDP  443->192.168.0.18:443  'libminiupnpc' '' 0
 5 TCP   443->192.168.0.18:443   'libminiupnpc' '' 0
GetGenericPortMappingEntry() returned 713 (SpecifiedArrayIndexInvalid)
```

### Version

```
$ apt show miniupnpc
Package: miniupnpc
Version: 1.9.20140610-4
Priority: optional
Section: net
Maintainer: Thomas Goirand <zigo@debian.org>
Installed-Size: 51.2 kB
Depends: libc6 (>= 2.4), libminiupnpc10 (>= 1.9.20140610)
Recommends: minissdpd
Homepage: http://miniupnp.free.fr/
Download-Size: 20.6 kB
APT-Manual-Installed: yes
APT-Sources: http://raspbian.raspberrypi.org/raspbian stretch/main armhf Packages
Description: UPnP IGD client lightweight library client
 The UPnP protocol is supported by most home adsl/cable routers and Microsoft
 Windows 2K/XP. The aim of the MiniUPnP project is to bring a free software
 solution to support the "Internet Gateway Device" part of the protocol. The
 MediaServer/MediaRenderer UPnP protocol is also becoming very popular.
 .
 Miniupnpc aims at the simplest library possible, with the smallest footprint
 and no dependencies to other libraries such as XML parsers or HTTP
 implementations. All the code is pure ANSI C. Compiled on a x86 PC, the
 miniupnp client library have less than 15KB code size. For instance, the upnpc
 sample program is around 20KB. The miniupnp daemon is much smaller than any
 other IGD daemon and is ideal for using on low memory device for this reason.
 .
 This package is an example client for the library.
```

## OpenVPN client

### Version

These are the very first lines of the Tunnelblick log

```
*Tunnelblick: macOS 10.14.6 (18G2022); Tunnelblick 3.8.1 (build 5400); prior version 3.7.9 (build 5320); Admin user
git commit 202d7d855181acbb15662bb08484f6229a113517
```

### Settings

* Connect: Manually
* Set DNS/WINS: Set nameserver
* OpenVPN version: Default (2.4.7 - OpenSSL v1.0.2t)
* VPN log level: OpenVPN level 3 - normal output

* Monitor network settings: checked
* Route all IPv4 traffic through the VPN: checked
* Disable IPv6 unless the VPN server is accessed using IPv6: checked
* Check if appearant public IP address changed after connecting: checked

### `route`

This verify that IPv4 connection goes to the tunnel.

```
$ route get 8.8.8.8
   route to: dns.google
destination: dns.google
    gateway: 10.8.0.1
  interface: utun4
      flags: <UP,GATEWAY,HOST,DONE,WASCLONED,IFSCOPE,IFREF>
 recvpipe  sendpipe  ssthresh  rtt,msec    rttvar  hopcount      mtu     expire
       0         0         0         0         0         0      1500         0
```

### `traceroute`

This verify that the client connection gets forwarded on the server.

```
$ traceroute 8.8.8.8
traceroute to 8.8.8.8 (8.8.8.8), 64 hops max, 52 byte packets
 1  10.8.0.1 (10.8.0.1)  192.002 ms  408.636 ms  409.769 ms
 2  192.168.0.1 (192.168.0.1)  422.498 ms  201.484 ms  186.485 ms
 3  host-123-123-123-123.dynamic.kbtelecom.net (123.123.123.123)  430.026 ms  409.369 ms  408.965 ms
 4  192.168.11.169 (192.168.11.169)  409.532 ms  423.573 ms  395.242 ms
 ...
 ```

### `nslookup`

This verify that the client receives a DNS configuration that works.

```
$ nslookup www.google.com
Server:		8.8.8.8
Address:	8.8.8.8#53

Non-authoritative answer:
Name:	www.google.com
Address: 216.58.200.36
```

## Example `/var/log/remount.log`

```
$ cat /var/log/remount.log
Mon 30 Dec 04:17:08 GMT 2019: rw resolvconf
Mon 30 Dec 04:17:08 GMT 2019: ro resolvconf
Mon 30 Dec 04:17:08 GMT 2019: rw apt-daily-upgrade
Mon 30 Dec 04:17:11 GMT 2019: ro apt-daily-upgrade
Mon 30 Dec 18:45:16 GMT 2019: rw apt-daily
Mon 30 Dec 18:45:28 GMT 2019: ro apt-daily
Mon 30 Dec 18:45:29 GMT 2019: rw apt-daily-upgrade
Mon 30 Dec 18:45:30 GMT 2019: ro apt-daily-upgrade
Mon 30 Dec 18:47:07 GMT 2019: rw user
Mon 30 Dec 18:49:19 GMT 2019: ro user
Mon 30 Dec 19:02:02 GMT 2019: rw user
Mon 30 Dec 19:17:01 GMT 2019: rw fake-hwclock <skipped (1)>
Mon 30 Dec 19:17:01 GMT 2019: ro fake-hwclock <skipped (2)>
Mon 30 Dec 19:35:44 GMT 2019: ro user
```
