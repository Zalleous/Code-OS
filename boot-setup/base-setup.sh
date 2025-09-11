# --- Configuration ---
# You can customize the list of packages to be installed here.
# 'base', 'linux', and 'linux-firmware' are essential.
# Adding a network manager and a text editor is highly recommended.
BASE_PACKAGES=(
    "base"
    "linux"
    "linux-firmware"
    "base-devel"
    "networkmanager" # For managing network connections in the final system.
    "nano"           # A simple and user-friendly text editor.
    "vim"            # A powerful, more advanced text editor.
    "git"            # Needed for AUR helpers and development.
    "sudo"           # To allow user privilege escalation.
    "man-db"         # For reading manual pages (e.g., `man pacman`).
    "man-pages"
    "texinfo"
)

# --- Script Settings ---
# Exit immediately if a command exits with a non-zero status.
set -e
# Treat unset variables as an error when substituting.
set -u

# --- Main Execution ---
main() {
    echo "--------------------------------------------------------"
    echo "Installing base system with pacstrap..."
    echo "This will download and install all the core packages."
    echo "This process can take a significant amount of time depending on"
    echo "your internet connection and the mirror speed."
    echo "--------------------------------------------------------"
    
    # The pacstrap command installs packages to the specified new root directory.
    # The "${BASE_PACKAGES[@]}" syntax expands the array into a space-separated list.
    pacstrap /mnt "${BASE_PACKAGES[@]}"

    echo ""
    echo "--------------------------------------------------------"
    echo "✅ Base system installation complete."
    echo "The next critical step is to generate the fstab file,"
    echo "which tells your new system where its partitions are."
    echo "--------------------------------------------------------"
}

# Run the main function
main