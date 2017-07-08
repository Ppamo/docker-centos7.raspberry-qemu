#!/bin/bash

# checks
if [ -z "$KERNEL" -o -z "$IMAGE" ]; then
	echo "KERNEL ($KERNEL) or IMAGE ($IMAGE) not defined!"
	exit -1
fi

if [ ! -f $KERNEL ]; then
	echo "Kernel file \"$KERNEL\" does not exists!"
	exit -1
fi
if [ ! -f $IMAGE ]; then
	echo "Image file \"$IMAGE\" does not exists!"
	exit -1
fi
if [ -z "$MEMORY" ]; then
	echo "Using default memory value (256)"
	MEMORY=256
else
	echo "Using $MEMORY memory"
fi

# get the IP and Gateway
IP=$(ip route get 8.8.8.8 | awk 'NR==1 {print $NF}')
GATEWAY=$(ip route get 8.8.8.8 | grep -Eo "via .* dev")
GATEWAY=${GATEWAY:4:(-4)}
echo "using ip=$IP gateway=$GATEWAY"

# prepare the image
FPSTART=$( fdisk -l $IMAGE | grep FAT32 | awk '{ print $2 }')
LPSTART=$( fdisk -l $IMAGE | grep Linux | awk '{ print $2 }')

# enable ssh
mount $IMAGE -o offset=$(( FPSTART * 512 )) /mnt
touch /mnt/ssh
umount /mnt

# set udev qemu rules
mount $IMAGE -o offset=$(( LPSTART * 512 )) /mnt
cat > /mnt/etc/udev/rules.d/90-qemu.rules <<EOF
KERNEL=="sda", SYMLINK+="mmcblk0"
KERNEL=="sda?", SYMLINK+="mmcblk0p%n"
KERNEL=="sda2", SYMLINK+="root"
EOF

# replace rc.local script to setup network
mv /mnt/etc/rc.local /mnt/etc/rc.local.bak

cat > /mnt/etc/rc.local <<EOF
#!/bin/sh -e
#
# rc.local
#

ifconfig eth0 $IP
ip route add default via $GATEWAY dev eth0

# clean up
rm -f /etc/rc.local
mv /etc/rc.local.bak /etc/rc.local
EOF
chmod 755 /mnt/etc/rc.local

# patch ld.so.preload depending on qemu version
QVMAJOR=$( qemu-system-arm --version | grep -Eo "[0-9]\.[0-9]\.[0-9]" | grep -Eo "^[0-9]" )
QVMINOR=$( qemu-system-arm --version | grep -Eo "\.[0-9]\." | grep -Eo "[0-9]" )

if [[ $QVMAJOR -eq 2 ]] && [[ $QVMINOR -lt 8 ]]; then
	sed -i '/^[^#].*libarmmem.so/s/^\(.*\)$/#\1/' /mnt/etc/ld.so.preload
fi
if [[ $QVMAJOR -lt  2 ]]; then
	sed -i '/^[^#].*libarmmem.so/s/^\(.*\)$/#\1/' /mnt/etc/ld.so.preload
fi

umount /mnt

# run qemu
qemu-system-arm -kernel $KERNEL -cpu arm1176 -m $MEMORY -M versatilepb -nographic -no-reboot -append "root=/dev/sda2 panic=1 console=ttyAMA0" -drive format=raw,file=$IMAGE -net nic -net tap,ifname=tap0,script=/etc/qemu-ifup.sh,downscript=no
