#!/bin/sh
set -x
arch=amd64
target=xenial
chroot_dir=xenial_rootfs

# MAKE SURE THE FOLDER IS MOUNTED AS DEV,EXEC:
# mount -i -o remount,exec,dev /home/vlad

# Install git and debootstrap on the host
sudo apt-get update
sudo apt-get install cgpt
sudo apt-get install -y -f debootstrap

# Create chroot 
mkdir ${chroot_dir}
sudo debootstrap --arch=${arch} --variant=buildd ${target} ${chroot_dir}

# Need to bind /dev, /dev/pts, /proc, and /sys before entering chroot
#sudo mount --bind /dev $chroot_dir/dev
sudo mount --bind /dev/pts $chroot_dir/dev/pts
sudo mount -t proc proc $chroot_dir/proc
sudo mount -t sysfs sys $chroot_dir/sys

# Copy necessary files to the chroot
apt_sources_file=sources.list
chroot_apt_sources_file=${chroot_dir}/etc/apt/sources.list
sudo cp ${apt_sources_file} ${chroot_apt_sources_file}
work_dir=/usr/src
chroot_work_dir=${chroot_dir}${work_dir}
sudo cp .config ${chroot_work_dir}
sudo cp kernel_cmdline_boot_from_sd.txt ${chroot_work_dir}
sudo cp kernel_cmdline_boot_from_ssd.txt ${chroot_work_dir}
sudo cp kernel_cmdline_boot_from_usb.txt ${chroot_work_dir}
sudo cp bootstub.efi ${chroot_work_dir}
sudo cp run_commands_in_chroot.sh ${chroot_work_dir}
sudo cp write_to_media.sh ${chroot_work_dir}

# Run script in chroot
sudo chroot ${chroot_dir} /bin/bash -x ${work_dir}/run_commands_in_chroot.sh

# Need to inbind /dev, /dev/pts, /proc, and /sys after leaving chroot
sudo umount $chroot_dir/dev/pts
#sudo umount $chroot_dir/dev
sudo umount $chroot_dir/proc
sudo umount $chroot_dir/sys

tar cvjf ${chroot_dir}.tar.bz2 ${chroot_dir}
mv ${chroot_dir}.tar.bz2 ${chroot_dir}/

set +x
