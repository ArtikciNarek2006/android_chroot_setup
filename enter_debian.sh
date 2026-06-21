#!/system/bin/sh

RC="\033[0m"
RED="\033[1;31m"
GREEN="\033[1;32m"
BLUE="\033[1;34m"

CHROOT_PATH="/data/local/debian"
INIT_SCRIPT="/data/local/init_debian.sh"

if [ "$(id -u)" -ne 0 ]; then
    echo "${RED}[!] Error: Superuser access required. Execute 'su' first.${RC}"
    exit 1
fi

# Auto-initialize if proc or root mount points are dropped
if ! mount | grep -q "$CHROOT_PATH "; then
    echo "${RED}[*] Chroot mount point offline. Spawning engine init...${RC}"
    sh "$INIT_SCRIPT"
fi

echo "${GREEN}[+] Dropping into Debian environment context...${RC}"
echo "${BLUE}====================================================${RC}"

chroot "$CHROOT_PATH" /bin/bash -c "
    export HOME=/root
    export PATH=/root/miniconda3/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
    export LANG=C.UTF-8
    exec su - root
"
