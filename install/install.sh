#!/bin/bash

set -xe

source /install/install.cfg

LOG_FILE="/install/install.log"

# https://unix.stackexchange.com/questions/91620/efi-variables-are-not-supported-on-this-system
efi_test() {
    efivar-tester
    modprobe efivarfs
}

set_mkinitcpio()
{
    CONF_PATH="/etc/mkinitcpio.conf"
    sed -i -E "s/^HOOKS=.*/HOOKS=(base udev autodetect keyboard keymap consolefont modconf block filesystems fsck)/g" $CONF_PATH
    grep "^HOOKS" $CONF_PATH
    mkinitcpio -P > /dev/null 2>&1
}

basic_conf()
{
    ln -sf /usr/share/zoneinfo/Europe/Prague /etc/localtime
    hwclock --systohc

    sed -i '/#cs_CZ.UTF-8 UTF-8/s/^#//g' /etc/locale.gen
    sed -i '/#en_US.UTF-8 UTF-8/s/^#//g' /etc/locale.gen
    locale-gen
    echo "LANG=en_US.UTF-8" >> /etc/locale.conf

    echo "arch" >> /etc/hostname
    echo "127.0.0.1			arch.localdomain		arch" >> /etc/hosts

    #set_mkinitcpio

    mount /dev/sda1 /boot
    grub-mkconfig -o /boot/grub/grub.cfg
}

add_user()
{
    sed -i -E 's/^# (%wheel ALL=\(ALL\) ALL)/\1/g' /etc/sudoers
    useradd -m -G wheel -s /bin/bash $USER_NAME
    printf "$PASSWORD\n$PASSWORD\n" | passwd $USER_NAME
    printf "$PASSWORD\n$PASSWORD\n" | passwd
}

sudo_pwd()
{
    if [[ $1 == "off" ]];
    then
        sed -i -E 's/(\%wheel ALL=\(ALL\)) ALL/\1 NOPASSWD:ALL/g' /etc/sudoers
    elif [[ $1 == "on" ]];
    then
        sed -i -E 's/(\%wheel ALL=\(ALL\)) NOPASSWD:ALL/\1 ALL/g' /etc/sudoers
    fi
}

install_yay()
{
    git clone https://aur.archlinux.org/yay-git.git /opt/yay-git
    chown -R $USER_NAME /opt/yay-git
    cd /opt/yay-git
    sudo -u $USER_NAME makepkg --noconfirm --syncdeps --install --clean --check
    sudo -u $USER_NAME yay -S --noconfirm --answerdiff=None brave-bin sublime-text-3
}

packages_conf()
{
    sed -i '/^#.*ftp.sh.cvut.cz/s/^#//' /etc/pacman.d/mirrorlist
    pacman-key --init
    pacman-key --populate archlinux
    pacman -Syy
    pacman -Syu --noconfirm
    pacman -S --noconfirm - < /install/pkglist.txt
    systemctl enable NetworkManager
    systemctl enable lightdm
    systemctl enable bluetooth
}

custom_kernel()
{
    VERSION="5.11.15.arch1-1"
    LINUX_PKG="https://archive.archlinux.org/packages/l/linux/linux-$VERSION-x86_64.pkg.tar.zst"
    LINUX_HEADERS_PKG="https://archive.archlinux.org/packages/l/linux-headers/linux-headers-$VERSION-x86_64.pkg.tar.zst"
    pacman -U --noconfirm $LINUX_PKG $LINUX_HEADERS_PKG
    # IgnorePkg   = linux linux-api-headers linux-headers linux-firmware
}

configure()
{
    cp /install/configs/menu-icon.png /usr/share/icons/menu-icon.png

    XFCONF_DIR="$HOME_DIR/.config/xfce4/xfconf/xfce-perchannel-xml"
    mkdir -p $XFCONF_DIR
    cp /install/configs/xfce/* $XFCONF_DIR
    mkdir -p $HOME_DIR/.config/xfce4/panel
    cp /install/configs/whiskermenu-1.rc $HOME_DIR/.config/xfce4/panel

    mkdir -p $HOME_DIR/.config/autostart/
    cp /install/configs/yakuake.desktop $HOME_DIR/.config/autostart

    mkdir -p $HOME_DIR/.config/mc/
    cp /install/configs/mc_ini $HOME_DIR/.config/mc/ini
    mkdir -p $HOME_DIR/.config/vlc
    cp /install/configs/vlcrc $HOME_DIR/.config/vlc

    mkdir -p $HOME_DIR/.local/share/konsole
    mkdir -p $HOME_DIR/.config/BraveSoftware/Brave-Browser

    cp /install/configs/yakuakerc $HOME_DIR/.config/yakuakerc
    cp /install/configs/Profile.profile $HOME_DIR/.local/share/konsole/Profile.profile
    cp /install/configs/Local\ State $HOME_DIR/.config/BraveSoftware/Brave-Browser/
    cp /install/configs/nobeep.conf /etc/modprobe.d
    cp /install/configs/mimeapps.list $HOME_DIR/.config
}

setup_keys()
{
    chmod 600 /install/key/*
    cp -r /install/key/ "$1"
    mv "$1/key" "$1/.ssh"
    eval `ssh-agent`
    ssh-keyscan github.com >> "$1/.ssh/known_hosts"
}

setup_home()
{
    mkdir -p $HOME_DIR/workspace
    mkdir -p $HOME_DIR/mounts
    mkdir -p $HOME_DIR/downloads

    ln -s /mnt $HOME_DIR/mounts
    ln -s /run/media $HOME_DIR/mounts

    setup_keys "$HOME_DIR"

    chown -R $USER_NAME $HOME_DIR
    chgrp -R $USER_NAME $HOME_DIR
}

clean_root_keys()
{
    rm -rf /root/.ssh
}

set_rcs()
{
    git clone git@github.com:licekto/rcs.git $HOME_DIR/.rcs
    git clone git@github.com:licekto/scripts.git $HOME_DIR/.bin

    TMP_CONF_DIR="$HOME_DIR/arch-conf"

    git clone git@github.com:licekto/arch-conf.git $TMP_CONF_DIR

    ln -s $HOME_DIR/.rcs/gitconfig $HOME_DIR/.gitconfig
    ln -s $HOME_DIR/.rcs/vimrc $HOME_DIR/.vimrc
    git config --global core.excludesfile $HOME_DIR/.rcs/gitignore

    touch $HOME_DIR/.bashrc
    echo "source $HOME_DIR/.rcs/bashrc" >> $HOME_DIR/.bashrc
    cat $TMP_CONF_DIR/bashrc.append >> $HOME_DIR/.bashrc

    cat $TMP_CONF_DIR/fstab.append >> /etc/fstab
    cat $TMP_CONF_DIR/hosts.append >> /etc/hosts
    rm -rf $TMP_CONF_DIR
}

touch $LOG_FILE

echo "Configuring the base system..."
basic_conf >> $LOG_FILE 2>&1
echo "Adding user $USER_NAME"
add_user >> $LOG_FILE 2>&1
echo "Installing packages. It may take some time..."
packages_conf > $LOG_FILE 2>&1

# Uncomment if a specific kernel version is desired
#echo "Installing specific kernel version..."
#custom_kernel >> $LOG_FILE 2>&1

echo "Installing yay and yay packages..."
sudo_pwd "off" >> $LOG_FILE 2>&1
install_yay >> $LOG_FILE 2>&1
sudo_pwd "on" >> $LOG_FILE 2>&1
echo "Configuring the system..."
configure >> $LOG_FILE 2>&1
echo "Setting up keys..."
setup_keys "/root" >> $LOG_FILE 2>&1
echo "Setting up git repositories..."
set_rcs >> $LOG_FILE 2>&1
echo "Setting up home directory..."
setup_home >> $LOG_FILE 2>&1

clean_root_keys >> $LOG_FILE 2>&1

echo "Packages has been successfully installed."
exit
