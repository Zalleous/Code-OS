# --- Script Settings ---
# Exit immediately if a command exits with a non-zero status.
set -e
# Treat unset variables as an error when substituting.
# We disable this temporarily because some commands might return empty outputs
# that we need to check.
set +u

# --- Functions ---

# Pings a reliable host to verify that an internet connection is active.
test_connection() {
    echo "Testing internet connectivity..."
    if ping -c 3 archlinux.org > /dev/null 2>&1; then
        echo "✅ Internet connection is active."
        return 0
    else
        echo "❌ Failed to connect to the internet."
        return 1
    fi
}

# Sets up a wired Ethernet connection.
setup_wired_connection() {
    local interface=$1
    echo "Attempting to connect via wired interface: ${interface}..."
    
    # Use dhcpcd to automatically get an IP address.
    # The '-q' flag makes it quiet, and '-b' runs it in the background.
    dhcpcd "${interface}"
    
    echo "Waiting a few seconds for the connection to establish..."
    sleep 5

    # Test the connection.
    if test_connection; then
        echo "Wired connection setup was successful."
    else
        echo "Could not establish a wired connection. Please check your cable and network."
        exit 1
    fi
}

# Guides the user through setting up a Wi-Fi connection using iwctl.
setup_wifi_connection() {
    local interface=$1
    echo "Starting Wi-Fi setup for interface: ${interface}..."

    # Ensure the device is powered on.
    rfkill unblock wifi
    
    # Scan for networks.
    echo "Scanning for Wi-Fi networks... (This may take a moment)"
    iwctl station "${interface}" scan
    
    echo "Available Wi-Fi Networks:"
    # List available networks. '--no-pager' prevents it from opening a less-like viewer.
    iwctl --no-pager station "${interface}" get-networks
    echo "--------------------------------------------------------"

    # Get user input for SSID and passphrase.
    read -p "Please enter the Wi-Fi network name (SSID): " ssid
    read -s -p "Please enter the Wi-Fi password (leave blank for open network): " passphrase
    echo "" # Newline after password prompt.

    # Attempt to connect.
    echo "Connecting to '${ssid}'..."
    if [ -z "$passphrase" ]; then
        # Connect to an open network.
        iwctl station "${interface}" connect "${ssid}"
    else
        # Connect to a password-protected network.
        iwctl --passphrase="${passphrase}" station "${interface}" connect "${ssid}"
    fi

    echo "Waiting a few seconds for the connection to establish..."
    sleep 5
    
    # Test the connection.
    if test_connection; then
        echo "Wi-Fi connection setup was successful."
    else
        echo "Could not establish a Wi-Fi connection. Please check your SSID and password."
        exit 1
    fi
}


# --- Main Execution ---
main() {
    echo "Starting Network Setup..."
    
    # Check for an existing connection first.
    if ping -c 1 archlinux.org > /dev/null 2>&1; then
        echo "An internet connection is already active. No setup needed."
        exit 0
    fi
    
    # Get a list of network interfaces (excluding 'lo').
    interfaces=$(ip -o link show | awk -F': ' '{print $2}' | grep -v 'lo')
    
    if [ -z "$interfaces" ]; then
        echo "Error: No network interfaces found. Cannot proceed."
        exit 1
    fi
    
    echo "Available network interfaces:"
    # Use a 'select' loop to create a menu for the user.
    PS3="Please choose the interface to configure: "
    select interface in $interfaces; do
        if [[ -n "$interface" ]]; then
            echo "You selected: ${interface}"
            break
        else
            echo "Invalid selection. Please try again."
        fi
    done

    # Check if the selected interface is wired (starts with 'e') or wireless (starts with 'w').
    if [[ "$interface" == e* ]]; then
        setup_wired_connection "$interface"
    elif [[ "$interface" == w* ]]; then
        setup_wifi_connection "$interface"
    else
        echo "Unrecognized interface type: ${interface}. Attempting with DHCP..."
        setup_wired_connection "$interface"
    fi

    echo "--------------------------------------------------------"
    echo "Network setup complete."
}

# Run the main function
main