#!/bin/bash

dbus-update-activation-environment --all

picom --config $HOME/.config/bspwm/picom.conf &

pgrep -x sxhkd > /dev/null || sxhkd &


