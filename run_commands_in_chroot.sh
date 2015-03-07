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
apt-get install -y -f vim wget make bc git wireless-tools net-tools wpasupplicant parted links sudo man locate isc-dhcp-client
#apt-get install -y -f ubuntu-minimal
apt-get install -y -f kubuntu-desktop


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


# Add chronos user with password chronos
useradd --create-home --groups sudo --user-group chronos
echo chronos:chronos | chpasswd

# Partially config wifi
cd /etc/wpa_supplicant
gunzip /usr/share/doc/wpa_supplicant/examples/wpa_supplicant.conf.gz
echo "iface wlan0 inet manual" >> /etc/network/interfaces
echo "wpa-roam /etc/wpa_supplicant/wpa_supplicant.conf" >> /etc/network/interfaces
echo "iface default inet dhcp" >> /etc/network/interfaces


# the following packages are necessary to compile vboot
apt-get install -y -f libssl-dev pkg-config liblzma-dev libyaml-dev uuid-dev

# Install vboot (cgpt, vbutil_kernel, keys, ...)
cd ${work_dir}
git clone https://chromium.googlesource.com/chromiumos/platform/vboot_reference
cd vboot_reference
git checkout d7d9d3b6699ec8af3da14f0a2d4660744b945252
make genkeys futil cgpt
make install
mkdir -p /usr/share/vboot
cp -avf tests/devkeys /usr/share/vboot


# Sign the newly built kernel
vbutil_kernel --pack ${work_dir}/signed_kernel_on_sd_rootfs_on_sd.bin --keyblock /usr/share/vboot/devkeys/kernel.keyblock --signprivate /usr/share/vboot/devkeys/kernel_data_key.vbprivk --version 1 --vmlinuz /boot/vmlinuz-3.19.0 --bootloader ${work_dir}/bootstub.efi --config ${work_dir}/kernel_cmdline_boot_from_sd.txt --arch x86

vbutil_kernel --pack ${work_dir}/signed_kernel_on_sd_rootfs_on_ssd.bin --keyblock /usr/share/vboot/devkeys/kernel.keyblock --signprivate /usr/share/vboot/devkeys/kernel_data_key.vbprivk --version 1 --vmlinuz /boot/vmlinuz-3.19.0 --bootloader ${work_dir}/bootstub.efi --config ${work_dir}/kernel_cmdline_boot_from_ssd.txt --arch x86

vbutil_kernel --pack ${work_dir}/signed_kernel_on_usb_rootfs_on_usb.bin --keyblock /usr/share/vboot/devkeys/recovery_kernel.keyblock --signprivate /usr/share/vboot/devkeys/recovery_kernel_data_key.vbprivk --version 1 --vmlinuz /boot/vmlinuz-3.19.0 --bootloader ${work_dir}/bootstub.efi --config ${work_dir}/kernel_cmdline_boot_from_usb.txt --arch x86

vbutil_kernel --pack ${work_dir}/signed_kernel_on_usb_rootfs_on_sd.bin --keyblock /usr/share/vboot/devkeys/recovery_kernel.keyblock --signprivate /usr/share/vboot/devkeys/recovery_kernel_data_key.vbprivk --version 1 --vmlinuz /boot/vmlinuz-3.19.0 --bootloader ${work_dir}/bootstub.efi --config ${work_dir}/kernel_cmdline_boot_from_sd.txt --arch x86

vbutil_kernel --pack ${work_dir}/signed_kernel_on_usb_rootfs_on_ssd.bin --keyblock /usr/share/vboot/devkeys/recovery_kernel.keyblock --signprivate /usr/share/vboot/devkeys/recovery_kernel_data_key.vbprivk --version 1 --vmlinuz /boot/vmlinuz-3.19.0 --bootloader ${work_dir}/bootstub.efi --config ${work_dir}/kernel_cmdline_boot_from_ssd.txt --arch x86

set +x

