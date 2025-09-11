# --- Configuration ---
# You can customize the list of packages to be installed here.
# 'base', 'linux', and 'linux-firmware' are essential.
# Adding a network manager and a text editor is highly recommended.
BASE_PACKAGES=(
    "base"
    "linux"
    "linux-firmware"
    "base-devel"
    "networkmanager"     # For managing network connections in the final system.
    "nano"               # A simple and user-friendly text editor.
    "vim"                # A powerful, more advanced text editor.
    "git"                # Needed for AUR helpers and development.
    "sudo"               # To allow user privilege escalation.
    "man-db"             # For reading manual pages (e.g., `man pacman`).
    "man-pages"
    "texinfo"
    "grub"               # GRUB bootloader
    "efibootmgr"         # EFI boot manager
    "dosfstools"         # FAT filesystem utilities
    "os-prober"          # For detecting other operating systems
    "mtools"             # Tools for manipulating MSDOS files
)

# Optional packages that user can choose to install
OPTIONAL_PACKAGES=(
    "intel-ucode"        # Intel CPU microcode updates
    "amd-ucode"          # AMD CPU microcode updates
    "linux-headers"      # Kernel headers for building modules
    "dkms"               # Dynamic Kernel Module Support
    "reflector"          # Pacman mirror ranking tool
    "wget"               # Web downloader
    "curl"               # Another web tool
    "htop"               # System monitor
    "neofetch"           # System information tool
    "bash-completion"    # Bash auto-completion
    "zsh"                # Z shell
    "fish"               # Friendly interactive shell
)

# --- Script Settings ---
# Exit immediately if a command exits with a non-zero status.
set -e
# Treat unset variables as an error when substituting.
set -u

# --- Functions ---

# Check if /mnt is properly mounted
check_mount() {
    if ! mountpoint -q /mnt; then
        echo "❌ Error: /mnt is not mounted. Please run disk-setup.sh first."
        exit 1
    fi
    
    if ! mountpoint -q /mnt/boot/efi; then
        echo "❌ Error: EFI partition is not mounted at /mnt/boot/efi."
        exit 1
    fi
    
    echo "✅ Mount points verified."
}

# Update package database
update_package_database() {
    echo "Updating package database..."
    pacman -Sy
}

# Detect CPU vendor for microcode
detect_cpu() {
    local cpu_vendor=$(grep -m1 "vendor_id" /proc/cpuinfo | cut -d: -f2 | xargs)
    
    case "$cpu_vendor" in
        "GenuineIntel")
            echo "intel-ucode"
            ;;
        "AuthenticAMD")
            echo "amd-ucode"
            ;;
        *)
            echo ""
            ;;
    esac
}

# Let user select optional packages
select_optional_packages() {
    echo "========================================================="
    echo "                Optional Package Selection"
    echo "========================================================="
    echo "You can choose to install additional packages:"
    echo ""
    
    local selected_packages=()
    
    # Auto-detect and suggest CPU microcode
    local cpu_microcode=$(detect_cpu)
    if [[ -n "$cpu_microcode" ]]; then
        echo "Detected CPU: $(grep -m1 "model name" /proc/cpuinfo | cut -d: -f2 | xargs)"
        read -p "Install $cpu_microcode for CPU microcode updates? (y/n): " install_microcode
        if [[ "$install_microcode" =~ ^[Yy]$ ]]; then
            selected_packages+=("$cpu_microcode")
        fi
    fi
    
    echo ""
    echo "Available optional packages:"
    for i in "${!OPTIONAL_PACKAGES[@]}"; do
        echo "  $((i+1)). ${OPTIONAL_PACKAGES[i]}"
    done
    
    echo ""
    echo "Enter package numbers to install (space-separated), or 'all' for all packages, or 'none' to skip:"
    read -p "Selection: " selection
    
    if [[ "$selection" == "all" ]]; then
        selected_packages+=("${OPTIONAL_PACKAGES[@]}")
    elif [[ "$selection" != "none" && -n "$selection" ]]; then
        for num in $selection; do
            if [[ "$num" =~ ^[0-9]+$ ]] && [ "$num" -ge 1 ] && [ "$num" -le "${#OPTIONAL_PACKAGES[@]}" ]; then
                selected_packages+=("${OPTIONAL_PACKAGES[$((num-1))]}")
            fi
        done
    fi
    
    if [ ${#selected_packages[@]} -gt 0 ]; then
        echo "Selected optional packages: ${selected_packages[*]}"
        BASE_PACKAGES+=("${selected_packages[@]}")
    else
        echo "No optional packages selected."
    fi
}

# --- Main Execution ---
main() {
    echo "========================================================="
    echo "           Arch Linux Base System Installation"
    echo "========================================================="
    
    check_mount
    update_package_database
    select_optional_packages
    
    echo ""
    echo "========================================================="
    echo "Installing base system with pacstrap..."
    echo "========================================================="
    echo "This will download and install all the core packages."
    echo "This process can take a significant amount of time depending on"
    echo "your internet connection and the mirror speed."
    echo ""
    echo "Packages to be installed:"
    printf "  %s\n" "${BASE_PACKAGES[@]}"
    echo ""
    
    read -p "Do you want to proceed with the installation? (y/n): " proceed
    if [[ ! "$proceed" =~ ^[Yy]$ ]]; then
        echo "Installation cancelled."
        exit 0
    fi
    
    echo "Starting installation..."
    # The pacstrap command installs packages to the specified new root directory.
    # The "${BASE_PACKAGES[@]}" syntax expands the array into a space-separated list.
    if ! pacstrap /mnt "${BASE_PACKAGES[@]}"; then
        echo "❌ Base system installation failed."
        exit 1
    fi

    echo ""
    echo "========================================================="
    echo "Generating fstab..."
    echo "========================================================="
    
    # Generate fstab file
    if ! genfstab -U /mnt >> /mnt/etc/fstab; then
        echo "❌ Failed to generate fstab."
        exit 1
    fi
    
    echo "Generated fstab:"
    cat /mnt/etc/fstab
    
    echo ""
    echo "========================================================="
    echo "✅ Base system installation complete!"
    echo "========================================================="
    echo "Next steps:"
    echo "  1. Configure locale and timezone:"
    echo "     ./locale-setup.sh"
    echo "  2. Set up bootloader:"
    echo "     ./grub-setup.sh"
    echo "  3. Create user account:"
    echo "     ./user-setup.sh"
    echo "  4. Chroot into the new system:"
    echo "     arch-chroot /mnt"
    echo "========================================================="
}

# Run the main function
main
