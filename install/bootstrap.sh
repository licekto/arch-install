#!/bin/bash

set -xe

source install.cfg

LOG_FILE="bootstrap.log"

bootstrap()
{
    printf "y\n" | mkfs.ext4 $LINUX_DEV
    e2label $LINUX_DEV Arch
    mount $LINUX_DEV /mnt
    swapon $SWAP_DEV

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
