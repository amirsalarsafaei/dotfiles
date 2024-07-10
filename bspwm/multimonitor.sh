#!/usr/bin/bash
hdmi_monitor=$(xrandr -q | grep -i 'hdmi')
usbc_monitor=$(xrandr -q | grep --perl-regex -i 'DP-(0|1)')

if [[ $hdmi_monitor = *connected* && $usbc_monitor = *connected* ]]; then 
	bspc monitor HDMI-0 -d i ii iii vi v
	bspc monitor DP-0 -d vi vii viii xi x
else 
	bspc monitor -d I II III IV V VI VII VIII IX X
fi
