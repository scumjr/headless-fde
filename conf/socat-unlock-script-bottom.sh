#!/bin/sh

# This script is executed during kernel boot in the early user-space before the
# root partition has been mounted. It kills socat after the unlocking of the
# disk.

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

if [ -f /run/socat-unlock.pid ]; then
        kill "$(cat /run/socat-unlock.pid)"
        rm /run/socat-unlock.pid
fi

exit 0
