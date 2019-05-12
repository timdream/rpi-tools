# rpi-tools

My own assorted script (manual or automated) to prepare for Raspberry Pi images & to command booted up Raspberry Pi.

Likely not going to support future versions once I am done with my current project, but should be helpful for people who is looking.

Featuring:

[v] Fetch the image and boot it up in Qemu
[v] Execute some command on the image in Qemu
[v] Set the disk to readonly
[ ] Set up OpenVPN?

## Usage

### QEMU image

1. Install qemu and wget: `brew install qemu wget`.
2. Run `make`
3. The resulting disk image can be found in `dist`.

### bootstrap.sh

It turned out you cannot put an image booted with QEMU to and SD card.
So everything needs to be done should be done on the actual machine.

After getting your Raspberry Pi booted up and SSH turned on, do this
to execute `bootstrap.sh` on it.

```
ssh pi@raspberrypi.local bash < ./bootstrap.sh
```

## References

* [RPI Qemu](https://gist.github.com/hfreire/5846b7aa4ac9209699ba#gistcomment-2833377)
* [How to Setup QEMU Output to Console and Automate Using Shell Script](https://fadeevab.com/how-to-setup-qemu-output-to-console-and-automate-using-shell-script/)
* [Makefile cheatsheet](https://devhints.io/makefile)
* [Turn on SSH](https://www.raspberrypi.org/documentation/remote-access/ssh/)
* [Moniter a string in shell until it is found](https://superuser.com/a/900134)

## To be incorporated

* [Protect your Raspberry PI SD card, use Read-Only filesystem](https://hallard.me/raspberry-pi-read-only/): very useful but the assumptions on directories are outdated.
* [ReadonlyRoot](https://wiki.debian.org/ReadonlyRoot): Also generic but useful.
* [OpenVPN road warrior installer for Debian, Ubuntu and CentOS](https://github.com/Nyr/openvpn-install).
