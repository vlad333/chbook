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

sudo cp asound.state ${chroot_dir}/var/lib/alsa/asound.state
sudo mkdir ${chroot_dir}/etc/X11/xorg.conf.d
sudo cp 20-intel.conf ${chroot_dir}/etc/X11/xorg.conf.d/

# Need to inbind /dev, /dev/pts, /proc, and /sys after leaving chroot
sudo umount $chroot_dir/dev/pts
#sudo umount $chroot_dir/dev
sudo umount $chroot_dir/proc
sudo umount $chroot_dir/sys


# Create a loopback partition, and copy the chroot_dir into it
loopback_file_name=${chroot_dir}.loopback
loopback_mount_name=${loopback_file_name}.mount

chroot_dir_size=$(du -s -B 1 ${chroot_dir} | cut -f 1)
echo "${chroot_dir} is ${chroot_dir_size} bytes"
bytes_in_mb=$((1024*1024))
chroot_dir_size_in_mb=$((${chroot_dir_size} / ${bytes_in_mb}))
loopback_file_size_in_mb=$((${chroot_dir_size_in_mb} + 100))
loopback_file_size=$((${loopback_file_size_in_mb} * ${bytes_in_mb}))
dd if=/dev/zero of=${loopback_file_name} bs=1 seek=$((${loopback_file_size}-1)) count=1

loopback_device_name=$(losetup -f)
losetup ${loopback_device_name} ${loopback_file_name}
mkfs.ext4 ${loopback_device_name}
mkdir -p ${loopback_mount_name}
mount ${loopback_device_name}  ${loopback_mount_name}
cp -avf ${chroot_dir}/ ${loopback_mount_name}/
umount ${loopback_mount_name}
losetup -d ${loopback_device_name}

bzip2 ${loopback_file_name}

mv ${loopback_file_name}.bz2 ${chroot_work_dir}/

set +x
