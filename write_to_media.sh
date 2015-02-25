#!/bin/sh
set -x
arch=amd64
target=trusty
chroot_dir=trusty_rootfs

work_dir=/usr/src
chroot_work_dir=${chroot_dir}${work_dir}

print_usage ()
{
	echo "write_to_media.sh media_type media_dev_name"
	echo "\tmedia_type: sd or usb"
	echo "\tmedia_dev_name: device name for media.  For example: /dev/sdc, /dev/mmcblk0, /dev/mmcblk1"
}

# Check number of parameters
if [ "$#" -ne 2 ]; then
	echo "Illigal number of parameters, num arguments=$#"
	print_usage
	exit 1
fi

media_type=$1
echo "media_type: ${media_type}"
media_dev_name=$2
echo "media_dev_name: ${media_dev_name}"


signed_kernel_image_file=
kernel_dev=
rootfs_dev=
if [ "${media_type}" = "sd" ]; then
	signed_kernel_image_file=${chroot_work_dir}/signed_kernel_on_sd_rootfs_on_sd.bin
	if [[ ${media_dev_name} != /dev/mmcblk* ]]; then
		echo "For sd type devices only the /dev/mmcblk* form is supported for now"
		exit 10
	fi
	kernel_dev="${media_dev_name}p1"
	rootfs_dev="${media_dev_name}p2"
elif [ "${media_type}" = "usb" ]; then
	signed_kernel_image_file=${chroot_work_dir}/signed_kernel_on_usb_rootfs_on_usb.bin
	if [[ ${media_dev_name} != /dev/sd* ]]; then
		echo "For usb type devices only the /dev/sd* form is supported for now"
		return 20
	fi
	kernel_dev="${media_dev_name}1"
	rootfs_dev="${media_dev_name}2"
else
	echo "Invalid media_type argument: ${media_type}"
	print_usage
	exit 2
fi

# Make sure that the signed kernel image exists
if [ ! -f "${signed_kernel_image_file}" ]; then
	echo "The ${signed_kernel_image_file} does not exists, please make sure that there is signed kernel image"
	print_usage
	exit 3
fi

# Make sure the media_dev_name is a block device
if [ ! -b "${media_dev_name}" ]; then
	echo "The specified media_dev_name (${media_dev_name}) is not a block device or does not exists"
	print_usage
	exit 4
fi


if [ ! -d "${chroot_dir}" ]; then
	echo "The chroot rootfs (${chroot_dir}) does not exist"
	exit 5
fi


media_rootfs=mounted_media_rootfs
sudo mkdir "${media_rootfs}"

if [ "$(ls -A ${media_rootfs})" ]; then
	echo "The directory where the media to be mounted (${media_rootfs} is not empty, please remove it and try again"
	exit 6
fi

echo "All the content on ${media_dev_name} will be erased.  Are you sure you want to continue? Type: yes/no (lowercase): "
read confirmation_answer

media_dev_name=$2
if [ ${confirmation_answer} = "yes" ]; then
	# Create the partition table
	sudo parted ${media_dev_name} mklabel gpt
	if [ $? -ne 0 ]; then
		echo "Failed on a call to parted"
		exit 100
	fi
	sudo cgpt create -z ${media_dev_name}
	if [ $? -ne 0 ]; then
		echo "Failed on the call to cgpt create zeroing up existing parititon table"
		exit 200
	fi
	sudo cgpt create ${media_dev_name}
	if [ $? -ne 0]; then
		echo "Failed on cgpt create creating a new partition table"
		exit 300
	fi
	OFFSET=$(expr 8 \* 1024)
	SIZE=$(expr 64 \* 1024)
	sudo cgpt add -i 1 -t kernel -b $OFFSET -s $SIZE -l kernel -S 1 -T 15 -P 10 ${media_dev_name}
	if [ $? -ne 0 ]; then
		echo "Failed on cgpt add to add kernel partition"
		exit 400
	fi
	OFFSET=$(expr $OFFSET + $SIZE)
	SIZE=$(expr $(sudo cgpt show ${media_dev_name} | grep "Sec GPT table" | tr -s " " | cut -f2 -d' ') - $OFFSET)
	sudo cgpt add -i 2 -t data -b $OFFSET -s $SIZE -l root ${media_dev_name}
	if [ $? -ne 0 ]; then
		echo "Failed on cgpt add to add root partition"
		exit 500
	fi

	sudo sync
	sudo blockdev --rereadpt ${media_dev_name}
	sudo partprobe ${media_dev_name}


	# Just print the new gpt partition table
	sudo cgpt show ${media_dev_name}

	# Copy the kernel
	sudo dd if=${signed_kernel_image_file} of=${kernel_dev} bs=1M
	if [ $? -ne 0 ]; then
		echo "Failed to copy signed image into media"
		exit 600
	fi

	# Format the root partition on the media
	sudo mkfs.ext4 ${rootfs_dev}
	if [ $? -ne 0 ]; then
		echo "Failed to format root partition on media"
		exit 700
	fi

	sudo mount ${rootfs_dev} ${media_rootfs}
	if [ $? -ne 0 ]; then
		echo "Failed to mount root partition on the media"
		exit 800
	fi
	sudo cp -avf ${chroot_dir}/* ${media_rootfs}/

	sudo umount ${media_rootfs}
	if [ $? -ne 0 ]; then
		echo "Failed to unmount root partition on media"
		exit 900
	fi
fi


set +x
