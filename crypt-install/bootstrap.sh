#!/bin/bash

set -xe

# Configuration options
DEVICE="sda"
DEVICE_PATH="/dev/$DEVICE"
WIN_PARTITION_SIZE="2GiB"
SHARED_PARTITION_SIZE="1GiB"
SWAP_PARTITION_SIZE="1GiB"
LINUX_PARTITION_SIZE="0"
CRYPTROOT_PWD="root"

LOG_FILE="bootstrap.log"

# https://linux.die.net/man/8/sgdisk
new_part() {
	local part_num="$1"
	local size="$2"
	local typecode="$3"
	local label="$4"
	if [ $size != 0 ]; then
		size="+$size"
	fi
	sgdisk --new="$part_num":0:"$size" --typecode="$part_num":"$typecode" --change-name="$part_num":"$label" $DEVICE_PATH
}

setup_partitions()
{
    echo "Setting up partitions..."
    BLOCK_SIZE=$(cat /sys/class/block/$DEVICE/queue/physical_block_size)
    TOTAL_SIZE=$(lsblk --output SIZE -n -d $DEVICE_PATH | sed 's/^ *//g')
    RANDOM_DEVICE="/dev/random"

    echo "Device to be modified: $DEVICE_PATH, block size=$BLOCK_SIZE, total size=$TOTAL_SIZE"
    echo "Wiping the partitions..."
    wipefs -a $DEVICE_PATH > /dev/null

    echo "Overwriting the disk with random data ($RANDOM_DEVICE). It may take some time..."
    dd if=$RANDOM_DEVICE of=$DEVICE_PATH bs=$BLOCK_SIZE status=progress
    cryptsetup open --type plain -d /dev/random $DEVICE_PATH to_be_wiped
    dd if=/dev/zero of=/dev/mapper/to_be_wiped status=progress
    cryptsetup close to_be_wiped

    echo "Creating partitions..."
    sgdisk --zap-all $DEVICE_PATH
    sgdisk --clear $DEVICE_PATH

    new_part 1 500MiB ef00 efi
    new_part 2 64MiB 0c01 msr
    new_part 3 $WIN_PARTITION_SIZE 0700 win10
    new_part 4 300MiB 0700 win_recovery
    new_part 5 $SHARED_PARTITION_SIZE 0700 shared
    new_part 6 $SWAP_PARTITION_SIZE 8200 cryptswap
    new_part 7 $LINUX_PARTITION_SIZE 8300 cryptroot

    mkfs.fat -F32 -n EFI /dev/sda1
    mkfs.fat -F32 /dev/sda2
    mkfs.ntfs /dev/sda3
    mkfs.ntfs /dev/sda4
    mkfs.ntfs /dev/sda5

    printf "$CRYPTROOT_PWD" | cryptsetup --align-payload=8192 -s 256 -v -q luksFormat /dev/disk/by-partlabel/cryptroot -
    printf "$CRYPTROOT_PWD" | cryptsetup open /dev/disk/by-partlabel/cryptroot cryptroot

    mkfs.ext4 /dev/mapper/cryptroot
    mount /dev/mapper/cryptroot /mnt

    cryptsetup open --type plain --key-file /dev/urandom /dev/disk/by-partlabel/cryptswap cryptswap
    mkswap -L cryptswap /dev/mapper/cryptswap
    swapon -L cryptswap

    mkdir /mnt/boot
    mount /dev/sda1 /mnt/boot

    echo "New partitions:"
    echo "---------------"
    parted -l
}
#>> $LOG_FILE 2>&1

echo "Bootstrapping the base system..."
{

pacstrap /mnt base base-devel linux linux-firmware intel-ucode grub efibootmgr os-prober openssh vim parted

echo "Generating fstab"
genfstab -U /mnt >> /mnt/etc/fstab

sed -i '/swap/d' /mnt/etc/fstab
echo "/dev/mapper/cryptswap		none 		swap 		sw 		0 0" >> /mnt/etc/fstab

SWAP_SETTINGS=$(grep swap /mnt/etc/crypttab | awk '{ print $5 }')
echo "cryptswap		/dev/disk/by-partlabel/cryptswap 	/dev/urandom $SWAP_SETTINGS" >> /mnt/etc/crypttab

INSTALL_SCRIPT="install.sh"
echo "Downloading $INSTALL_SCRIPT..."
curl -o $INSTALL_SCRIPT https://raw.githubusercontent.com/licekto/arch-install/master/$INSTALL_SCRIPT

chmod +x $INSTALL_SCRIPT
cp $INSTALL_SCRIPT /mnt
echo "Chrooting to the new system..."
} >> $LOG_FILE 2>&1

echo "The base system has been successfully bootstrapped. Configuring the system..."
arch-chroot /mnt ./$INSTALL_SCRIPT

{
rm /mnt/$INSTALL_SCRIPT
mv /mnt/install.log .

umount /mnt/boot
umount /mnt

cryptsetup close /dev/mapper/cryptroot
swapoff /dev/mapper/cryptswap
cryptsetup close /dev/mapper/cryptswap
} >> $LOG_FILE 2>&1

echo "The base system has been successfully installed."
