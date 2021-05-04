#!/bin/bash

if [[ $# -eq 1 && $1 == "--detect" ]]
then
	xfconf-query --channel xfce4-desktop --list
	xfconf-query -c xfce4-desktop -m
	exit
fi

SCREEN="$1"
# Virtualbox:
#SCREEN="/backdrop/screen0/monitorVirtual1/workspace0/last-image"

xfconf-query --channel xfce4-desktop --property $SCREEN --set /usr/share/backgrounds/wallpaper.jpg
