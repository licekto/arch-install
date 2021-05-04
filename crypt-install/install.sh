#!/bin/bash

set -xe

# Configuration options
ROOT_PWD="root"
USER_NAME="tomas"
USER_PWD="root"

LOG_FILE="install.log"

# https://unix.stackexchange.com/questions/91620/efi-variables-are-not-supported-on-this-system
efi_test() {
	efivar-tester
	modprobe efivarfs
}

{
ln -sf /usr/share/zoneinfo/Europe/Prague /etc/localtime

hwclock --systohc

sed -i '/#cs_CZ.UTF-8 UTF-8/s/^#//g' /etc/locale.gen
sed -i '/#en_US.UTF-8 UTF-8/s/^#//g' /etc/locale.gen
locale-gen
echo "LANG=en_US.UTF-8" >> /etc/locale.conf

echo "arch" >> /etc/hostname
echo "127.0.0.1			arch.localdomain		arch" >> /etc/hosts

CONF_PATH="/etc/mkinitcpio.conf"
sed -i -E "s/^HOOKS=.*/HOOKS=(base udev autodetect keyboard keymap consolefont modconf block encrypt filesystems fsck)/g" $CONF_PATH
grep "^HOOKS" $CONF_PATH

mkinitcpio -P > /dev/null 2>&1

UUID=$(lsblk -f | grep sda7 | awk '{ print $4 }')
# https://wiki.archlinux.org/index.php/intel_graphics#Screen_flickering
sed -i -E "s/(GRUB_CMDLINE_LINUX=\")/\1cryptdevice=UUID=$UUID:cryptroot root=\/dev\/mapper\/cryptroot i915.enable_psr=0/g" /etc/default/grub
grep "GRUB_CMDLINE_LINUX=" /etc/default/grub

mkdir /mnt/boot
mount /dev/sda1 /mnt/boot

grub-install --target=x86_64-efi --bootloader-id=GRUB --efi-directory=/mnt/boot --recheck
grub-mkconfig -o /boot/grub/grub.cfg
} >> $LOG_FILE 2>&1
echo "Installing packages. It may take some time..."
{
pacman -S --noconfirm \
		  networkmanager network-manager-applet networkmanager-openvpn \
		  dhclient wpa_supplicant bash-completion \
		  xorg-server xorg-xinit xf86-video-intel \
		  xfce4 xfce4-xkb-plugin lightdm lightdm-gtk-greeter sudo \
		  libcanberra libcanberra-pulse xfce4-pulseaudio-plugin \
		  git mc vim yakuake

systemctl enable NetworkManager.service
systemctl enable lightdm.service

sed -i -E 's/^# (%wheel ALL=\(ALL\) ALL)/\1/g' /etc/sudoers
useradd -m -G wheel -s /bin/bash $USER_NAME
printf "$USER_PWD\n$USER_PWD\n" | passwd $USER_NAME
printf "$ROOT_PWD\n$ROOT_PWD\n" | passwd

umount /mnt/boot
} >> $LOG_FILE 2>&1

exit
