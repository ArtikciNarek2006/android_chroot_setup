### ON phone

setenforce 0
dd if=/dev/zero of=/data/local/debian.img bs=1M count=30720
mkfs.ext4 -F -E nodiscard /data/local/debian.img
mkdir /data/local/debian
mount -t ext4 /data/local/debian.img /data/local/debian


#### on pc run

-> export TARGET_DIR="$HOME/rootfs"
-> sudo debootstrap --arch=arm64 --foreign stable "$TARGET_DIR" http://debian.org
-> cd $HOME/rootfs
-> sudo tar -cpvzf - . | ssh -i /home/revio/Desktop/test_ssh/key root@192.168.15.14 "tar -xvpzf - -C /data/local/debian"

#### setup seccond stage: on device
-> umount /data/local/debian
-> ./init_debian.sh
    ###### will give error. its ok
-> chroot "$CHROOT_PATH" /bin/bash -c "
    export HOME=/root
    export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
    export LANG=C.UTF-8
    exec bash
"

