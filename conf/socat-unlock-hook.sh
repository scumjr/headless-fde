#!/bin/sh

set -e

# This hook is executed during generation of the initramfs-image and isn't
# included in the image itself. It copies the socat binary and the SSL
# certificates to the image.

PREREQ=""

prereqs() {
  echo "$PREREQ"
}

case "$1" in
  prereqs)
    prereqs
    exit 0
  ;;
esac

. "${CONFDIR}/initramfs.conf"
. /usr/share/initramfs-tools/hook-functions

copy_exec /usr/bin/socat /usr/bin/socat

LIBC_DIR=$(ldd /usr/bin/socat | sed -nr 's#.* => (/lib.*)/libc\.so\.[0-9.-]+ \(0x[[:xdigit:]]+\)$#\1#p')
find -L "$LIBC_DIR" -maxdepth 1 -name 'libnss_files.*' -type f | while read so; do
    copy_exec "$so"
done

mkdir -p "${DESTDIR}/etc/socat-unlock/"
cp /etc/socat-initramfs/server.pem /etc/socat-initramfs/client.crt "${DESTDIR}/etc/socat-unlock/"
