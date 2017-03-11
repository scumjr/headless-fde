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
	mkdir -p conf/keys/
	for f in conf/keys/id_rsa conf/keys/ssh_host_rsa_key; do
		if [ ! -f "$f" ]; then
			ssh-keygen -t rsa -N '' -f "$f"
		fi
	done
}

function generate_certs
{
	mkdir -p conf/keys/
	for filename in client server; do
		[ -f conf/keys/$filename.key ] && continue
		openssl genrsa -out conf/keys/$filename.key 4096
		openssl req -new -key conf/keys/$filename.key -x509 -days 7300 -out conf/keys/$filename.crt
		cat conf/keys/$filename.key conf/keys/$filename.crt >conf/keys/$filename.pem
		chmod 600 conf/keys/$filename.key conf/keys/$filename.pem
	done
}

function create_tree
{
	mkdir -p "$WORKDIR/root/.ssh/" "$WORKDIR/root/etc/ssh/"
	cp conf/keys/id_rsa.pub "$WORKDIR/root/.ssh/authorized_keys"
	cp conf/keys/ssh_host_rsa_key "$WORKDIR/root/etc/ssh/ssh_host_rsa_key"

	mkdir -p "$WORKDIR/root/remote-fde/"
	cp conf/remote-fde.sh \
	   conf/keys/server.pem \
	   conf/keys/client.crt \
	   conf/socat-unlock-hook.sh \
	   conf/socat-unlock-script-bottom.sh \
	   conf/socat-unlock-script-premount.sh \
	   "$WORKDIR/root/remote-fde/"

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
	generate_certs
	create_tree
	rebuild_initrd "$WORKDIR/initrd.gz" "$WORKDIR/initrd-remote-fde"
}

main
