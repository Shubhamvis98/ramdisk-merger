#!/sbin/busybox sh

_PATH="$PATH"
export PATH=/sbin

busybox cd /
busybox rm /init

source /sbin/device-params

blink()
{
	for i in `busybox seq $1`
	do
		busybox echo 255 > $LED
		busybox sleep 0.08
		busybox echo 0 > $LED
		busybox sleep 0.08
	done
}

busybox mkdir -m 755 -p /dev/block
busybox mkdir -m 755 -p /dev/input
busybox mkdir -m 555 -p /proc
busybox mkdir -m 755 -p /sys

# create device nodes
busybox mknod -m 600 $EVENT_NODE
busybox mknod -m 666 /dev/null c 1 3

# mount filesystems
busybox mount -t proc proc /proc
busybox mount -t sysfs sysfs /sys

# trigger LED
busybox echo 255 > ${LED}

# keycheck
busybox cat $EVENT > /dev/keycheck &
busybox sleep 3

# android ramdisk
load_image=/sbin/android.cpio

# boot decision
if [ -s /dev/keycheck ]
then
	blink 5
	load_image=/sbin/twrp.cpio
fi

# poweroff LED
busybox echo 0 > ${LED}

# kill the keycheck process
busybox pkill -f "busybox cat ${EVENT}"

# unpack the ramdisk image
busybox cpio -i < ${load_image}

busybox umount /proc
busybox umount /sys

busybox rm -fr /dev/*
export PATH="${_PATH}"
exec /init

