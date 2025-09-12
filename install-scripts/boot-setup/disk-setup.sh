# --- Configuration ---
# You can adjust partition sizes here.
# Use M for Megabytes, G for Gigabytes.
EFI_PARTITION_SIZE="512M"
# Set SWAP_PARTITION_SIZE to "0" to disable swap partition creation.
# By default, it creates a swap partition equal to the amount of RAM.
SWAP_PARTITION_SIZE="$(grep MemTotal /proc/meminfo | awk '{print $2}')K" # Use K for Kilobytes from /proc/meminfo
ROOT_PARTITION_SIZE="0" # Use "0" to allocate all remaining space.

# Filesystem options
ROOT_FS_TYPE="ext4"
EFI_FS_TYPE="fat32"

# --- Script Settings ---
# Exit immediately if a command exits with a non-zero status.
set -e
# Treat unset variables as an error when substituting.
set -u

# --- Functions ---

# Displays a list of available block devices for the user to choose from.
# The selected drive path is exported as TARGET_DRIVE.
select_drive() {
    echo "========================================================="
    echo "                    Drive Selection"
    echo "========================================================="
    echo "Listing available drives..."
    echo ""
    
    # List block devices that are disks (and not partitions or loop devices).
    echo "Available drives:"
    echo "--------------------------------------------------------"
    lsblk -d -o NAME,SIZE,MODEL,TYPE | grep -E 'disk' | grep -vE 'boot|loop'
    echo "--------------------------------------------------------"
    
    # Show detailed information about drives
    echo ""
    echo "Detailed drive information:"
    for drive in $(lsblk -d -n -o NAME | grep -vE 'boot|loop'); do
        if [ -b "/dev/$drive" ]; then
            size=$(lsblk -d -n -o SIZE "/dev/$drive")
            model=$(lsblk -d -n -o MODEL "/dev/$drive" | xargs)
            echo "  /dev/$drive - Size: $size - Model: $model"
            
            # Show if drive has existing partitions
            if lsblk "/dev/$drive" | grep -q "part"; then
                echo "    ⚠️  This drive has existing partitions:"
                lsblk "/dev/$drive" -o NAME,SIZE,FSTYPE,MOUNTPOINT | grep "part" | sed 's/^/      /'
            fi
        fi
    done
    echo ""

    while true; do
        read -p "Please enter the name of the drive to install Arch Linux on (e.g., sda, nvme0n1): " drive_name
        
        # Prepend /dev/ to the name if it's not already there.
        if [[ ! "$drive_name" =~ /dev/.* ]]; then
            drive_name="/dev/${drive_name}"
        fi

        # Check if the selected drive exists.
        if [ ! -b "$drive_name" ]; then
            echo "❌ Error: Drive ${drive_name} does not exist."
            echo "Available drives: $(lsblk -d -n -o NAME | grep -vE 'boot|loop' | tr '\n' ' ')"
            continue
        fi
        
        # Check if drive is currently mounted
        if mount | grep -q "^${drive_name}"; then
            echo "⚠️  Warning: Drive ${drive_name} has mounted partitions:"
            mount | grep "^${drive_name}" | sed 's/^/  /'
            read -p "Do you want to unmount them and continue? (yes/no): " unmount_confirm
            if [ "$unmount_confirm" = "yes" ]; then
                echo "Unmounting partitions on ${drive_name}..."
                umount "${drive_name}"* 2>/dev/null || true
                swapoff "${drive_name}"* 2>/dev/null || true
            else
                continue
            fi
        fi

        break
    done

    # Show final drive information
    echo ""
    echo "Selected drive: ${drive_name}"
    drive_size=$(lsblk -d -n -o SIZE "$drive_name")
    drive_model=$(lsblk -d -n -o MODEL "$drive_name" | xargs)
    echo "Size: $drive_size"
    echo "Model: $drive_model"
    
    if lsblk "$drive_name" | grep -q "part"; then
        echo ""
        echo "Current partition table:"
        lsblk "$drive_name" -o NAME,SIZE,FSTYPE,MOUNTPOINT
    fi
    
    echo ""
    echo "⚠️  WARNING: ALL data on this drive will be PERMANENTLY DESTROYED!"
    echo "This includes:"
    echo "  - All files and folders"
    echo "  - All partitions and filesystems"
    echo "  - Any operating systems installed on this drive"
    echo ""
    
    while true; do
        read -p "Are you absolutely sure you want to continue? Type 'DELETE ALL DATA' to confirm: " confirmation
        if [ "$confirmation" = "DELETE ALL DATA" ]; then
            break
        elif [ "$confirmation" = "no" ] || [ "$confirmation" = "n" ]; then
            echo "Aborting installation."
            exit 0
        else
            echo "Please type exactly 'DELETE ALL DATA' to confirm, or 'no' to abort."
        fi
    done
    
    export TARGET_DRIVE="$drive_name"
    echo "✅ Drive ${drive_name} selected for installation."
    echo "--------------------------------------------------------"
}

# Wipes the partition table and any filesystem signatures from the drive.
wipe_disk() {
    echo "========================================================="
    echo "                    Wiping Disk"
    echo "========================================================="
    echo "Wiping existing partition table and signatures on ${TARGET_DRIVE}..."
    
    # Unmount any mounted partitions
    echo "Ensuring no partitions are mounted..."
    umount "${TARGET_DRIVE}"* 2>/dev/null || true
    swapoff "${TARGET_DRIVE}"* 2>/dev/null || true
    
    # Securely wipe filesystem signatures
    echo "Removing filesystem signatures..."
    if ! wipefs --all --force "${TARGET_DRIVE}"; then
        echo "❌ Failed to wipe filesystem signatures."
        exit 1
    fi
    
    # Zap (destroy) the GPT partition table
    echo "Destroying existing partition table..."
    if ! sgdisk --zap-all "${TARGET_DRIVE}"; then
        echo "❌ Failed to destroy partition table."
        exit 1
    fi
    
    # Inform kernel of partition table changes
    partprobe "${TARGET_DRIVE}" 2>/dev/null || true
    sleep 2
    
    echo "✅ Disk wiped successfully."
    echo "--------------------------------------------------------"
}

# Partitions the disk using a GPT layout for UEFI systems.
create_partitions() {
    echo "========================================================="
    echo "                 Creating Partitions"
    echo "========================================================="
    echo "Creating new partitions on ${TARGET_DRIVE}..."
    echo ""
    echo "Partition layout:"
    echo "  1. EFI System Partition: ${EFI_PARTITION_SIZE}"
    if [[ "${SWAP_PARTITION_SIZE}" != "0" ]]; then
        echo "  2. Swap Partition: ${SWAP_PARTITION_SIZE}"
        echo "  3. Root Partition: Remaining space"
    else
        echo "  2. Root Partition: Remaining space (no swap)"
    fi
    echo ""
    
    # Use sgdisk for partitioning.
    # Partition 1: EFI System Partition
    echo "Creating EFI System Partition..."
    if ! sgdisk -n 1:0:+${EFI_PARTITION_SIZE} -t 1:ef00 -c 1:"EFI System Partition" "${TARGET_DRIVE}"; then
        echo "❌ Failed to create EFI partition."
        exit 1
    fi

    # Partition 2: Swap Partition (if size > 0)
    if [[ "${SWAP_PARTITION_SIZE}" != "0" ]]; then
        echo "Creating Swap Partition..."
        if ! sgdisk -n 2:0:+${SWAP_PARTITION_SIZE} -t 2:8200 -c 2:"Swap Partition" "${TARGET_DRIVE}"; then
            echo "❌ Failed to create swap partition."
            exit 1
        fi
        partition_number=3
    else
        echo "Skipping swap partition creation."
        partition_number=2
    fi

    # Partition 3 (or 2): Root Partition (uses remaining space)
    echo "Creating Root Partition..."
    if ! sgdisk -n ${partition_number}:0:${ROOT_PARTITION_SIZE} -t ${partition_number}:8300 -c ${partition_number}:"Root Partition" "${TARGET_DRIVE}"; then
        echo "❌ Failed to create root partition."
        exit 1
    fi

    # Inform kernel of partition table changes
    partprobe "${TARGET_DRIVE}"
    sleep 2

    echo ""
    echo "✅ Partitions created successfully."
    echo ""
    echo "New partition layout:"
    sgdisk -p "${TARGET_DRIVE}"
    echo "--------------------------------------------------------"
}

# Formats the newly created partitions.
format_partitions() {
    echo "========================================================="
    echo "                Formatting Partitions"
    echo "========================================================="

    # Determine partition names. Handles both sdX and nvmeXnY conventions.
    if [[ $TARGET_DRIVE == *"nvme"* ]] || [[ $TARGET_DRIVE == *"mmcblk"* ]]; then
        local efi_part="${TARGET_DRIVE}p1"
        if [[ "${SWAP_PARTITION_SIZE}" != "0" ]]; then
            local swap_part="${TARGET_DRIVE}p2"
            local root_part="${TARGET_DRIVE}p3"
        else
            local root_part="${TARGET_DRIVE}p2"
        fi
    else
        local efi_part="${TARGET_DRIVE}1"
        if [[ "${SWAP_PARTITION_SIZE}" != "0" ]]; then
            local swap_part="${TARGET_DRIVE}2"
            local root_part="${TARGET_DRIVE}3"
        else
            local root_part="${TARGET_DRIVE}2"
        fi
    fi
    
    # Wait for partitions to be available
    echo "Waiting for partitions to be available..."
    sleep 3
    
    # Verify partitions exist
    for part in "$efi_part" "$root_part"; do
        if [ ! -b "$part" ]; then
            echo "❌ Partition $part not found. Waiting..."
            sleep 5
            if [ ! -b "$part" ]; then
                echo "❌ Partition $part still not available. Aborting."
                exit 1
            fi
        fi
    done
    
    # Format EFI partition as FAT32
    echo "Formatting EFI partition (${efi_part}) as FAT32..."
    if ! mkfs.fat -F32 -n "EFI" "$efi_part"; then
        echo "❌ Failed to format EFI partition."
        exit 1
    fi

    # Format and enable Swap partition
    if [[ "${SWAP_PARTITION_SIZE}" != "0" ]]; then
        if [ ! -b "$swap_part" ]; then
            echo "❌ Swap partition $swap_part not found."
            exit 1
        fi
        echo "Formatting Swap partition (${swap_part})..."
        if ! mkswap -L "SWAP" "$swap_part"; then
            echo "❌ Failed to format swap partition."
            exit 1
        fi
    fi

    # Format Root partition
    echo "Formatting Root partition (${root_part}) as ${ROOT_FS_TYPE}..."
    case "$ROOT_FS_TYPE" in
        "ext4")
            if ! mkfs.ext4 -F -L "ROOT" "$root_part"; then
                echo "❌ Failed to format root partition."
                exit 1
            fi
            ;;
        "btrfs")
            if ! mkfs.btrfs -f -L "ROOT" "$root_part"; then
                echo "❌ Failed to format root partition."
                exit 1
            fi
            ;;
        "xfs")
            if ! mkfs.xfs -f -L "ROOT" "$root_part"; then
                echo "❌ Failed to format root partition."
                exit 1
            fi
            ;;
        *)
            echo "❌ Unsupported filesystem type: $ROOT_FS_TYPE"
            exit 1
            ;;
    esac

    echo ""
    echo "✅ All partitions formatted successfully."
    echo "--------------------------------------------------------"
    
    # Export partition names for mounting
    export EFI_PARTITION="$efi_part"
    export SWAP_PARTITION="$swap_part"
    export ROOT_PARTITION="$root_part"
}

# Mounts the filesystems to /mnt and enables swap.
mount_filesystems() {
    echo "========================================================="
    echo "                 Mounting Filesystems"
    echo "========================================================="

    # Mount the root partition to /mnt
    echo "Mounting ${ROOT_PARTITION} to /mnt..."
    if ! mount "$ROOT_PARTITION" /mnt; then
        echo "❌ Failed to mount root partition."
        exit 1
    fi

    # Create the EFI directory and mount the EFI partition
    echo "Creating EFI mount point and mounting ${EFI_PARTITION}..."
    mkdir -p /mnt/boot/efi
    if ! mount "$EFI_PARTITION" /mnt/boot/efi; then
        echo "❌ Failed to mount EFI partition."
        exit 1
    fi

    # Turn on swap
    if [[ "${SWAP_PARTITION_SIZE}" != "0" ]]; then
        echo "Enabling swap on ${SWAP_PARTITION}..."
        if ! swapon "$SWAP_PARTITION"; then
            echo "❌ Failed to enable swap."
            exit 1
        fi
    fi

    echo ""
    echo "✅ All filesystems mounted successfully."
    echo ""
    echo "Current mount status:"
    lsblk -f
    echo ""
    echo "Mount points:"
    df -h | grep -E "(Filesystem|/mnt)"
    echo "--------------------------------------------------------"
}


# --- Main Execution ---
main() {
    echo "========================================================="
    echo "           Arch Linux Disk Setup Script"
    echo "========================================================="
    echo "This script will:"
    echo "  1. Help you select a target drive"
    echo "  2. Wipe the selected drive completely"
    echo "  3. Create a GPT partition table with:"
    echo "     - EFI System Partition (${EFI_PARTITION_SIZE})"
    if [[ "${SWAP_PARTITION_SIZE}" != "0" ]]; then
        echo "     - Swap Partition (${SWAP_PARTITION_SIZE})"
    fi
    echo "     - Root Partition (remaining space)"
    echo "  4. Format all partitions"
    echo "  5. Mount filesystems to /mnt"
    echo ""
    echo "⚠️  WARNING: This will DESTROY ALL DATA on the selected drive!"
    echo ""
    read -p "Do you want to continue? (y/n): " continue_setup
    if [[ ! "$continue_setup" =~ ^[Yy]$ ]]; then
        echo "Disk setup cancelled."
        exit 0
    fi
    
    select_drive
    wipe_disk
    create_partitions
    format_partitions
    mount_filesystems
    
    echo "========================================================="
    echo "✅ Disk setup completed successfully!"
    echo "========================================================="
    echo "Next steps:"
    echo "  1. Run the base system installation:"
    echo "     ./base-setup.sh"
    echo "  2. Generate fstab:"
    echo "     genfstab -U /mnt >> /mnt/etc/fstab"
    echo "  3. Chroot into the new system:"
    echo "     arch-chroot /mnt"
    echo ""
    echo "Target system is mounted at: /mnt"
    echo "EFI partition is mounted at: /mnt/boot/efi"
    if [[ "${SWAP_PARTITION_SIZE}" != "0" ]]; then
        echo "Swap is enabled on: ${SWAP_PARTITION}"
    fi
    echo "========================================================="
}

# Run the main function
main
