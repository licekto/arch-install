#!/bin/bash

set -xe
source install.cfg

LOG_FILE="configure.log"

set_wallpaper()
{
    sudo cp configs/wallpaper.png $WALLPAPER
    # Run 'utils/background-setter.sh --detect', change the background
    # and see which screen has been detected. Then, set this variable
    # with the returned value.
    SCREEN="/backdrop/screen0/monitoreDP1/workspace0/last-image"
    xfconf-query --channel xfce4-desktop --property $SCREEN --set $WALLPAPER
}

configure()
{
    # https://askubuntu.com/questions/380550/xubuntu-how-to-set-the-wallpaper-using-the-command-line
    xfconf-query -c xsettings -p /Net/ThemeName -s Adwaita-dark
    xfconf-query -c xfwm4 -p /general/workspace_count --set 1
    #xfconf-query -c xfce4-session -p /general/LockCommand -s "light-locker-command --lock" --create -t string
    # Disable hibernation because of encrypted swap
    xfconf-query -c xfce4-session -np /shutdown/ShowHibernate -t bool -s false
}

disable_recent()
{
    mkdir -p ~/.config/gtk-3.0/settings.ini
    cp configs/gtk3-settings.ini ~/.config/gtk-3.0/settings.ini
    #sed -i 's/StartupMode=.*$/StartupMode=cwd/' ~/.config/gtk-2.0/gtkfilechooser.ini
    REC_USED_FILE=~/.local/share/recently-used.xbel
    rm -f $REC_USED_FILE
    touch $REC_USED_FILE
    sudo chattr +i $REC_USED_FILE

    REC_USED_DIR=~/.local/share/RecentDocuments
    rm -rf $REC_USED_DIR
    mkdir $REC_USED_DIR
    sudo chattr +i $REC_USED_DIR
}

echo "Configuring the installed system..."
configure >> $LOG_FILE 2>&1

disable_recent >> $LOG_FILE 2>&1
