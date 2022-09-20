#!/bin/sh

# Setup hostname
echo $1 > /etc/hostname

# Change plymouth default theme
plymouth-set-default-theme mobian
