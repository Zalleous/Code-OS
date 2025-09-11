# --- Configuration ---
# You can adjust partition sizes here.
# Use M for Megabytes, G for Gigabytes.
EFI_PARTITION_SIZE="512M"
# Set SWAP_PARTITION_SIZE to "0" to disable swap partition creation.
# By default, it creates a swap partition equal to the amount of RAM.
SWAP_PARTITION_SIZE="$(grep MemTotal /proc/meminfo | awk '{print $2}')K" # Use K for Kilobytes from /proc/meminfo
ROOT_PARTITION_SIZE="0" # Use "0" to allocate all remaining space.

# --- Script Settings ---
# Exit immediately if a command exits with a non-zero status.
set -e
# Treat unset variables as an error when substituting.
set -u

# --- Functions ---

# Displays a list of available block devices for the user to choose from.
# The selected drive path is exported as TARGET_DRIVE.
select_drive() {
    echo "Listing available drives..."
    # List block devices that are disks (and not partitions or loop devices).
    lsblk -d -o NAME,SIZE,MODEL | grep -vE 'boot|loop'

    echo ""
    read -p "Please enter the name of the drive to install Arch Linux on (e.g., sda, nvme0n1): " drive_name
    
    # Prepend /dev/ to the name if it's not already there.
    if [[ ! "$drive_name" =~ /dev/.* ]]; then
        drive_name="/dev/${drive_name}"
    fi

    # Check if the selected drive exists.
    if [ ! -b "$drive_name" ]; then
        echo "Error: Drive ${drive_name} does not exist. Please run the script again." >&2
        exit 1
    fi

    echo "You have selected ${drive_name}."
    read -p "WARNING: ALL data on this drive will be destroyed. Are you absolutely sure? (yes/no): " confirmation
    if [ "$confirmation" != "yes" ]; then
        echo "Aborting installation."
        exit 0
    fi
    export TARGET_DRIVE="$drive_name"
    echo "--------------------------------------------------------"
}

# Wipes the partition table and any filesystem signatures from the drive.
wipe_disk() {
    echo "Wiping existing partition table and signatures on ${TARGET_DRIVE}..."
    # Securely wipe filesystem signatures
    wipefs --all --force "${TARGET_DRIVE}"
    # Zap (destroy) the GPT partition table
    sgdisk --zap-all "${TARGET_DRIVE}"
    echo "Disk wiped successfully."
    echo "--------------------------------------------------------"
}

# Partitions the disk using a GPT layout for UEFI systems.
create_partitions() {
    echo "Creating new partitions on ${TARGET_DRIVE}..."
    
    # Use sgdisk for partitioning.
    # Partition 1: EFI System Partition
    sgdisk -n 1:0:+${EFI_PARTITION_SIZE} -t 1:ef00 -c 1:"EFI System Partition" "${TARGET_DRIVE}"

    # Partition 2: Swap Partition (if size > 0)
    if [[ "${SWAP_PARTITION_SIZE}" != "0" ]]; then
        sgdisk -n 2:0:+${SWAP_PARTITION_SIZE} -t 2:8200 -c 2:"Swap Partition" "${TARGET_DRIVE}"
    fi

    # Partition 3: Root Partition (uses remaining space)
    sgdisk -n 3:0:${ROOT_PARTITION_SIZE} -t 3:8300 -c 3:"Root Partition" "${TARGET_DRIVE}"

    echo "Partitions created successfully."
    # List the new partition layout
    sgdisk -p "${TARGET_DRIVE}"
    echo "--------------------------------------------------------"
}

# Formats the newly created partitions.
format_partitions() {
    echo "Formatting partitions..."

    # Determine partition names. Handles both sdX and nvmeXnY conventions.
    if [[ $TARGET_DRIVE == *"nvme"* ]]; then
        local efi_part="${TARGET_DRIVE}p1"
        local swap_part="${TARGET_DRIVE}p2"
        local root_part="${TARGET_DRIVE}p3"
    else
        local efi_part="${TARGET_DRIVE}1"
        local swap_part="${TARGET_DRIVE}2"
        local root_part="${TARGET_DRIVE}3"
    fi
    
    # Format EFI partition as FAT32
    echo "Formatting EFI partition (${efi_part})..."
    mkfs.fat -F32 "$efi_part"

    # Format and enable Swap partition
    if [[ "${SWAP_PARTITION_SIZE}" != "0" ]]; then
        echo "Formatting Swap partition (${swap_part})..."
        mkswap "$swap_part"
    fi

    # Format Root partition as ext4
    echo "Formatting Root partition (${root_part})..."
    mkfs.ext4 -F "$root_part"

    echo "Partitions formatted successfully."
    echo "--------------------------------------------------------"
    
    # Export partition names for mounting
    export EFI_PARTITION="$efi_part"
    export SWAP_PARTITION="$swap_part"
    export ROOT_PARTITION="$root_part"
}

# Mounts the filesystems to /mnt and enables swap.
mount_filesystems() {
    echo "Mounting filesystems..."

    # Mount the root partition to /mnt
    echo "Mounting ${ROOT_PARTITION} to /mnt..."
    mount "$ROOT_PARTITION" /mnt

    # Create the EFI directory and mount the EFI partition
    echo "Mounting ${EFI_PARTITION} to /mnt/boot/efi..."
    mkdir -p /mnt/boot/efi
    mount "$EFI_PARTITION" /mnt/boot/efi

    # Turn on swap
    if [[ "${SWAP_PARTITION_SIZE}" != "0" ]]; then
        echo "Enabling swap on ${SWAP_PARTITION}..."
        swapon "$SWAP_PARTITION"
    fi

    echo "Filesystems mounted successfully."
    lsblk
    echo "--------------------------------------------------------"
}


# --- Main Execution ---
main() {
    echo "Starting Arch Linux Disk Setup..."
    select_drive
    wipe_disk
    create_partitions
    format_partitions
    mount_filesystems
    echo "Disk setup is complete. You can now proceed with pacstrap."
    echo "Example: pacstrap /mnt base linux linux-firmware"
}

# Run the main function
main
