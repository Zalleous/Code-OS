#!/bin/bash

# --- Configuration ---
# Default locale settings
DEFAULT_LOCALE="en_US.UTF-8"
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

# Set up locale
setup_locale() {
    echo "========================================================="
    echo "                    Locale Configuration"
    echo "========================================================="
    
    # Check if locale is already configured
    if [ -f /mnt/etc/locale.conf ]; then
        current_locale=$(grep "^LANG=" /mnt/etc/locale.conf | cut -d= -f2)
        echo "Current locale: $current_locale"
        read -p "Do you want to change the locale configuration? (y/n): " change_locale
        if [[ ! "$change_locale" =~ ^[Yy]$ ]]; then
            echo "Keeping current locale configuration."
            SELECTED_LOCALE="$current_locale"
            return 0
        fi
    fi
    
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
    
    # Check if we're in chroot or need to use arch-chroot
    if [ -f /etc/locale.gen ]; then
        # We're in chroot environment
        sed -i "s/^#${SELECTED_LOCALE}/${SELECTED_LOCALE}/" /etc/locale.gen
        
        # Also enable en_US.UTF-8 as fallback if it's not the selected locale
        if [[ "$SELECTED_LOCALE" != "en_US.UTF-8" ]]; then
            sed -i 's/^#en_US.UTF-8/en_US.UTF-8/' /etc/locale.gen
        fi
        
        # Generate locales
        echo "Generating locales..."
        locale-gen
        
        # Set system locale
        echo "LANG=$SELECTED_LOCALE" > /etc/locale.conf
    else
        # We're in live environment, use arch-chroot
        sed -i "s/^#${SELECTED_LOCALE}/${SELECTED_LOCALE}/" /mnt/etc/locale.gen
        
        # Also enable en_US.UTF-8 as fallback if it's not the selected locale
        if [[ "$SELECTED_LOCALE" != "en_US.UTF-8" ]]; then
            sed -i 's/^#en_US.UTF-8/en_US.UTF-8/' /mnt/etc/locale.gen
        fi
        
        # Generate locales
        echo "Generating locales..."
        arch-chroot /mnt locale-gen
        
        # Set system locale
        echo "LANG=$SELECTED_LOCALE" > /mnt/etc/locale.conf
    fi
    
    echo "✅ Locale set to $SELECTED_LOCALE"
}

# Set up keyboard layout
setup_keymap() {
    echo "========================================================="
    echo "                  Keyboard Configuration"
    echo "========================================================="
    
    # Check if keymap is already configured
    if [ -f /mnt/etc/vconsole.conf ]; then
        current_keymap=$(grep "^KEYMAP=" /mnt/etc/vconsole.conf | cut -d= -f2)
        echo "Current keymap: $current_keymap"
        read -p "Do you want to change the keyboard layout? (y/n): " change_keymap
        if [[ ! "$change_keymap" =~ ^[Yy]$ ]]; then
            echo "Keeping current keyboard layout."
            SELECTED_KEYMAP="$current_keymap"
            return 0
        fi
    fi
    
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
    if [ -f /etc/vconsole.conf ] || [ ! -d /mnt ]; then
        # We're in chroot or no /mnt exists
        echo "KEYMAP=$SELECTED_KEYMAP" > /etc/vconsole.conf
    else
        # We're in live environment
        echo "KEYMAP=$SELECTED_KEYMAP" > /mnt/etc/vconsole.conf
    fi
    
    echo "✅ Keyboard layout set to $SELECTED_KEYMAP"
}

# Set hostname
setup_hostname() {
    echo "========================================================="
    echo "                   Hostname Configuration"
    echo "========================================================="
    
    # Check if hostname is already configured
    if [ -f /mnt/etc/hostname ]; then
        current_hostname=$(cat /mnt/etc/hostname)
        echo "Current hostname: $current_hostname"
        read -p "Do you want to change the hostname? (y/n): " change_hostname
        if [[ ! "$change_hostname" =~ ^[Yy]$ ]]; then
            echo "Keeping current hostname."
            hostname="$current_hostname"
            return 0
        fi
    fi
    
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
    if [ -f /etc/hostname ] || [ ! -d /mnt ]; then
        # We're in chroot or no /mnt exists
        echo "$hostname" > /etc/hostname
        
        # Configure hosts file
        cat > /etc/hosts << EOF
127.0.0.1   localhost
::1         localhost
127.0.1.1   $hostname.localdomain $hostname
EOF
    else
        # We're in live environment
        echo "$hostname" > /mnt/etc/hostname
        
        # Configure hosts file
        cat > /mnt/etc/hosts << EOF
127.0.0.1   localhost
::1         localhost
127.0.1.1   $hostname.localdomain $hostname
EOF
    fi
    
    echo "✅ Hostname set to $hostname"
}

# --- Main Execution ---
main() {
    echo "========================================================="
    echo "         Arch Linux Locale and Language Setup"
    echo "========================================================="
    echo "This script will configure:"
    echo "  1. System locale (language)"
    echo "  2. Keyboard layout"
    echo "  3. System hostname"
    echo ""
    echo "Note: Timezone configuration is handled separately."
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
    echo "  Locale: $SELECTED_LOCALE"
    echo "  Keymap: $SELECTED_KEYMAP"
    echo "  Hostname: $(cat /mnt/etc/hostname)"
    echo ""
    echo "Locale and language configuration is now complete."
    echo "========================================================="
}

# Run the main function
main
