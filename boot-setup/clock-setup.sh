#!/bin/bash

# --- Script Settings ---
set -e
set -u

# --- Functions ---

resetUI() {
    clear
    echo "========================================================="
    echo "                 Arch Linux Clock Setup"
    echo "========================================================="
    if command -v timedatectl >/dev/null 2>&1; then
        timedatectl status
    else
        echo "Current time: $(date)"
    fi
    echo "========================================================="
    echo ""
}

setupClock() {
    echo "Setting up system timezone and clock..."
    
    # Get available timezones
    if [ -d /usr/share/zoneinfo ]; then
        timezones=$(find /usr/share/zoneinfo -type f | grep -v "posix\|right" | sed 's|/usr/share/zoneinfo/||' | sort)
    else
        echo "❌ Timezone data not available."
        return 1
    fi
    
    echo "Available timezone regions:"
    regions=$(echo "$timezones" | cut -d'/' -f1 | sort -u | head -20)
    echo "$regions" | nl
    echo ""
    
    PS3="Select your region (number): "
    select region in $(echo "$regions"); do
        if [[ -n "$region" ]]; then
            break
        else
            echo "❌ Invalid selection. Please try again."
        fi
    done

    clear
    echo "========================================================="
    echo "Selected region: $region"
    echo "========================================================="
    
    echo "Available zones in $region:"
    zones=$(echo "$timezones" | grep "^$region/" | cut -d'/' -f2- | head -20)
    echo "$zones" | nl
    echo ""

    PS3="Select your zone (number): "
    select zone in $(echo "$zones"); do
        if [[ -n "$zone" ]]; then
            SELECTED_TIMEZONE="$region/$zone"
            break
        else
            echo "❌ Invalid selection. Please try again."
        fi
    done
    
    echo ""
    echo "Selected timezone: $SELECTED_TIMEZONE"
    
    # Set timezone in target system
    if [ -d /mnt ]; then
        echo "Setting timezone in target system..."
        if [ -f "/usr/share/zoneinfo/$SELECTED_TIMEZONE" ]; then
            ln -sf "/usr/share/zoneinfo/$SELECTED_TIMEZONE" /mnt/etc/localtime
            
            # Set hardware clock if we're in live environment
            if command -v hwclock >/dev/null 2>&1; then
                arch-chroot /mnt hwclock --systohc 2>/dev/null || hwclock --systohc
            fi
            
            echo "✅ Timezone set to $SELECTED_TIMEZONE in target system"
        else
            echo "❌ Timezone file not found: $SELECTED_TIMEZONE"
            return 1
        fi
    else
        # Set for current system (if in chroot)
        echo "Setting timezone for current system..."
        if command -v timedatectl >/dev/null 2>&1; then
            timedatectl set-timezone "$SELECTED_TIMEZONE"
            timedatectl set-ntp true
        else
            ln -sf "/usr/share/zoneinfo/$SELECTED_TIMEZONE" /etc/localtime
        fi
        
        if command -v hwclock >/dev/null 2>&1; then
            hwclock --systohc
        fi
        
        echo "✅ Timezone set to $SELECTED_TIMEZONE"
    fi
}

# --- Main Execution ---
main() {
    resetUI
    
    while true; do
        read -p "Do you want to configure the timezone? (y/n): " yesNo
        
        case "$yesNo" in
            [Yy]*)
                setupClock
                resetUI
                break
                ;;
            [Nn]*)
                echo "Skipping timezone configuration."
                break
                ;;
            *)
                echo "Please answer y/Y or n/N"
                ;;
        esac
    done
    
    echo "Clock setup complete."
}

# Run the main function
main
