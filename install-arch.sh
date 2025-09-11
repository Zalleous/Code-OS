#!/bin/bash

# --- Configuration ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BOOT_SETUP_DIR="$SCRIPT_DIR/boot-setup"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# --- Script Settings ---
set -e

# --- Functions ---

print_header() {
    clear
    echo -e "${BLUE}=========================================================${NC}"
    echo -e "${BLUE}              Arch Linux Installation Suite${NC}"
    echo -e "${BLUE}=========================================================${NC}"
    echo ""
}

print_step() {
    echo -e "${GREEN}[STEP $1]${NC} $2"
    echo ""
}

print_warning() {
    echo -e "${YELLOW}⚠️  WARNING:${NC} $1"
}

print_error() {
    echo -e "${RED}❌ ERROR:${NC} $1"
}

print_success() {
    echo -e "${GREEN}✅ SUCCESS:${NC} $1"
}

check_environment() {
    print_header
    echo "Checking installation environment..."
    echo ""
    
    # Check if we're booted from Arch ISO
    if [ ! -f /etc/arch-release ]; then
        print_error "This script must be run from an Arch Linux installation environment."
        exit 1
    fi
    
    # Check if we're running as root
    if [ "$EUID" -ne 0 ]; then
        print_error "This script must be run as root. Use: sudo $0"
        exit 1
    fi
    
    # Check if scripts exist
    local required_scripts=(
        "network-setup.sh"
        "disk-setup.sh" 
        "base-setup.sh"
        "locale-setup.sh"
        "clock-setup.sh"
        "grub-setup.sh"
        "user-setup.sh"
    )
    
    for script in "${required_scripts[@]}"; do
        if [ ! -f "$BOOT_SETUP_DIR/$script" ]; then
            print_error "Required script not found: $BOOT_SETUP_DIR/$script"
            exit 1
        fi
        
        if [ ! -x "$BOOT_SETUP_DIR/$script" ]; then
            print_warning "Making $script executable..."
            chmod +x "$BOOT_SETUP_DIR/$script"
        fi
    done
    
    print_success "Environment check passed."
    echo ""
}

run_script() {
    local script_name="$1"
    local step_number="$2"
    local description="$3"
    
    print_step "$step_number" "$description"
    
    echo "Running: $script_name"
    echo "----------------------------------------"
    
    if ! "$BOOT_SETUP_DIR/$script_name"; then
        print_error "Script $script_name failed. Installation cannot continue."
        echo ""
        echo "You can try to:"
        echo "  1. Fix the issue and run the script manually: $BOOT_SETUP_DIR/$script_name"
        echo "  2. Restart the installation: $0"
        exit 1
    fi
    
    print_success "$script_name completed successfully."
    echo ""
    
    read -p "Press Enter to continue to the next step..."
    echo ""
}

show_summary() {
    print_header
    echo "Installation Summary:"
    echo "----------------------------------------"
    echo "The following steps will be performed:"
    echo ""
    echo "  1. Network Setup - Configure internet connection"
    echo "  2. Disk Setup - Partition and format storage"
    echo "  3. Base System - Install core Arch Linux packages"
    echo "  4. Locale Setup - Configure language and keyboard"
    echo "  5. Clock Setup - Configure timezone and time"
    echo "  6. GRUB Setup - Install and configure bootloader"
    echo "  7. User Setup - Create user account and configure sudo"
    echo ""
    print_warning "This will modify your system and potentially destroy data!"
    echo ""
    
    while true; do
        read -p "Do you want to proceed with the installation? (y/n): " proceed
        case "$proceed" in
            [Yy]*)
                break
                ;;
            [Nn]*)
                echo "Installation cancelled."
                exit 0
                ;;
            *)
                echo "Please answer y or n."
                ;;
        esac
    done
}

final_steps() {
    print_header
    print_success "Arch Linux installation completed successfully!"
    echo ""
    echo "========================================================="
    echo "                    FINAL STEPS"
    echo "========================================================="
    echo ""
    echo "Your Arch Linux system is now installed and configured."
    echo ""
    echo "To complete the installation:"
    echo ""
    echo "  1. Exit any chroot environment (if applicable)"
    echo "  2. Unmount all filesystems:"
    echo "     umount -R /mnt"
    echo "  3. Reboot the system:"
    echo "     reboot"
    echo "  4. Remove the installation media"
    echo "  5. Boot into your new Arch Linux system"
    echo ""
    echo "After first boot:"
    echo "  - Update the system: sudo pacman -Syu"
    echo "  - Install additional software as needed"
    echo "  - Configure desktop environment (if desired)"
    echo ""
    echo "========================================================="
    echo ""
    
    while true; do
        read -p "Do you want to reboot now? (y/n): " reboot_now
        case "$reboot_now" in
            [Yy]*)
                echo "Unmounting filesystems..."
                umount -R /mnt 2>/dev/null || true
                echo "Rebooting in 5 seconds..."
                sleep 5
                reboot
                ;;
            [Nn]*)
                echo "Remember to unmount filesystems and reboot manually."
                break
                ;;
            *)
                echo "Please answer y or n."
                ;;
        esac
    done
}

# --- Main Execution ---
main() {
    # Trap to handle script interruption
    trap 'echo -e "\n${RED}Installation interrupted.${NC}"; exit 1' INT TERM
    
    check_environment
    show_summary
    
    # Execute installation steps
    run_script "network-setup.sh" "1" "Setting up network connection"
    run_script "disk-setup.sh" "2" "Partitioning and formatting disk"
    run_script "base-setup.sh" "3" "Installing base system packages"
    run_script "locale-setup.sh" "4" "Configuring locale and language"
    run_script "clock-setup.sh" "5" "Setting up timezone and clock"
    run_script "grub-setup.sh" "6" "Installing and configuring GRUB bootloader"
    run_script "user-setup.sh" "7" "Creating user account and configuring system"
    
    final_steps
}

# Check if script is being sourced or executed
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
