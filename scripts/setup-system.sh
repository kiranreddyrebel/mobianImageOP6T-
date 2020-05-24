#!/bin/sh

# Setup hostname
echo $1 > /etc/hostname

# Generate locales (only en_US.UTF-8 for now)
sed -i -e '/en_US\.UTF-8/s/^# //g' /etc/locale.gen
locale-gen

# Change plymouth default theme
plymouth-set-default-theme mobian

# Load phosh on startup, if it exists.    
if service --status-all | grep -Fq 'phosh'; then    
  systemctl enable phosh.service
fi