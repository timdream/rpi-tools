IMAGE_NAME=2020-02-13-raspbian-buster-lite
QEMU=$(shell which qemu-system-arm)
TMP_DIR=build
RPI_KERNEL=${TMP_DIR}/kernel-qemu-4.19.50-buster
RPI_FS=${TMP_DIR}/${IMAGE_NAME}.img
PTB_FILE=${TMP_DIR}/versatile-pb.dtb
IMAGE_FILE=${TMP_DIR}/${IMAGE_NAME}.zip
IMAGE=http://downloads.raspberrypi.org/raspbian_lite/images/raspbian_lite-2020-02-14/${IMAGE_NAME}.zip

.PHONY: all
all: dist/raspbian_lite.img

${RPI_KERNEL}: Makefile
	mkdir -p ${TMP_DIR} && \
	wget https://github.com/dhruvvyas90/qemu-rpi-kernel/blob/master/kernel-qemu-4.19.50-buster?raw=true \
	  -O ${RPI_KERNEL}

${PTB_FILE}: Makefile
	mkdir -p ${TMP_DIR} && \
	wget https://github.com/dhruvvyas90/qemu-rpi-kernel/raw/master/versatile-pb.dtb \
	  -O ${PTB_FILE}

${IMAGE_FILE}:
	mkdir -p ${TMP_DIR} && \
	wget ${IMAGE} -O ${IMAGE_FILE}

${RPI_FS}: ${IMAGE_FILE}
	mkdir -p ${TMP_DIR} && \
	unzip ${IMAGE_FILE} -d ${TMP_DIR} && \
	touch ${RPI_FS}

dist/raspbian_lite.img: ${RPI_FS} ${PTB_FILE} ${RPI_KERNEL}
	@mkdir -p dist && \
	rm -rf dist/raspbian_lite.img ${TMP_DIR}/pipe.in ${TMP_DIR}/pipe.out ${TMP_DIR}/output && \
	cp ${RPI_FS} ${TMP_DIR}/raspbian_lite.tmp.img && \
	mkfifo ${TMP_DIR}/pipe.in ${TMP_DIR}/pipe.out ${TMP_DIR}/output && \
	echo ">>> Booting up for the first time in QEMU..." && \
	( cat ${TMP_DIR}/pipe.out | tee ${TMP_DIR}/output & ) && \
	( ${QEMU} -kernel ${RPI_KERNEL} \
		-cpu arm1176 -m 256 -M versatilepb \
		-dtb ${PTB_FILE} -no-reboot \
		-append "root=/dev/sda2 panic=1 rootfstype=ext4 rw" \
		-drive "file=${TMP_DIR}/raspbian_lite.tmp.img,index=0,media=disk,format=raw" \
		-net user,hostfwd=tcp::5022-:22 -net nic -pidfile ${TMP_DIR}/qemu.pid -serial pipe:${TMP_DIR}/pipe & ) && \
	sleep 10 && \
	while read line; do \
		echo "$${line}" | grep -q 'My IP address is' && break; \
	done < ${TMP_DIR}/output && \
	echo ">>> Logging in and turning on SSH..." && \
	sleep 20 && \
	printf "pi\n" > build/pipe.in && \
	sleep 2 && \
	printf "raspberry\n" > build/pipe.in && \
	sleep 2 && \
	printf "sudo systemctl enable ssh && sudo systemctl start ssh && sudo poweroff\n" > build/pipe.in && \
	sleep 2 &&\
	echo ">>> Waiting for poweroff..." && \
	while [ -f ${TMP_DIR}/qemu.pid ]; do \
		sleep 1; \
	done && \
	echo ">>> Moving image to dist..." && \
	rm -f ${TMP_DIR}/pipe.in ${TMP_DIR}/pipe.out ${TMP_DIR}/output && \
	mv ${TMP_DIR}/raspbian_lite.tmp.img dist/raspbian_lite.img

.PHONY: boot
boot: dist/raspbian_lite.img ${PTB_FILE} ${RPI_KERNEL}
	${QEMU} -kernel ${RPI_KERNEL} \
		-cpu arm1176 -m 256 -M versatilepb \
		-dtb ${PTB_FILE} -no-reboot \
		-append "root=/dev/sda2 panic=1 rootfstype=ext4 rw" \
		-drive "file=dist/raspbian_lite.img,index=0,media=disk,format=raw" \
		-net user,hostfwd=tcp::5022-:22 -net nic -pidfile ${TMP_DIR}/qemu.pid -serial mon:stdio

build/id_ed25519:
	ssh-keygen -t ed25519 -f ./build/id_ed25519 -q -N ""

.PNONY: ssh-copy-id
ssh-copy-id: build/id_ed25519
	rm -f ./build/known_hosts && \
	ssh-copy-id -i ./build/id_ed25519.pub pi@localhost -p 5022 -o UserKnownHostsFile=./build/known_hosts

.PNONY: test-bootstrap
test-bootstrap: build/id_ed25519
	ssh pi@localhost -i ./build/id_ed25519.pub -p 5022 -o UserKnownHostsFile=./build/known_hosts bash < ./bootstrap.sh

.PNOHY: test-openvpn-install
test-openvpn-install: build/id_ed25519
	ssh pi@localhost -i ./build/id_ed25519.pub -p 5022 -o UserKnownHostsFile=./build/known_hosts "sudo mkdir /dev/net && sudo mknod /dev/net/tun c 10 200" && \
	ssh pi@localhost -i ./build/id_ed25519.pub -p 5022 -o UserKnownHostsFile=./build/known_hosts "sudo remount rw" && \
	wget https://raw.githubusercontent.com/Nyr/openvpn-install/92d90dac/openvpn-install.sh -O - | ssh pi@localhost -i ./build/id_ed25519.pub -p 5022 -o UserKnownHostsFile=./build/known_hosts "cat > /tmp/openssh-install.sh" && \
	ssh pi@localhost -i ./build/id_ed25519.pub -p 5022 -o UserKnownHostsFile=./build/known_hosts "sudo bash /tmp/openssh-install.sh" && \
	ssh pi@localhost -i ./build/id_ed25519.pub -p 5022 -o UserKnownHostsFile=./build/known_hosts "sudo remount ro"

.PNOHY: test-openvpn
test-openvpn: build/id_ed25519
	ssh pi@localhost -i ./build/id_ed25519.pub -p 5022 -o UserKnownHostsFile=./build/known_hosts bash < ./openvpn.sh

.PNOHY: test-upnp
test-upnp: build/id_ed25519
	ssh pi@localhost -i ./build/id_ed25519.pub -p 5022 -o UserKnownHostsFile=./build/known_hosts bash < ./upnp.sh

.PNOHY: test-ddns
test-ddns: build/id_ed25519
	ssh pi@localhost -i ./build/id_ed25519.pub -p 5022 -o UserKnownHostsFile=./build/known_hosts bash < ./ddns.sh

.PNOHY: test-gist
test-gist: build/id_ed25519
	ssh pi@localhost -i ./build/id_ed25519.pub -p 5022 -o UserKnownHostsFile=./build/known_hosts bash < ./gist.sh
