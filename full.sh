#!/bin/sh
set -x
arch=amd64
target=trusty
chroot_dir=trusty_rootfs

# Create chroot 
mkdir ${chroot_dir}
sudo debootstrap --arch=${arch} --variant=buildd ${target} ${chroot_dir}

# Need to bind /dev, /dev/pts, /proc, and /sys before entering chroot
sudo mount --bind /dev $chroot_dir/dev
sudo mount --bind /dev/pts $chroot_dir/dev/pts
sudo mount -t proc proc $chroot_dir/proc
sudo mount -t sysfs sys $chroot_dir/sys

# Copy necessary files to the chroot
apt_sources_file=/etc/apt/sources.list
chroot_apt_sources_file=${chroot_dir}${apt_sources_file}
sudo cp ${apt_sources_file} ${chroot_apt_sources_file}
chroot_work_dir=${chroot_dir}/usr/src
sudo cp .config ${chroot_work_dir}
sudo cp kernel_cmdline.txt ${chroot_work_dir}
sudo cp run_commands_in_chroot.sh ${chroot_work_dir}

# Run script in chroot
sudo chroot ${chroot_dir} /bin/bash -x ${chroot_work_dir}/run_commands_in_chroot.sh

# Need to inbind /dev, /dev/pts, /proc, and /sys after leaving chroot
sudo umount $chroot_dir/dev/pts
sudo umount $chroot_dir/dev
sudo umount $chroot_dir/proc
sudo umount $chroot_dir/sys


set +x
