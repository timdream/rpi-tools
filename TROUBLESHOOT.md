# Troubleshooting

Assuming you finally have SSH access to the Raspberry Pi, here are some commands to debug, from incoming to out-going.

## Verify default network interface

There should be at least one `default`.

On **Raspberry Pi**:

```
$ route -4
Kernel IP routing table
Destination     Gateway         Genmask         Flags Metric Ref    Use Iface
default         hitronhub.home  0.0.0.0         UG    202    0        0 eth0
10.8.0.0        0.0.0.0         255.255.255.128 U     0      0        0 tun0
10.8.0.128      0.0.0.0         255.255.255.128 U     0      0        0 tun1
192.168.0.0     0.0.0.0         255.255.255.0   U     202    0        0 eth0
$ route -4 | grep default | head -n 1 | awk '{print $8}'
eth0
```

## Find the LAN IP address

On **Raspberry Pi**, assumes `eth0` (wired ethernet port) is the default interface:

```
$ ifconfig eth0
eth0: flags=4163<UP,BROADCAST,RUNNING,MULTICAST>  mtu 1500
        inet 192.168.0.18  netmask 255.255.255.0  broadcast 192.168.0.255
        inet6 fe80::4b5c:b337:bb99:5af2  prefixlen 64  scopeid 0x20<link>
        ether b8:27:eb:84:b8:ea  txqueuelen 1000  (Ethernet)
        RX packets 283266  bytes 115482368 (110.1 MiB)
        RX errors 0  dropped 6  overruns 0  frame 0
        TX packets 120674  bytes 58543794 (55.8 MiB)
        TX errors 0  dropped 0 overruns 0  carrier 0  collisions 0
$ ifconfig eth0 | grep "inet " | awk '{print $2}'
192.168.0.18
```

## Verify external connectivity to Google DNS (or any other host)

On **Raspberry Pi**:

```
ping 8.8.8.8
```

## Verify local DNS query

On **Raspberry Pi**:

```
$ nslookup www.google.com
Server:		192.168.0.1
Address:	192.168.0.1#53

Non-authoritative answer:
Name:	www.google.com
Address: 172.217.160.68
```

## Find the external IP of Raspberry Pi

This talks to OpenDNS and ask it to return the IP you connect to it.

On **Raspberry Pi**:

```
$ curl -s https://api.ipify.org
123.123.123.123
```

## Verify your DNS hostname is pointing to that external IP

On **your computer**:

```
$ nslookup example.com
Server:		2601:647:4500:ca:8e3b:adff:fefa:9e0e
Address:	2601:647:4500:ca:8e3b:adff:fefa:9e0e#53

Non-authoritative answer:
Name:	example.com
Address: 123.123.123.123
```

## Verify TCP OpenVPN server connection

### systemd status

On **Raspberry Pi**:

```
$ systemctl status openvpn@server
● openvpn@server.service - OpenVPN connection to server
   Loaded: loaded (/lib/systemd/system/openvpn@.service; enabled; vendor preset: enabled)
   Active: active (running) since Tue 2019-12-31 03:17:52 GMT; 4 days ago
     Docs: man:openvpn(8)
           https://community.openvpn.net/openvpn/wiki/Openvpn23ManPage
           https://community.openvpn.net/openvpn/wiki/HOWTO
  Process: 436 ExecStart=/usr/sbin/openvpn --daemon ovpn-server --status /run/openvpn/server.status 10 --cd /etc/openvpn --config /etc/openvpn/server.conf --writepid /run/openvpn/server.pid (code=exited, status=0/SUCCESS)
 Main PID: 443 (openvpn)
    Tasks: 1 (limit: 4915)
   CGroup: /system.slice/system-openvpn.slice/openvpn@server.service
           └─443 /usr/sbin/openvpn --daemon ovpn-server --status /run/openvpn/server.status 10 --cd /etc/openvpn --config /etc/openvpn/server.conf --writepid /run/openvpn/server.pid
...
```

### Verify TLS connection to TCP server locally

On **Raspberry Pi**:

```
$ openssl s_client -connect localhost:443
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
    Start Time: 1578111032
    Timeout   : 7200 (sec)
    Verify return code: 0 (ok)
    Extended master secret: no
---
```

### Verify you can connect to it from client

This implies UPnP on the TCP port works.

On **your computer**:

```
$ openssl s_client -connect example.com:443
CONNECTED(00000005)
4449486444:error:140040E5:SSL routines:CONNECT_CR_SRVR_HELLO:ssl handshake failure:/BuildRoot/Library/Caches/com.apple.xbs/Sources/libressl/libressl-22.260.1/libressl-2.6/ssl/ssl_pkt.c:585:
---
no peer certificate available
---
No client certificate CA names sent
---
SSL handshake has read 0 bytes and written 0 bytes
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
    Start Time: 1578111346
    Timeout   : 7200 (sec)
    Verify return code: 0 (ok)
---
```

## Verify UDP OpenVPN server connection

### systemd status

On **Raspberry Pi**:

```
$ systemctl status openvpn@server-udp
● openvpn@server-udp.service - OpenVPN connection to server-udp
   Loaded: loaded (/lib/systemd/system/openvpn@.service; enabled; vendor preset: enabled)
   Active: active (running) since Fri 2020-01-03 07:20:32 GMT; 21h ago
     Docs: man:openvpn(8)
           https://community.openvpn.net/openvpn/wiki/Openvpn23ManPage
           https://community.openvpn.net/openvpn/wiki/HOWTO
  Process: 4297 ExecStart=/usr/sbin/openvpn --daemon ovpn-server-udp --status /run/openvpn/server-udp.status 10 --cd /etc/openvpn --config /etc/openvpn/server-udp.conf --writepid /run/openvpn/server-udp.pid (code=exited, status=0/SUCCESS)
 Main PID: 4298 (openvpn)
    Tasks: 1 (limit: 4915)
   CGroup: /system.slice/system-openvpn.slice/openvpn@server-udp.service
           └─4298 /usr/sbin/openvpn --daemon ovpn-server-udp --status /run/openvpn/server-udp.status 10 --cd /etc/openvpn --config /etc/openvpn/server-udp.conf --writepid /run/openvpn/server-udp.pid
...
```
### Verify TLS connection to UDP server locally

This is not possible because an OpenVPN server listening on UDP port simply drop the packets if it's not encrypted by the specific key.

### Verify you can connect to it from client

This implies UPnP on the UDP port works, but not the server itself ([credit](https://serverfault.com/a/733921)).

On **Raspbarry Pi**:

1. Stop the UDP server: `sudo systmectl stop openvpn@server-udp`.
2. Start listening to packets with `nc`: `nc -ul 443`.

On **your computer**:

1. Start sending stuff via `nc`: `nc -u example.com 443`, hit enter, type something, and hit enter again.
2. The typed text should appear on the Raspbarry Pi terminal.

## Verify SSH incoming connection from client

We are pointing external port `8022` and `28022` to port `22` internally in the UPnP set up script.

On **your computer**:

```
$ ssh pi@example.com -p 8022
```

Alternatively, just to test there is an SSH server running:

```
$ ssh-keyscan example.com -p 8022
```

## Router port forwarding

The above tests should verify you can connect TCP/443, UDP/443, and TCP/8022. To ask the router to list it out, on **Raspbarry Pi**:

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
Status : Connected, uptime=1737305s, LastConnectionError : ERROR_NONE
  Time started : Sun Dec 15 01:56:10 2019
MaxBitRateDown : 4200000 bps (4.2 Mbps)   MaxBitRateUp 4200000 bps (4.2 Mbps)
ExternalIPAddress = 123.123.123.123
 i protocol exPort->inAddr:inPort description remoteHost leaseTime
 0 TCP   443->192.168.0.18:443   'libminiupnpc' '' 0
 1 TCP  8022->192.168.0.18:22    'libminiupnpc' '' 0
 2 TCP 28022->192.168.0.18:22    'libminiupnpc' '' 0
 3 UDP   443->192.168.0.18:443   'libminiupnpc' '' 0
GetGenericPortMappingEntry() returned 713 (SpecifiedArrayIndexInvalid)
```

## Kernel forwarding settings

### `/proc/sys/net/ipv4/ip_forward`

On **Raspbarry Pi**:

```
$ sudo cat /proc/sys/net/ipv4/ip_forward
1
```

### iptables

The `to:` IP must match the LAN IP to the default interface (`192.168.0.18` in this case).

On **Raspbarry Pi**:

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
