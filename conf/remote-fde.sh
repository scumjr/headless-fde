#!/bin/sh

set -e

# Use the same SSH key for installation and dropbear-initramfs
cp /.ssh/authorized_keys /target/etc/dropbear-initramfs/authorized_keys

echo 'IP=172.16.111.13::172.16.111.2:255.255.255.0::ens33:off' >> /target/etc/initramfs-tools/initramfs.conf

# Install a custom script to unlock LUKS
cp /remote-fde/crypt_unlock.sh /target/etc/initramfs-tools/hooks/

# GRUB's splash screen messes up with remote unlock
sed -i 's/^GRUB_CMDLINE_LINUX_DEFAULT="quiet splash"/GRUB_CMDLINE_LINUX_DEFAULT=""/' /target/etc/default/grub

in-target update-initramfs -u
in-target update-grub
