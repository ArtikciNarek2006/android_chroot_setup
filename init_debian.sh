#!/system/bin/sh

# ==============================================================================
# COLOR DEFINITIONS (mksh-compatible ANSI Escapes)
# ==============================================================================
RC="\033[0m"
RED="\033[1;31m"
GREEN="\033[1;32m"
YELLOW="\033[1;33m"
BLUE="\033[1;34m"
CYAN="\033[1;36m"

# ==============================================================================
# CONFIGURATION & CONSTANTS
# ==============================================================================
IMG_FILE="/data/local/debian.img"
CHROOT_PATH="/data/local/debian"

echo "${BLUE}====================================================${RC}"
echo "${CYAN}    DEBIAN CHROOT INITIALIZATION ENGINE             ${RC}"
echo "${BLUE}====================================================${RC}"

# ==============================================================================
# STEP 1: SECURITY CLEARANCE (SELINUX)
# ==============================================================================
CURRENT_SELINUX=$(getenforce)
if [ "$CURRENT_SELINUX" != "Permissive" ]; then
    echo "${YELLOW}[*] SELinux status is currently: $CURRENT_SELINUX${RC}"
    echo "${GREEN}[+] Shifting kernel security context to Permissive...${RC}"
    setenforce 0
else
    echo "${GREEN}[✓] SELinux is already Permissive.${RC}"
fi

# ==============================================================================
# STEP 2: ANDROID PARANOID NETWORK BYPASS
# ==============================================================================
# Attempting to strip network constraints globally at the kernel layer
sysctl -w net.ipv4.fmark_and_mask=0 >/dev/null 2>&1
if [ $? -eq 0 ]; then
    echo "${GREEN}[✓] Kernel network restrictions bypassed via sysctl.${RC}"
else
    echo "${YELLOW}[*] Kernel sysctl restricted. Falling back to explicit group nesting...${RC}"
fi

# ==============================================================================
# STEP 3: DYNAMIC LOOP DEVICE RESOLUTION & VERIFICATION
# ==============================================================================
# Dynamic string evaluation to match the backing file
REAL_LOOP=$(losetup -a | grep "$IMG_FILE" | head -n 1 | cut -d: -f1)

if [ -n "$REAL_LOOP" ]; then
    echo "${GREEN}[✓] Verified: '$IMG_FILE' is tied to block device: $REAL_LOOP${RC}"
else
    echo "${YELLOW}[*] '$IMG_FILE' is not currently tied to a loop device.${RC}"
    echo "${GREEN}[+] Querying kernel for the next available loop channel...${RC}"
    
    REAL_LOOP=$(losetup -f)
    if [ -z "$REAL_LOOP" ]; then
        echo "${RED}[!] CRITICAL ERROR: No available loop devices left in Android kernel layer!${RC}"
        exit 1
    fi
    
    echo "${GREEN}[+] Linking '$IMG_FILE' to hardware block: $REAL_LOOP${RC}"
    losetup "$REAL_LOOP" "$IMG_FILE"
    
    # Verify binding validity via plain grep matching
    if ! losetup -a | grep -q "$IMG_FILE"; then
        echo "${RED}[!] CRITICAL ERROR: Hardware binding failed for $REAL_LOOP!${RC}"
        exit 1
    fi
fi

# ==============================================================================
# STEP 4: MOUNT VERIFICATION (IS DRIVE ACTIVE?)
# ==============================================================================
if mount | grep -q "$CHROOT_PATH "; then
    echo "${GREEN}[✓] Core filesystem space is already mounted at '$CHROOT_PATH'.${RC}"
else
    echo "${GREEN}[+] Mount point is idle. Attaching $REAL_LOOP to '$CHROOT_PATH'...${RC}"
    mkdir -p "$CHROOT_PATH"
    mount -t ext4 "$REAL_LOOP" "$CHROOT_PATH"
    
    if [ $? -ne 0 ]; then
        echo "${RED}[!] CRITICAL ERROR: Failed to mount filesystem block layer!${RC}"
        exit 1
    fi
fi

# ==============================================================================
# STEP 5: VIRTUAL LINUX FILESYSTEM SUBSYSTEM BINDINGS
# ==============================================================================
# Simple string parsing token scan safe for mksh parsing environments
for sys_mount in dev dev/pts dev/shm proc sys tmp mnt/sdcard; do
    TARGET_MNT="$CHROOT_PATH/$sys_mount"
    
    if [ ! -d "$TARGET_MNT" ]; then
        mkdir -p "$TARGET_MNT"
    fi
    
    if ! mount | grep -q "$TARGET_MNT "; then
        echo "${GREEN}[+] Syncing system pipeline subsystem: /$sys_mount${RC}"
        if [ "$sys_mount" = "dev" ]; then
            mount -o bind /dev "$TARGET_MNT"
        elif [ "$sys_mount" = "dev/pts" ]; then
            mount -t devpts devpts "$TARGET_MNT"
	elif [ "$sys_mount" = "dev/shm" ]; then
            # Clean 3GB Shared Memory boundary deployment
            mount -t tmpfs -o size=3G tmpfs "$TARGET_MNT"
        elif [ "$sys_mount" = "proc" ]; then
            mount -t proc proc "$TARGET_MNT"
        elif [ "$sys_mount" = "sys" ]; then
            mount -t sysfs sysfs "$TARGET_MNT"
        elif [ "$sys_mount" = "tmp" ]; then
            mount -t tmpfs tmpfs "$TARGET_MNT"
        elif [ "$sys_mount" = "mnt/sdcard" ]; then
            mount -o bind /sdcard "$TARGET_MNT"
        fi
    fi
done

# ==============================================================================
# STEP 6: NETWORK & DNS SYNCHRONIZATION
# ==============================================================================
cp /etc/hosts "$CHROOT_PATH/etc/hosts" 2>/dev/null
echo "nameserver 1.1.1.1" > "$CHROOT_PATH/etc/resolv.conf"
echo "nameserver 8.8.8.8" >> "$CHROOT_PATH/etc/resolv.conf"

# ==============================================================================
# STEP 7: CHROOT ENTRY ENVIRONMENT CONTROL [this step is deprecated and commented, use enter_debian.sh]
# ==============================================================================
echo "${GREEN}[✓] Environment checks clean. Stepping into Debian container...${RC}"
echo "${BLUE}====================================================${RC}"

# Didnt helped
#if [ -f "$CHROOT_PATH/etc/group" ]; then
#    grep -q "aid_inet" "$CHROOT_PATH/etc/group" || echo "aid_inet:x:3003:root" >> "$CHROOT_PATH/etc/group"
#    grep -q "aid_net_raw" "$CHROOT_PATH/etc/group" || echo "aid_net_raw:x:3004:root" >> "$CHROOT_PATH/etc/group"
#fi

#chroot "$CHROOT_PATH" /bin/bash -c "
#    export HOME=/root
#    export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
#    export LANG=C.UTF-8
#    exec su - root
#"
