#!/bin/bash

dbus-update-activation-environment --all

picom --config $HOME/.config/bspwm/picom.conf &

pgrep -x sxhkd > /dev/null || sxhkd &

feh --no-fehbg --bg-fill ~/Pictures/wallpaper.jpg &

# Polkit

/usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1 &>/dev/null

# Keyring 

eval $(gnome-keyring-daemon -s --components=pkcs11,secrets,ssh,gpg) &>/dev/null

xsetroot -cursor_name left_ptr &

eww open greeting  &>/dev/null
