#!/bin/bash

VERSION="7.20"
USER="<user_name>"
PASSWORD="<super_password>"

sudo mount -t tmpfs tmpfs /tmp/

wget https://download.mikrotik.com/routeros/$VERSION/chr-$VERSION.img.zip
sudo apt-get install unzip
unzip chr-$VERSION.img.zip
DISK=$(fdisk -l | grep -i "disk /dev/" | awk -F ' ' '{print $2}')
DISK="${DISK: :-1}"
sudo mkdir -p /mnt/chr

SS=$(fdisk -lu chr-7.20.img | grep -i "sector size" | awk -F ' ' '{print $4}')
FS=$(fdisk -lu chr-7.20.img | grep -i "img2" | awk -F ' ' '{print $2}')
OFFSET=$(( $SS * $FS ))

sudo mount -o loop,offset=$OFFSET chr-7.20.img /mnt/chr

sudo cat <<EOF> /mnt/chr/rw/autorun.scr
/user add $USER password $PASSWORD
## add other command
EOF

sudo umount /mnt/chr
sudo echo u > /proc/sysrq-trigger

sudo dd if=chr-$VERSION.img of=$DISK bs=4M oflag=sync

sudo echo 1 > /proc/sys/kernel/sysrq
sudo echo b > /proc/sysrq-trigger

