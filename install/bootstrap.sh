#!/bin/bash

set -xe

source install.cfg

LOG_FILE="bootstrap.log"

encrypt_part()
{
    BLOCK_SIZE=$(cat /sys/class/block/$DEVICE/queue/physical_block_size)
    TOTAL_SIZE=$(lsblk --output SIZE -n -d $LINUX_DEV | sed 's/^ *//g')
    RANDOM_DEVICE="/dev/random"

    #echo "Overwriting the disk with random data ($RANDOM_DEVICE). It may take some time..."
    #printf "YES" | cryptsetup open --type plain -d /dev/random $LINUX_DEV to_be_wiped
    #dd if=/dev/zero of=/dev/mapper/to_be_wiped status=progress
    #cryptsetup close to_be_wiped

    printf "$CRYPTROOT_PWD" | cryptsetup --align-payload=8192 -s 256 -v -q luksFormat $LINUX_DEV -
    printf "$CRYPTROOT_PWD" | cryptsetup open $LINUX_DEV cryptroot

    mkfs.ext4 /dev/mapper/cryptroot
    mount /dev/mapper/cryptroot /mnt
    mkfs.ext4 -L cryptswap $SWAP_DEV 1M
}

cleanup_boot()
{
    cd /mnt/boot
    rm -rf initramfs-linux.img initramfs-linux-fallback.img intel-ucode.img syslinux vmlinuz-linux
    rm -rf grub
    rm -rf EFI/grub
}

close_encrypt()
{
    umount -R /mnt
    cryptsetup close /dev/mapper/cryptroot
}

prepare_non_crypt()
{
    printf "y\n" | mkfs.ext4 $LINUX_DEV
    e2label $LINUX_DEV Arch
    mount $LINUX_DEV /mnt
    mkswap $SWAP_DEV
    swapon $SWAP_DEV
}

bootstrap()
{
    mkdir /mnt/boot
    mount /dev/sda1 /mnt/boot
    ls /mnt/boot
    (cleanup_boot)

    pacstrap -G -M /mnt base base-devel linux linux-firmware intel-ucode grub efibootmgr os-prober openssh vim
    genfstab -U /mnt >> /mnt/etc/fstab

    sed -i '/swap/d' /mnt/etc/fstab
    echo "/dev/mapper/swap		none		swap		sw		0 0" >> /mnt/etc/fstab
    SWAP_SETTINGS=$(grep swap /mnt/etc/crypttab | awk '{ print $5 }' | sed 's/,size=.*/,offset=2048,size=512/')
    echo "swap	LABEL=cryptswap	/dev/urandom $SWAP_SETTINGS" >> /mnt/etc/crypttab

    cp -r /install /mnt
    chmod +x /mnt/install/install.sh
}

echo "Testing internet connection..."
ping archlinux.org -c1 > ping.log 2>&1

echo "Preparing encrypted partition..."
encrypt_part >> $LOG_FILE 2>&1

echo "Bootstrapping the base system. It may take several minutes..."
bootstrap >> $LOG_FILE 2>&1

echo "The base system has been successfully bootstrapped. Configuring the system..."
arch-chroot /mnt /install/install.sh

mkdir /mnt/$HOME_DIR/install-logs
mv /mnt/install/*.log /mnt/$HOME_DIR/install-logs

rm -rf /mnt/install
close_encrypt >> $LOG_FILE 2>&1

echo "The base system has been successfully installed. Ready for reboot..."

