VERSION=
mount -t tmpfs tmpfs /tmp/

wget https://download.mikrotik.com/routeros/$VERSION/chr-$VERSION.img.zip
sudo apt-get install unzip
unzip chr-$VERSION.img.zip
DISK=$(fdisk -l | grep -i "disk /dev/" | awk -F ' ' '{print $2}')
DISK="${DISK: :-1}

dd if=chr-$VERSION.img of=$DISK bs=4M oflag=sync

echo 1 > /proc/sys/kernel/sysrq
echo b > /proc/sysrq-trigger
