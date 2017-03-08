A [lot of techniques](https://www.google.com/search?q=headless+full+disk+encryption)
exist to install headless servers with full disk encryption: PXE + VNC,
debootstrap, QEMU, local installation in a VM + dd, etc. I tend to find them
hackish and ended up to use another option. I'm pretty sure that it's already
explained elsewhere but didn't find it on the Internet, so here it is.

Basically, the `initrd.gz` of a Debian-like netboot installation is customized
to provide a remote shell through SSH at the beginning of the installation
thanks to the
[preseeding method](https://www.debian.org/releases/stable/mips/apb.html). It
allows to install the distro as usual, but remotely. A custom script is run just
before the installation finishes to setup the packages which will allow to
unlock the disk remotely at each reboot. This was successfully tested with
Ubuntu 16.10.

3 different SSH servers are involved:

- *#1*. Temporary OpenSSH server, specific to the installation
- *#2*. Dropbear server, used in conjunction with initramfs to unlock the disk
- *#3*. OpenSSH server

Servers *#1* and *#2* share the same `authorized_keys` (embedded in the custom
`initrd.gz`), while the authentication on server *#3* is made with the
login/password provided during the installation.



# Custom initrd.gz generation

Please change configuration values as needed (especially the network parameters)
in `conf/preseed.cfg` and `conf/remote-fde.sh` before running `build.sh`:

    $ ./build.sh
    $ ls -lh build/initrd-remote-fde.gz build/linux
    -rw-rw-r-- 1 user user   37M  Mar  7 22:17 build/initrd-remote-fde.gz
    -rw-rw-r-- 1 user user  7,2M  Mar  7 19:58 build/linux



# GRUB configuration to boot to the custom initrd.gz

Copy the custom files to `/boot/netboot/`:

    sudo mkdir -p /boot/netboot/
    sudo cp build/linux /boot/netboot/
    sudo cp build/initrd-remote-fde.gz /boot/netboot/initrd.gz

Write the following lines to `/etc/grub.d/40_custom`:

    #!/bin/sh
    exec tail -n +3 $0
    # This file provides an easy way to add custom menu entries.  Simply type the
    # menu entries you want to add after this comment.  Be careful not to change
    # the 'exec tail' line above.

    menuentry "remote-fde" {
            linux (hd0,1)/boot/netboot/linux
            initrd (hd0,1)/boot/netboot/initrd.gz
    }

Change the `GRUB_DEFAULT` parameter in `/etc/default/grub` to force the boot to
this new entry:

    GRUB_DEFAULT="remote-fde"

Apply the changes and reboot to the custom `initrd.gz`:

    sudo update-grub
    sudo reboot



# Server installation through SSH

The server will boot on the custom `initrd.gz` and begin the installation.
Since a few packages will be fetched and installed from the Internet, it can
take a while until the SSH server *#1* is launched. Please note that the user is
`installer`.

    $ ssh -o UserKnownHostsFile=/dev/null -i ./conf/id_rsa installer@172.16.111.13
    The authenticity of host '172.16.111.13 (172.16.111.13)' can't be established.
    RSA key fingerprint is SHA256:2a2c/hF2rcJ95OMqUKIazgY1UnxGyeVRkNVaiZk30RY.
    Are you sure you want to continue connecting (yes/no)? 

We don't want to remember the public key of this server since it's specific to
the installation, hence the `UserKnownHostsFile` option. You should check that
the fingerprint is the same than the one displayed by this command:

    $ ssh-keygen -lf conf/ssh_host_rsa_key
    2048 SHA256:2a2c/hF2rcJ95OMqUKIazgY1UnxGyeVRkNVaiZk30RY user@laptop (RSA)

Once logged in, the installation can be resumed as usual:

![Install through SSH](https://raw.githubusercontent.com/scumjr/headless-fde/master/img/ssh-install.png)

and the disk can be encrypted during partitioning.

Once the installation is complete, you can hit continue to reboot to the freshly
installed system. If you're paranoid, you might read the optional final section.



# Connection to the freshly installed system

## Remote unlock

Connection to the Dropbear SSH server (*#2*) using the same SSH private key than
the one used during the installation and the `unlock` command unlocks the disk.

    $ ssh -o UserKnownHostsFile=/dev/null -o FingerprintHash=md5 -i ./conf/id_rsa root@172.16.111.13
    The authenticity of host '172.16.111.13 (172.16.111.13)' can't be established.
    ECDSA key fingerprint is MD5:6b:6a:80:67:fd:dd:13:c5:4f:af:1e:31:bb:a1:98:9b.
    Are you sure you want to continue connecting (yes/no)? yes
    Warning: Permanently added '172.16.111.13' (ECDSA) to the list of known hosts.
    To unlock root partition, and maybe others like swap, run `cryptroot-unlock`
    To unlock root-partition run unlock


    BusyBox v1.22.1 (Ubuntu 1:1.22.0-19ubuntu2) built-in shell (ash)
    Enter 'help' for a list of built-in commands.

    # unlock
    Please unlock disk sda5_crypt: 
      WARNING: Failed to connect to lvmetad. Falling back to device scanning.
      Reading all physical volumes.  This may take a while...
      Found volume group "ubuntu-vg" using metadata type lvm2
      WARNING: Failed to connect to lvmetad. Falling back to device scanning.
      2 logical volume(s) in volume group "ubuntu-vg" now active
    cryptsetup: sda5_crypt set up successfully
    Connection to 172.16.111.13 closed.

You'll be disconnected and the system will boot.


## Connection to the unlocked system

One can finally connect to the target system (*#3*) using the login/password specified
during the install. Yeah!

    $ ssh user@172.16.111.13
    The authenticity of host '172.16.111.13 (172.16.111.13)' can't be established.
    ECDSA key fingerprint is SHA256:zmFmL7MPexfOBiQlIaubEHbzV4PQOeZTJ6aq8BUi7M8.
    Are you sure you want to continue connecting (yes/no)? yes
    Warning: Permanently added '172.16.111.13' (ECDSA) to the list of known hosts.
    user@172.16.111.13's password: 
    Welcome to Ubuntu 16.10 (GNU/Linux 4.8.0-39-generic x86_64)

     * Documentation:  https://help.ubuntu.com
     * Management:     https://landscape.canonical.com
     * Support:        https://ubuntu.com/advantage

    The programs included with the Ubuntu system are free software;
    the exact distribution terms for each program are described in the
    individual files in /usr/share/doc/*/copyright.

    Ubuntu comes with ABSOLUTELY NO WARRANTY, to the extent permitted by
    applicable law.

    To run a command as administrator (user "root"), use "sudo <command>".
    See "man sudo_root" for details.

    user@ubuntu:~$ 



# Optional tips for the paranoids

During the installation, one can connect to the server within another SSH
session to get a shell (just select the "Start shell" option) and display the
fingerprints of the SSH host keys generated during the installation of the
Dropbear and openssh-server packages:

    $ ssh -o UserKnownHostsFile=/dev/null -i ./conf/id_rsa installer@172.16.111.13
    ...
    "Start shell"
    ...
    BusyBox v1.22.1 (Ubuntu 1:1.22.0-19ubuntu2) built-in shell (ash)
    Enter 'help' for a list of built-in commands.

    ~ # chroot /target/ /bin/bash


## Dropbear (*#2*) host key fingerprint

    root@ubuntu:/# dropbearkey -y -f /etc/dropbear-initramfs/dropbear_ecdsa_host_key 
    Public key portion is:
    ecdsa-sha2-nistp521 AAAAE2VjZHNhLXNoYTItbmlzdHA1MjEAAAAIbmlzdHA1MjEAAACFBAH45+Y0Arf7NesVs+mH6l56kRPTSpBRaABbORHForyRz2aptNkfZ6T2qvF5B8ggzVSQL0T1zN3NFavfcBSh319/GQAzNOGpcj1RjP39dUtMehXbXr0fiEHkiguczU+5WEWuTId0Ryj4gZ+oKOekcJOu1NtEpYM8aUlDepFccUUr+Zv5SA== root@ubuntu
    Fingerprint: md5 6b:6a:80:67:fd:dd:13:c5:4f:af:1e:31:bb:a1:98:9b

Unfortunately, the hash algorithm used to display the fingerprint of the host
key is MD5 (or SHA1 depending on
[compile options](https://github.com/mkj/dropbear/blob/master/signkey.c#L469)).
Never mind.


## OpenSSH (*#3*) host key fingerprint

    root@ubuntu:/# ssh-keygen -lf /etc/ssh/ssh_host_ecdsa_key.pub
    256 SHA256:zmFmL7MPexfOBiQlIaubEHbzV4PQOeZTJ6aq8BUi7M8 root@ubuntu (ECDSA)



# References

- [Automating the installation using preseeding](https://www.debian.org/releases/stable/mips/apb.html)
- [Remote unlocking LUKS encrypted LVM using Dropbear SSH in Ubuntu Server 14.04.1 (with Static IP)](https://stinkyparkia.wordpress.com/2014/10/14/remote-unlocking-luks-encrypted-lvm-using-dropbear-ssh-in-ubuntu-server-14-04-1-with-static-ipst/)
