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
echo "${RED}    DEBIAN CHROOT TERMINATION ENGINE               ${RC}"
echo "${BLUE}====================================================${RC}"

# ==============================================================================
# STEP 1: KILL ACTIVE ENVIRONMENT PROCESSES
# ==============================================================================
echo "${YELLOW}[*] Sweeping chroot workspace for active processes...${RC}"
# Using standard busybox/toybox fuser to clear any processes utilizing the path
fuser -k -9 "$CHROOT_PATH" >/dev/null 2>&1
sleep 1

# ==============================================================================
# STEP 2: TEARDOWN VIRTUAL SUBSYSTEMS (Reverse Order Allocation)
# ==============================================================================
# Sweeping from deepest/most volatile structures back to the core nodes
for sys_mount in mnt/sdcard tmp sys/kernel/debug sys proc dev/shm dev/pts dev; do
    TARGET_MNT="$CHROOT_PATH/$sys_mount"
    
    if mount | grep -q "$TARGET_MNT "; then
        echo "${YELLOW}[-] Detaching subsystem mount: /$sys_mount${RC}"
        umount -f "$TARGET_MNT" 2>/dev/null
        
        # Lazy unmount fallback if standard unmount is busy
        if mount | grep -q "$TARGET_MNT "; then
            umount -l "$TARGET_MNT" 2>/dev/null
        fi
    fi
done

# ==============================================================================
# STEP 3: UNMOUNT CORE EXT4 CONTAINER
# ==============================================================================
if mount | grep -q "$CHROOT_PATH "; then
    echo "${YELLOW}[-] Detaching core filesystem partition from '$CHROOT_PATH'...${RC}"
    umount "$CHROOT_PATH" 2>/dev/null
    
    if mount | grep -q "$CHROOT_PATH "; then
        echo "${RED}[!] Standard unmount busy. Forcing lazy unmount on core volume...${RC}"
        umount -l "$CHROOT_PATH" 2>/dev/null
    fi
else
    echo "${GREEN}[✓] Core filesystem path is already unmounted.${RC}"
fi

# ==============================================================================
# STEP 4: DETACH PHYSICAL KERNEL LOOP BLOCKS
# ==============================================================================
# Dynamically locate which specific loop block holds our image file
REAL_LOOP=$(losetup -a | grep "$IMG_FILE" | head -n 1 | cut -d: -f1)

if [ -n "$REAL_LOOP" ]; then
    echo "${YELLOW}[-] Releasing hardware block assignment: $REAL_LOOP${RC}"
    losetup -d "$REAL_LOOP" 2>/dev/null
    
    # Final health check to make absolutely sure it released
    if losetup -a | grep -q "$IMG_FILE"; then
        echo "${RED}[!] WARNING: Loop device remained locked. Executing global flush...${RC}"
        losetup -D
    fi
else
    echo "${GREEN}[✓] No loop blocks are bound to '$IMG_FILE'.${RC}"
fi

echo "${GREEN}[✓] Teardown complete. Debian environment safely halted.${RC}"
echo "${BLUE}====================================================${RC}"
