#!/bin/sh

set -e

echo 'IP=172.16.111.13::172.16.111.2:255.255.255.0::ens33:off' >> /target/etc/initramfs-tools/initramfs.conf

# Install custom script to unlock LUKS with socat
cp /remote-fde/socat-unlock-hook.sh /target/etc/initramfs-tools/hooks/
cp /remote-fde/socat-unlock-script-premount.sh /target/etc/initramfs-tools/scripts/init-premount/socat-unlock
cp /remote-fde/socat-unlock-script-bottom.sh /target/etc/initramfs-tools/scripts/init-bottom/socat-unlock

mkdir -p /target/etc/socat-initramfs/
cp /remote-fde/server.pem /remote-fde/client.crt /target/etc/socat-initramfs/

# GRUB's splash screen messes up with remote unlock
sed -i 's/^GRUB_CMDLINE_LINUX_DEFAULT="quiet splash"/GRUB_CMDLINE_LINUX_DEFAULT=""/' /target/etc/default/grub

in-target update-initramfs -u
in-target update-grub
