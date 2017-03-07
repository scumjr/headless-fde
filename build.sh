#!/bin/bash

set -e

URL_INITRD=http://archive.ubuntu.com/ubuntu/dists/yakkety-updates/main/installer-amd64/current/images/netboot/ubuntu-installer/amd64/initrd.gz
URL_LINUX=http://archive.ubuntu.com/ubuntu/dists/yakkety-updates/main/installer-amd64/current/images/netboot/ubuntu-installer/amd64/linux
WORKDIR=$(pwd)/build/

function dl_initrd
{
	if [ ! -f "$WORKDIR/initrd.gz" ]; then
		wget "$URL_INITRD" -O "$WORKDIR/initrd.gz"
	fi
	if [ ! -f "$WORKDIR/linux" ]; then
		wget "$URL_LINUX" -O "$WORKDIR/linux"
	fi
	sha256sum --check conf/SHA256SUMS
}

function generate_ssh_keys
{
	for f in conf/id_rsa conf/ssh_host_rsa_key; do
		if [ ! -f "$f" ]; then
			ssh-keygen -t rsa -N '' -f "$f"
		fi
	done
}

function create_tree
{
	mkdir -p "$WORKDIR/root/.ssh/" "$WORKDIR/root/etc/ssh/"
	cp conf/id_rsa.pub "$WORKDIR/root/.ssh/authorized_keys"
	cp conf/ssh_host_rsa_key "$WORKDIR/root/etc/ssh/ssh_host_rsa_key"

	mkdir -p "$WORKDIR/root/remote-fde/"
	cp conf/crypt_unlock.sh conf/remote-fde.sh "$WORKDIR/root/remote-fde/"

	cp conf/preseed.cfg "$WORKDIR/root/"
}

# Destination files must be given without .gz suffix. fakeroot is required to
# append files as root to the archive.
function rebuild_initrd
{
	local src="$1"
	local dst="$2"

	zcat "$src" > "$dst"

	cd "$WORKDIR/root/" >/dev/null
	find . | fakeroot -- cpio --quiet --create --append --format=newc -F "$dst"
	cd - >/dev/null

	gzip --force "$dst"
}

function main
{
	mkdir -p "$WORKDIR"

	dl_initrd
	generate_ssh_keys
	create_tree
	rebuild_initrd "$WORKDIR/initrd.gz" "$WORKDIR/initrd-remote-fde"
}

main
