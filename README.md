place all those files in /data/local/

### ON phone

```bash
setenforce 0
dd if=/dev/zero of=/data/local/debian.img bs=1M count=30720
mkfs.ext4 -F -E nodiscard /data/local/debian.img
mkdir /data/local/debian
mount -t ext4 /data/local/debian.img /data/local/debian
```

#### on pc run

```bash
export TARGET_DIR="$HOME/rootfs"
sudo debootstrap --arch=arm64 --foreign stable "$TARGET_DIR" http://debian.org
cd $HOME/rootfs
sudo tar -cpvzf - . | ssh -i /home/revio/Desktop/test_ssh/key root@192.168.15.14 "tar -xvpzf - -C /data/local/debian"
```

#### setup seccond stage: on device

```bash
umount /data/local/debian
./enter_debian.sh
    ###### will give error. its ok
chroot "$CHROOT_PATH" /bin/bash -c "
    export HOME=/root
    export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
    export LANG=C.UTF-8
    exec bash
"
/debootstrap/debootstrap --second-stage
exit
./stop_debian.sh
./enter_debian.sh
```

#### Final setup.

disable APT sandbox if needed
```bash
echo "APT::Sandbox::User "root";" > /etc/apt/apt.conf.d/00-no-sandbox
apt update && apt upgrade -y
```

#### Install usefull

```bash
apt update && apt install wget curl tree command-not-found vim fastfetch unzip zip sudo hollywood  cmatrix ca-certificates git-all python3 openssl ffmpeg
```

