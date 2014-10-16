#!/bin/bash
set -e

# Copyright (c) 2010-2012 Jeff Doozan
#               2014 Tianon Gravi
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.

# Version 2.0    [2014-02-17] Tianon

# Version 1.3    [1/24/2013] Revised by Daniel Richard G.
# Version 1.2    [7/14/2012] Fixed to work with latest debootstrap
# Version 1.1    [4/25/2012] Download files from download.doozan.com
# Version 1.0    [8/8/2010] Initial Release

export PATH='/sbin:/usr/sbin:/bin:/usr/bin:/usr/local/sbin:/usr/local/bin'

root=/mnt

# these are expected to be formatted already (ext3 and swap, respectively)
rootDev=/dev/sda1
swapDev=/dev/sda2

hostname=pogoplug
rootPassword=root
kernelPackage=linux-image-kirkwood

suite=squeeze
variant=minbase
arch=armel
packages=(
	"$kernelPackage"
	
	dhcpcd
	flash-kernel
	ifupdown
	iproute
	module-init-tools
	net-tools
	netbase
	ntpdate
	openssh-server
	uboot-envtools
	uboot-mkimage
	udev
	wget
	
	# nice to haves
	bash-completion
	dialog
	iputils-ping
	ntp
	rsync
	vim-nox
	
	# shut up, dpkg/apt
	apt-utils libterm-readline-gnu-perl
)

dooMirror='http://download.doozan.com'
debMirror='http://http.debian.net/debian'
secMirror='http://security.debian.org'

debootstrapUrl="$debMirror/pool/main/d/debootstrap/debootstrap_1.0.26+squeeze1_all.deb" # from "$debMirror/dists/squeeze/main/binary-armel/Packages.bz2"
pkgdetailsUrl="$dooMirror/debian/pkgdetails" # some random utility debootstrap likes to have

# let's do some bash hackery to get us a comma-separated list from that handy and easy to modify array :)
IFS=','
include="${packages[*]}"
unset IFS

mkdir -p "$root"
if ! grep -q "^$swapDev" /proc/swaps; then
	swapon "$swapDev"
fi
if ! mountpoint -q "$root"; then
	mount "$rootDev" "$root"
fi

if [ ! -e /usr/sbin/debootstrap ]; then
	rm -rf /tmp/debootstrap
	mkdir -p /tmp/debootstrap
	cd /tmp/debootstrap
	
	wget -O debootstrap.deb "$debootstrapUrl"
	ar xv debootstrap.deb
	tar xzvf data.tar.gz
	
	wget -O usr/share/debootstrap/pkgdetails "$pkgdetailsUrl"
	chmod 755 usr/share/debootstrap/pkgdetails
	
	mount -o remount,rw /
	mv usr/sbin/debootstrap /usr/sbin/
	mv usr/share/debootstrap /usr/share/
	mount -o remount,ro /
fi

debootstrap --verbose --arch="$arch" --variant="$variant" --include="$include" "$suite" "$root" "$debMirror"

cat <<-EOF > "$root/etc/apt/sources.list"
	deb $debMirror $suite main
EOF
if [ "$suite" != 'sid' ] && [ "$suite" != 'unstable' ]; then
	cat <<-EOF >> "$root/etc/apt/sources.list"
		deb $debMirror $suite-updates main
		deb $secMirror $suite/updates main
	EOF
fi

echo 'Acquire::Languages "none";' > "$root/etc/apt/apt.conf.d/no-languages"

echo "$hostname" > "$root/etc/hostname"
echo 'LANG=C' > "$root/etc/default/locale"

cat <<-EOF > "$root/etc/fw_env.config"
	# Configuration file for fw_(printenv/saveenv) utility.
	# Up to two entries are valid; in this case the redundant
	# environment sector is assumed present.
	# Note that "Number of sectors" is ignored on NOR.
	
	# MTD device name	Device offset	Env. size	Flash sector size	Number of sectors
	/dev/mtd0			0xc0000			0x20000		0x20000
EOF

cat <<-EOF > "$root/etc/network/interfaces"
	auto lo
	iface lo inet loopback
	
	auto eth0
	iface eth0 inet dhcp
EOF

cat <<-EOF > "$root/etc/resolv.conf"
	nameserver 8.8.8.8
	nameserver 8.8.4.4
EOF

mount --rbind /dev /mnt/dev
rootUuid="$(chroot "$root" blkid -o value -s UUID "$rootDev")" # "fe4deba0-d934-433f-8fee-79bb905aeb32"
swapUuid="$(chroot "$root" blkid -o value -s UUID "$swapDev")" # "447e0572-5743-4d18-9d52-05dc77b63bfe"
umount /mnt/dev

cat <<-EOF > "$root/etc/fstab"
	# fs	mount	type	options	dump pass
	
	UUID=$rootUuid	/	ext3	noatime,errors=remount-ro	0 1
	
	UUID=$swapUuid	none	swap	sw	0 0
	
	tmpfs	/tmp	tmpfs	defaults	0 0
EOF

# take it easy on your USB drive, bro
echo 'vm.swappiness = 10' > "$root/etc/sysctl.d/swap.conf"

echo 'T0:2345:respawn:/sbin/getty -L ttyS0 115200 linux' >> "$root/etc/inittab"
sed -i 's/^\([1-6]:.* tty[1-6]\)/#\1/' "$root/etc/inittab"

echo 'HWCLOCKACCESS=no' >> "$root/etc/default/rcS"

rm -f "$root/etc/blkid.tab"

rm -f "$root/etc/mtab"
ln -sf /proc/mounts "$root/etc/mtab"

echo "root:$rootPassword" | chroot "$root" chpasswd

cat <<-'EOF' > "$root/mkimage.sh"
	#!/bin/bash
	set -e
	
	set -x
	mkimage -A arm -O linux -T kernel -C none -a 0x00008000 -e 0x00008000 -n 'vmlinuz-2.6.32-5-kirkwood' -d boot/vmlinuz-2.6.32-5-kirkwood boot/uImage
	mkimage -A arm -O linux -T ramdisk -C none -a 0x00000000 -e 0x00000000 -n 'initrd.img-2.6.32-5-kirkwood' -d boot/initrd.img-2.6.32-5-kirkwood boot/uInitrd
EOF
chmod +x "$root/mkimage.sh"
chroot "$root" /mkimage.sh

chroot "$root" apt-get update
chroot "$root" apt-get install -y "$kernelPackage"
chroot "$root" apt-get clean

umount "$root"
swapoff "$swapDev"

echo
echo
echo
echo 'You are _probably_ safe to reboot now. :)'
echo 'FYI, the root password on your new device is "'"$rootPassword"'".'
echo
