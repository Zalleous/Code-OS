# --- Script Settings ---
# Exit immediately if a command exits with a non-zero status.
set -e
# Treat unset variables as an error when substituting.
# We disable this temporarily because some commands might return empty outputs
# that we need to check.
set +u

# --- Configuration ---
RETRY_ATTEMPTS=3
CONNECTION_TIMEOUT=10

# --- Functions ---

# Pings a reliable host to verify that an internet connection is active.
test_connection() {
    echo "Testing internet connectivity..."
    local hosts=("archlinux.org" "google.com" "1.1.1.1")
    
    for host in "${hosts[@]}"; do
        if ping -c 3 -W 5 "$host" > /dev/null 2>&1; then
            echo "✅ Internet connection is active (reached $host)."
            return 0
        fi
    done
    
    echo "❌ Failed to connect to the internet."
    return 1
}

# Retry a command with exponential backoff
retry_command() {
    local max_attempts=$1
    local delay=1
    local attempt=1
    shift
    
    while [ $attempt -le $max_attempts ]; do
        echo "Attempt $attempt of $max_attempts: $*"
        if "$@"; then
            return 0
        fi
        
        if [ $attempt -lt $max_attempts ]; then
            echo "Command failed. Retrying in ${delay} seconds..."
            sleep $delay
            delay=$((delay * 2))
        fi
        attempt=$((attempt + 1))
    done
    
    echo "Command failed after $max_attempts attempts."
    return 1
}

# Sets up a wired Ethernet connection.
setup_wired_connection() {
    local interface=$1
    echo "Attempting to connect via wired interface: ${interface}..."
    
    # Check if interface is up
    if ! ip link show "$interface" | grep -q "state UP"; then
        echo "Bringing up interface $interface..."
        ip link set "$interface" up
        sleep 2
    fi
    
    # Kill any existing dhcpcd processes for this interface
    pkill -f "dhcpcd.*${interface}" 2>/dev/null || true
    
    # Use dhcpcd to automatically get an IP address.
    echo "Starting DHCP client..."
    if ! retry_command $RETRY_ATTEMPTS dhcpcd -q -t $CONNECTION_TIMEOUT "${interface}"; then
        echo "❌ DHCP failed. Trying with systemd-networkd..."
        systemctl start systemd-networkd
        sleep 5
    fi
    
    echo "Waiting for connection to establish..."
    sleep 5

    # Test the connection.
    if test_connection; then
        echo "✅ Wired connection setup was successful."
        install_networkmanager
    else
        echo "❌ Could not establish a wired connection. Please check your cable and network."
        read -p "Do you want to try a different interface? (y/n): " retry
        if [[ "$retry" =~ ^[Yy]$ ]]; then
            return 1
        else
            exit 1
        fi
    fi
}

# Guides the user through setting up a Wi-Fi connection using iwctl.
setup_wifi_connection() {
    local interface=$1
    echo "Starting Wi-Fi setup for interface: ${interface}..."

    # Ensure the device is powered on.
    echo "Unblocking Wi-Fi devices..."
    rfkill unblock wifi
    sleep 2
    
    # Check if iwd is running
    if ! systemctl is-active --quiet iwd; then
        echo "Starting iwd service..."
        systemctl start iwd
        sleep 3
    fi
    
    # Scan for networks with retry logic.
    echo "Scanning for Wi-Fi networks... (This may take a moment)"
    if ! retry_command 3 iwctl station "${interface}" scan; then
        echo "❌ Failed to scan for networks. Please check if Wi-Fi is available."
        exit 1
    fi
    
    sleep 3  # Give time for scan results
    
    echo "Available Wi-Fi Networks:"
    # List available networks. '--no-pager' prevents it from opening a less-like viewer.
    if ! iwctl --no-pager station "${interface}" get-networks; then
        echo "❌ Could not retrieve network list."
        exit 1
    fi
    echo "--------------------------------------------------------"

    # Get user input for SSID and passphrase with validation.
    while true; do
        read -p "Please enter the Wi-Fi network name (SSID): " ssid
        if [[ -n "$ssid" ]]; then
            break
        fi
        echo "SSID cannot be empty. Please try again."
    done
    
    read -s -p "Please enter the Wi-Fi password (leave blank for open network): " passphrase
    echo "" # Newline after password prompt.

    # Attempt to connect with retry logic.
    echo "Connecting to '${ssid}'..."
    local connect_success=false
    
    for attempt in $(seq 1 $RETRY_ATTEMPTS); do
        echo "Connection attempt $attempt of $RETRY_ATTEMPTS..."
        
        if [ -z "$passphrase" ]; then
            # Connect to an open network.
            if iwctl station "${interface}" connect "${ssid}"; then
                connect_success=true
                break
            fi
        else
            # Connect to a password-protected network.
            if iwctl --passphrase="${passphrase}" station "${interface}" connect "${ssid}"; then
                connect_success=true
                break
            fi
        fi
        
        if [ $attempt -lt $RETRY_ATTEMPTS ]; then
            echo "Connection failed. Retrying in 3 seconds..."
            sleep 3
        fi
    done
    
    if [ "$connect_success" = false ]; then
        echo "❌ Failed to connect after $RETRY_ATTEMPTS attempts."
        read -p "Do you want to try a different network? (y/n): " retry
        if [[ "$retry" =~ ^[Yy]$ ]]; then
            setup_wifi_connection "$interface"
            return
        else
            exit 1
        fi
    fi

    echo "Waiting for connection to establish..."
    sleep 8
    
    # Test the connection.
    if test_connection; then
        echo "✅ Wi-Fi connection setup was successful."
        install_networkmanager
    else
        echo "❌ Could not establish a Wi-Fi connection. Please check your SSID and password."
        read -p "Do you want to try again? (y/n): " retry
        if [[ "$retry" =~ ^[Yy]$ ]]; then
            setup_wifi_connection "$interface"
        else
            exit 1
        fi
    fi
}

# Install and enable NetworkManager for the target system
install_networkmanager() {
    echo "Installing NetworkManager for the target system..."
    
    # Check if we're in a chroot environment or live environment
    if mountpoint -q /mnt; then
        echo "Installing NetworkManager to target system..."
        arch-chroot /mnt pacman -S --noconfirm networkmanager
        arch-chroot /mnt systemctl enable NetworkManager
        echo "✅ NetworkManager installed and enabled for target system."
    else
        echo "⚠️  Target system not mounted. NetworkManager will need to be installed later."
    fi
}


# --- Main Execution ---
main() {
    echo "========================================================="
    echo "           Arch Linux Network Setup Script"
    echo "========================================================="
    
    # Check for an existing connection first.
    if test_connection; then
        echo "✅ An internet connection is already active."
        read -p "Do you want to install NetworkManager anyway? (y/n): " install_nm
        if [[ "$install_nm" =~ ^[Yy]$ ]]; then
            install_networkmanager
        fi
        echo "Network setup complete."
        exit 0
    fi
    
    echo "No active internet connection detected. Setting up network..."
    
    # Get a list of network interfaces (excluding 'lo').
    interfaces=$(ip -o link show | awk -F': ' '{print $2}' | grep -v 'lo')
    
    if [ -z "$interfaces" ]; then
        echo "❌ Error: No network interfaces found. Cannot proceed."
        echo "Please check if your network hardware is properly detected."
        exit 1
    fi
    
    while true; do
        echo ""
        echo "Available network interfaces:"
        echo "--------------------------------------------------------"
        # Display interfaces with their status
        for iface in $interfaces; do
            status=$(ip link show "$iface" | grep -o "state [A-Z]*" | cut -d' ' -f2)
            type="Unknown"
            if [[ "$iface" == e* ]]; then
                type="Ethernet"
            elif [[ "$iface" == w* ]]; then
                type="Wireless"
            fi
            echo "  $iface ($type) - Status: $status"
        done
        echo "--------------------------------------------------------"
        
        # Use a 'select' loop to create a menu for the user.
        PS3="Please choose the interface to configure (or 'q' to quit): "
        select interface in $interfaces "Quit"; do
            if [[ "$interface" == "Quit" ]]; then
                echo "Exiting network setup."
                exit 0
            elif [[ -n "$interface" ]]; then
                echo "You selected: ${interface}"
                break
            else
                echo "Invalid selection. Please try again."
            fi
        done

        # Check if the selected interface is wired (starts with 'e') or wireless (starts with 'w').
        connection_success=false
        if [[ "$interface" == e* ]]; then
            if setup_wired_connection "$interface"; then
                connection_success=true
            fi
        elif [[ "$interface" == w* ]]; then
            if setup_wifi_connection "$interface"; then
                connection_success=true
            fi
        else
            echo "Unrecognized interface type: ${interface}. Attempting with DHCP..."
            if setup_wired_connection "$interface"; then
                connection_success=true
            fi
        fi
        
        if [ "$connection_success" = true ]; then
            break
        fi
        
        echo ""
        read -p "Would you like to try a different interface? (y/n): " try_again
        if [[ ! "$try_again" =~ ^[Yy]$ ]]; then
            echo "Exiting network setup."
            exit 1
        fi
    done

    echo "========================================================="
    echo "✅ Network setup complete successfully!"
    echo "========================================================="
}

# Run the main function
main
