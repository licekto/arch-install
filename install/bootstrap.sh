#!/bin/bash

set -xe

source install.cfg

LOG_FILE="bootstrap.log"

encrypt_part()
{
    BLOCK_SIZE=$(cat /sys/class/block/$DEV/queue/physical_block_size)
    TOTAL_SIZE=$(lsblk --output SIZE -n -d $LINUX_DEV | sed 's/^ *//g')
    RANDOM_DEVICE="/dev/random"
    
    e2label $LINUX_DEV cryptroot
    e2label $SWAP_DEV cryptswap

    echo "Overwriting the disk with random data ($RANDOM_DEVICE). It may take some time..."
    dd if=$RANDOM_DEVICE of=$LINUX_DEV bs=$BLOCK_SIZE status=progress
    cryptsetup open --type plain -d /dev/random $LINUX_DEV to_be_wiped
    dd if=/dev/zero of=/dev/mapper/to_be_wiped status=progress
    cryptsetup close to_be_wiped

    printf "$CRYPTROOT_PWD" | cryptsetup --align-payload=8192 -s 256 -v -q luksFormat $LINUX_DEV -
    printf "$CRYPTROOT_PWD" | cryptsetup open $LINUX_DEV cryptroot

    mkfs.ext4 /dev/mapper/cryptroot
    mount /dev/mapper/cryptroot /mnt

    cryptsetup open --type plain --key-file /dev/urandom $SWAP_DEV cryptswap
    mkswap -L cryptswap /dev/mapper/cryptswap
    swapon -L cryptswap
}

close_encrypt()
{
    umount /mnt/boot
    umount -R /mnt

    cryptsetup close /dev/mapper/cryptroot
    swapoff /dev/mapper/cryptswap
    cryptsetup close /dev/mapper/cryptswap
}

bootstrap()
{
    printf "y\n" | mkfs.ext4 $LINUX_DEV
    e2label $LINUX_DEV Arch
    mount $LINUX_DEV /mnt
    swapon $SWAP_DEV
    mount /dev/sda1 /mnt/boot

    pacstrap -G -M /mnt base base-devel linux linux-firmware intel-ucode grub efibootmgr os-prober openssh vim
    genfstab -U /mnt >> /mnt/etc/fstab

    cp -r /install /mnt
}

echo "Testing internet connection..."
ping archlinux.org -c1 > ping.log 2>&1
echo "Bootstrapping the base system. It may take several minutes..."
bootstrap >> $LOG_FILE 2>&1
echo "The base system has been successfully bootstrapped. Configuring the system..."

arch-chroot /mnt /install/install.sh

mkdir /mnt/$HOME_DIR/install-logs
mv /mnt/install/*.log /mnt/$HOME_DIR/install-logs

rm -rf /mnt/install
umount -R /mnt

echo "The base system has been successfully installed. Ready for reboot..."
