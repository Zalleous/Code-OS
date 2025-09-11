#!/bin/bash

# --- Configuration ---
# Default locale settings
DEFAULT_LOCALE="en_US.UTF-8"
DEFAULT_TIMEZONE="UTC"
DEFAULT_KEYMAP="us"

# Available locales (most common ones)
COMMON_LOCALES=(
    "en_US.UTF-8"
    "en_GB.UTF-8"
    "de_DE.UTF-8"
    "fr_FR.UTF-8"
    "es_ES.UTF-8"
    "it_IT.UTF-8"
    "pt_PT.UTF-8"
    "ru_RU.UTF-8"
    "ja_JP.UTF-8"
    "ko_KR.UTF-8"
    "zh_CN.UTF-8"
    "zh_TW.UTF-8"
)

# --- Script Settings ---
set -e
set -u

# --- Functions ---

# Check if we're in the right environment
check_environment() {
    if ! mountpoint -q /mnt; then
        echo "❌ Error: /mnt is not mounted. Please run disk-setup.sh and base-setup.sh first."
        exit 1
    fi
    
    if [ ! -f /mnt/etc/fstab ]; then
        echo "❌ Error: Base system not installed. Please run base-setup.sh first."
        exit 1
    fi
    
    echo "✅ Environment check passed."
}

# Set up timezone
setup_timezone() {
    echo "========================================================="
    echo "                   Timezone Configuration"
    echo "========================================================="
    
    echo "Available timezone regions:"
    ls /usr/share/zoneinfo/ | grep -v "posix\|right" | head -20
    echo "... (and more)"
    echo ""
    
    while true; do
        read -p "Enter your timezone region (e.g., America, Europe, Asia) or 'list' to see all: " region
        
        if [[ "$region" == "list" ]]; then
            echo "Available regions:"
            ls /usr/share/zoneinfo/ | grep -v "posix\|right" | column
            continue
        fi
        
        if [ -d "/usr/share/zoneinfo/$region" ]; then
            break
        else
            echo "❌ Region '$region' not found. Please try again."
        fi
    done
    
    echo ""
    echo "Available cities/zones in $region:"
    ls "/usr/share/zoneinfo/$region" | head -20
    if [ $(ls "/usr/share/zoneinfo/$region" | wc -l) -gt 20 ]; then
        echo "... (and more)"
    fi
    echo ""
    
    while true; do
        read -p "Enter your city/zone (e.g., New_York, London, Tokyo): " city
        
        if [ -f "/usr/share/zoneinfo/$region/$city" ]; then
            SELECTED_TIMEZONE="$region/$city"
            break
        else
            echo "❌ City '$city' not found in region '$region'. Please try again."
            echo "Available options:"
            ls "/usr/share/zoneinfo/$region" | grep -i "$city" || echo "No matches found."
        fi
    done
    
    echo ""
    echo "Selected timezone: $SELECTED_TIMEZONE"
    
    # Set timezone in the target system
    echo "Setting timezone in target system..."
    arch-chroot /mnt ln -sf "/usr/share/zoneinfo/$SELECTED_TIMEZONE" /etc/localtime
    arch-chroot /mnt hwclock --systohc
    
    echo "✅ Timezone set to $SELECTED_TIMEZONE"
}

# Set up locale
setup_locale() {
    echo "========================================================="
    echo "                    Locale Configuration"
    echo "========================================================="
    
    echo "Common locales:"
    for i in "${!COMMON_LOCALES[@]}"; do
        echo "  $((i+1)). ${COMMON_LOCALES[i]}"
    done
    echo "  $((${#COMMON_LOCALES[@]}+1)). Custom locale"
    echo ""
    
    while true; do
        read -p "Select a locale (1-$((${#COMMON_LOCALES[@]}+1))) or enter locale name directly: " locale_choice
        
        if [[ "$locale_choice" =~ ^[0-9]+$ ]]; then
            if [ "$locale_choice" -ge 1 ] && [ "$locale_choice" -le "${#COMMON_LOCALES[@]}" ]; then
                SELECTED_LOCALE="${COMMON_LOCALES[$((locale_choice-1))]}"
                break
            elif [ "$locale_choice" -eq $((${#COMMON_LOCALES[@]}+1)) ]; then
                read -p "Enter custom locale (e.g., en_US.UTF-8): " SELECTED_LOCALE
                break
            else
                echo "❌ Invalid selection. Please try again."
            fi
        else
            # Assume it's a locale name
            SELECTED_LOCALE="$locale_choice"
            break
        fi
    done
    
    echo ""
    echo "Selected locale: $SELECTED_LOCALE"
    
    # Enable the locale in the target system
    echo "Enabling locale in target system..."
    
    # Uncomment the locale in locale.gen
    arch-chroot /mnt sed -i "s/^#${SELECTED_LOCALE}/${SELECTED_LOCALE}/" /etc/locale.gen
    
    # Also enable en_US.UTF-8 as fallback if it's not the selected locale
    if [[ "$SELECTED_LOCALE" != "en_US.UTF-8" ]]; then
        arch-chroot /mnt sed -i 's/^#en_US.UTF-8/en_US.UTF-8/' /etc/locale.gen
    fi
    
    # Generate locales
    echo "Generating locales..."
    arch-chroot /mnt locale-gen
    
    # Set system locale
    echo "LANG=$SELECTED_LOCALE" > /mnt/etc/locale.conf
    
    echo "✅ Locale set to $SELECTED_LOCALE"
}

# Set up keyboard layout
setup_keymap() {
    echo "========================================================="
    echo "                  Keyboard Configuration"
    echo "========================================================="
    
    echo "Common keyboard layouts:"
    echo "  1. us (US English)"
    echo "  2. uk (UK English)"
    echo "  3. de (German)"
    echo "  4. fr (French)"
    echo "  5. es (Spanish)"
    echo "  6. it (Italian)"
    echo "  7. ru (Russian)"
    echo "  8. Custom layout"
    echo ""
    
    while true; do
        read -p "Select keyboard layout (1-8): " keymap_choice
        
        case "$keymap_choice" in
            1) SELECTED_KEYMAP="us"; break ;;
            2) SELECTED_KEYMAP="uk"; break ;;
            3) SELECTED_KEYMAP="de"; break ;;
            4) SELECTED_KEYMAP="fr"; break ;;
            5) SELECTED_KEYMAP="es"; break ;;
            6) SELECTED_KEYMAP="it"; break ;;
            7) SELECTED_KEYMAP="ru"; break ;;
            8) 
                echo "Available keymaps:"
                ls /usr/share/kbd/keymaps/**/*.map.gz | head -20
                echo "... (and more)"
                read -p "Enter keymap name: " SELECTED_KEYMAP
                break
                ;;
            *) echo "❌ Invalid selection. Please try again." ;;
        esac
    done
    
    echo ""
    echo "Selected keymap: $SELECTED_KEYMAP"
    
    # Set console keymap
    echo "KEYMAP=$SELECTED_KEYMAP" > /mnt/etc/vconsole.conf
    
    echo "✅ Keyboard layout set to $SELECTED_KEYMAP"
}

# Set hostname
setup_hostname() {
    echo "========================================================="
    echo "                   Hostname Configuration"
    echo "========================================================="
    
    while true; do
        read -p "Enter hostname for this system: " hostname
        
        # Validate hostname
        if [[ "$hostname" =~ ^[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?$ ]]; then
            break
        else
            echo "❌ Invalid hostname. Use only letters, numbers, and hyphens."
            echo "   Hostname must start and end with alphanumeric characters."
        fi
    done
    
    echo "Selected hostname: $hostname"
    
    # Set hostname
    echo "$hostname" > /mnt/etc/hostname
    
    # Configure hosts file
    cat > /mnt/etc/hosts << EOF
127.0.0.1   localhost
::1         localhost
127.0.1.1   $hostname.localdomain $hostname
EOF
    
    echo "✅ Hostname set to $hostname"
}

# --- Main Execution ---
main() {
    echo "========================================================="
    echo "         Arch Linux Locale and Language Setup"
    echo "========================================================="
    echo "This script will configure:"
    echo "  1. System timezone"
    echo "  2. System locale (language)"
    echo "  3. Keyboard layout"
    echo "  4. System hostname"
    echo ""
    
    check_environment
    
    setup_timezone
    echo ""
    setup_locale
    echo ""
    setup_keymap
    echo ""
    setup_hostname
    
    echo ""
    echo "========================================================="
    echo "✅ Locale and language setup complete!"
    echo "========================================================="
    echo "Configuration summary:"
    echo "  Timezone: $SELECTED_TIMEZONE"
    echo "  Locale: $SELECTED_LOCALE"
    echo "  Keymap: $SELECTED_KEYMAP"
    echo "  Hostname: $(cat /mnt/etc/hostname)"
    echo ""
    echo "Next steps:"
    echo "  1. Set up bootloader: ./grub-setup.sh"
    echo "  2. Create user account: ./user-setup.sh"
    echo "========================================================="
}

# Run the main function
main
