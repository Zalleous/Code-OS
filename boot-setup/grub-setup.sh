#!/bin/bash

# --- Configuration ---
GRUB_TIMEOUT=5
GRUB_DEFAULT=0

# --- Script Settings ---
set -e
set -u

# --- Functions ---

# Check if we're in the right environment
check_environment() {
    if ! mountpoint -q /mnt; then
        echo "❌ Error: /mnt is not mounted. Please run previous setup scripts first."
        exit 1
    fi
    
    if ! mountpoint -q /mnt/boot/efi; then
        echo "❌ Error: EFI partition is not mounted at /mnt/boot/efi."
        exit 1
    fi
    
    if [ ! -f /mnt/etc/fstab ]; then
        echo "❌ Error: Base system not installed. Please run base-setup.sh first."
        exit 1
    fi
    
    # Check if GRUB is installed
    if ! arch-chroot /mnt which grub-install >/dev/null 2>&1; then
        echo "❌ Error: GRUB is not installed. Please run base-setup.sh first."
        exit 1
    fi
    
    echo "✅ Environment check passed."
}

# Detect if system is UEFI or BIOS
detect_boot_mode() {
    if [ -d /sys/firmware/efi ]; then
        echo "✅ UEFI boot mode detected."
        BOOT_MODE="uefi"
    else
        echo "⚠️  BIOS boot mode detected."
        BOOT_MODE="bios"
        echo "Warning: This script is optimized for UEFI systems."
        read -p "Do you want to continue with BIOS setup? (y/n): " continue_bios
        if [[ ! "$continue_bios" =~ ^[Yy]$ ]]; then
            exit 0
        fi
    fi
}

# Install GRUB for UEFI systems
install_grub_uefi() {
    echo "========================================================="
    echo "                Installing GRUB (UEFI)"
    echo "========================================================="
    
    # Install GRUB to EFI directory
    echo "Installing GRUB to EFI system partition..."
    if ! arch-chroot /mnt grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=GRUB; then
        echo "❌ Failed to install GRUB."
        exit 1
    fi
    
    echo "✅ GRUB installed successfully."
}

# Install GRUB for BIOS systems
install_grub_bios() {
    echo "========================================================="
    echo "                Installing GRUB (BIOS)"
    echo "========================================================="
    
    # Get the disk device (without partition number)
    local disk_device
    if [[ -n "${TARGET_DRIVE:-}" ]]; then
        disk_device="$TARGET_DRIVE"
    else
        # Try to detect from mounted root partition
        local root_partition=$(findmnt -n -o SOURCE /mnt)
        if [[ "$root_partition" == *"nvme"* ]] || [[ "$root_partition" == *"mmcblk"* ]]; then
            disk_device=$(echo "$root_partition" | sed 's/p[0-9]*$//')
        else
            disk_device=$(echo "$root_partition" | sed 's/[0-9]*$//')
        fi
    fi
    
    echo "Installing GRUB to $disk_device..."
    if ! arch-chroot /mnt grub-install --target=i386-pc "$disk_device"; then
        echo "❌ Failed to install GRUB."
        exit 1
    fi
    
    echo "✅ GRUB installed successfully."
}

# Configure GRUB
configure_grub() {
    echo "========================================================="
    echo "                 Configuring GRUB"
    echo "========================================================="
    
    # Backup original GRUB configuration
    if [ -f /mnt/etc/default/grub ]; then
        cp /mnt/etc/default/grub /mnt/etc/default/grub.backup
    fi
    
    # Configure GRUB settings
    echo "Configuring GRUB settings..."
    
    # Set timeout
    arch-chroot /mnt sed -i "s/^GRUB_TIMEOUT=.*/GRUB_TIMEOUT=$GRUB_TIMEOUT/" /etc/default/grub
    
    # Set default entry
    arch-chroot /mnt sed -i "s/^GRUB_DEFAULT=.*/GRUB_DEFAULT=$GRUB_DEFAULT/" /etc/default/grub
    
    # Enable os-prober to detect other operating systems
    if ! grep -q "^GRUB_DISABLE_OS_PROBER=false" /mnt/etc/default/grub; then
        echo "GRUB_DISABLE_OS_PROBER=false" >> /mnt/etc/default/grub
    fi
    
    # Improve GRUB appearance
    arch-chroot /mnt sed -i 's/^#GRUB_COLOR_NORMAL=.*/GRUB_COLOR_NORMAL="light-blue\/black"/' /etc/default/grub
    arch-chroot /mnt sed -i 's/^#GRUB_COLOR_HIGHLIGHT=.*/GRUB_COLOR_HIGHLIGHT="light-cyan\/blue"/' /etc/default/grub
    
    # Generate GRUB configuration
    echo "Generating GRUB configuration..."
    if ! arch-chroot /mnt grub-mkconfig -o /boot/grub/grub.cfg; then
        echo "❌ Failed to generate GRUB configuration."
        exit 1
    fi
    
    echo "✅ GRUB configuration generated successfully."
}

# Enable essential services
enable_services() {
    echo "========================================================="
    echo "                Enabling Essential Services"
    echo "========================================================="
    
    # Enable NetworkManager
    echo "Enabling NetworkManager..."
    arch-chroot /mnt systemctl enable NetworkManager
    
    # Enable systemd-timesyncd for time synchronization
    echo "Enabling time synchronization..."
    arch-chroot /mnt systemctl enable systemd-timesyncd
    
    # Enable fstrim timer for SSD maintenance (if applicable)
    echo "Enabling fstrim timer for SSD maintenance..."
    arch-chroot /mnt systemctl enable fstrim.timer
    
    echo "✅ Essential services enabled."
}

# Set root password
set_root_password() {
    echo "========================================================="
    echo "                 Root Password Setup"
    echo "========================================================="
    
    echo "You need to set a password for the root user."
    echo "This is important for system security."
    echo ""
    
    while true; do
        echo "Setting root password..."
        if arch-chroot /mnt passwd; then
            echo "✅ Root password set successfully."
            break
        else
            echo "❌ Failed to set root password. Please try again."
        fi
    done
}

# Create initial ramdisk
create_initramfs() {
    echo "========================================================="
    echo "                Creating Initial Ramdisk"
    echo "========================================================="
    
    echo "Generating initial ramdisk..."
    if ! arch-chroot /mnt mkinitcpio -P; then
        echo "❌ Failed to create initial ramdisk."
        exit 1
    fi
    
    echo "✅ Initial ramdisk created successfully."
}

# --- Main Execution ---
main() {
    echo "========================================================="
    echo "              Arch Linux GRUB Setup Script"
    echo "========================================================="
    echo "This script will:"
    echo "  1. Detect boot mode (UEFI/BIOS)"
    echo "  2. Install GRUB bootloader"
    echo "  3. Configure GRUB settings"
    echo "  4. Generate GRUB configuration"
    echo "  5. Enable essential services"
    echo "  6. Set root password"
    echo "  7. Create initial ramdisk"
    echo ""
    
    check_environment
    detect_boot_mode
    
    echo ""
    read -p "Do you want to continue with GRUB installation? (y/n): " proceed
    if [[ ! "$proceed" =~ ^[Yy]$ ]]; then
        echo "GRUB setup cancelled."
        exit 0
    fi
    
    # Install GRUB based on boot mode
    if [ "$BOOT_MODE" = "uefi" ]; then
        install_grub_uefi
    else
        install_grub_bios
    fi
    
    configure_grub
    create_initramfs
    enable_services
    set_root_password
    
    echo ""
    echo "========================================================="
    echo "✅ GRUB setup completed successfully!"
    echo "========================================================="
    echo "Boot configuration:"
    echo "  Boot mode: $BOOT_MODE"
    echo "  GRUB timeout: $GRUB_TIMEOUT seconds"
    echo "  Default entry: $GRUB_DEFAULT"
    echo ""
    echo "Next steps:"
    echo "  1. Create user account: ./user-setup.sh"
    echo "  2. Reboot into your new Arch Linux system"
    echo ""
    echo "⚠️  Important: Make sure to remove the installation media before rebooting!"
    echo "========================================================="
}

# Run the main function
main
