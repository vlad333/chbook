#!/bin/sh
set -x

cpus_count=`cat /proc/cpuinfo | grep processor | wc -l`
work_dir=/usr/src
build_dir=${work_dir}/kernel_build

# Setup locale and timezone
cp /usr/share/zoneinfo/America/Toronto /etc/localtime
echo 'LANG="en_US.UTF-8"' >  /etc/default/locale
echo 'America/Toronto' > /etc/timezone
locale-gen en_US.UTF-8
dpkg-reconfigure -f non-interactive tzdata

# Download the necessary packages to chroot for compiling and signing
apt-get update -y
apt-get install -y vim wget make bc vboot-kernel-utils git wireless-tools wpasupplicant cgpt parted links

cd $work_dir
mkdir ${build_dir}
cp .config ${build_dir}
wget -c -t 10 -T 10 https://www.kernel.org/pub/linux/kernel/v3.x/linux-3.19.tar.xz
tar xvJf linux-3.19.tar.xz
cd linux-3.19
make O=${build_dir} oldconfig
make O=${build_dir} -j${cpus_count}
make O=${build_dir} modules_install firmware_install install headers_install

# Download FW for sound and bluetooth
cd ${work_dir}
git clone git://git.kernel.org/pub/scm/linux/kernel/git/firmware/linux-firmware.git
cp -avf linux-firmware/intel /lib/firmware/

# Download FW for WiFi
cd ${work_dir}
wget https://wireless.wiki.kernel.org/_media/en/users/drivers/iwlwifi-7260-ucode-23.13.10.0.tgz
tar xvzf iwlwifi-7260-ucode-23.13.10.0.tgz
cp iwlwifi-7260-ucode-23.13.10.0/iwlwifi-7260-10.ucode /lib/firmware


# Sign the newly built kernel
vbutil_kernel --pack ${work_dir}/signed_kernel_on_sd_rootfs_on_sd.bin --keyblock /usr/share/vboot/devkeys/kernel.keyblock --signprivate /usr/share/vboot/devkeys/kernel_data_key.vbprivk --version 1 --vmlinuz /boot/vmlinuz-3.19.0 --config ${work_dir}/kernel_cmdline_boot_from_sd.txt --arch x86

vbutil_kernel --pack ${work_dir}/signed_kernel_on_sd_rootfs_on_ssd.bin --keyblock /usr/share/vboot/devkeys/kernel.keyblock --signprivate /usr/share/vboot/devkeys/kernel_data_key.vbprivk --version 1 --vmlinuz /boot/vmlinuz-3.19.0 --config ${work_dir}/kernel_cmdline_boot_from_ssd.txt --arch x86

vbutil_kernel --pack ${work_dir}/signed_kernel_on_usb_rootfs_on_usb.bin --keyblock /usr/share/vboot/devkeys/recovery_kernel.keyblock --signprivate /usr/share/vboot/devkeys/recovery_kernel_data_key.vbprivk --version 1 --vmlinuz /boot/vmlinuz-3.19.0 --config ${work_dir}/kernel_cmdline_boot_from_usb.txt --arch x86

vbutil_kernel --pack ${work_dir}/signed_kernel_on_usb_rootfs_on_sd.bin --keyblock /usr/share/vboot/devkeys/recovery_kernel.keyblock --signprivate /usr/share/vboot/devkeys/recovery_kernel_data_key.vbprivk --version 1 --vmlinuz /boot/vmlinuz-3.19.0 --config ${work_dir}/kernel_cmdline_boot_from_sd.txt --arch x86

vbutil_kernel --pack ${work_dir}/signed_kernel_on_usb_rootfs_on_ssd.bin --keyblock /usr/share/vboot/devkeys/recovery_kernel.keyblock --signprivate /usr/share/vboot/devkeys/recovery_kernel_data_key.vbprivk --version 1 --vmlinuz /boot/vmlinuz-3.19.0 --config ${work_dir}/kernel_cmdline_boot_from_ssd.txt --arch x86

set +x

