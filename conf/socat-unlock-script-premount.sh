#!/bin/sh

# This script is executed during kernel boot in the early user-space before the
# root partition has been mounted. It waits for the network to be configured and
# launches socat.

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

. /conf/initramfs.conf
. /scripts/functions

configure_networking

log_begin_msg "Starting socat"

socat OPENSSL-LISTEN:443,fork,reuseaddr,cert=/etc/socat-unlock/server.pem,cafile=/etc/socat-unlock/client.crt OPEN:/lib/cryptsetup/passfifo &
echo "$!" >/run/socat-unlock.pid

exit 0
