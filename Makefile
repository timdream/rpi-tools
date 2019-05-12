IMAGE_NAME=2019-04-08-raspbian-stretch-lite
QEMU=$(shell which qemu-system-arm)
TMP_DIR=build
RPI_KERNEL=${TMP_DIR}/kernel-qemu-4.14.79-stretch
RPI_FS=${TMP_DIR}/${IMAGE_NAME}.img
PTB_FILE=${TMP_DIR}/versatile-pb.dtb
IMAGE_FILE=${TMP_DIR}/${IMAGE_NAME}.zip
IMAGE=http://downloads.raspberrypi.org/raspbian_lite/images/raspbian_lite-2019-04-09/${IMAGE_NAME}.zip

.PHONY: all
all: dist/raspbian_lite.img

${RPI_KERNEL}:
	mkdir -p ${TMP_DIR} && \
	wget https://github.com/dhruvvyas90/qemu-rpi-kernel/blob/master/kernel-qemu-4.14.79-stretch?raw=true \
	  -O ${RPI_KERNEL}

${PTB_FILE}:
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
