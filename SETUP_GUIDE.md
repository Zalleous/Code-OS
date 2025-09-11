# Arch Linux Installation Scripts

This repository contains a collection of scripts to automate the installation and configuration of Arch Linux. The scripts are designed to be interactive, user-friendly, and handle common installation scenarios.

## Overview

The installation process is divided into several modular scripts, each handling a specific aspect of the system setup:

1. **network-setup.sh** - Network connectivity configuration
2. **disk-setup.sh** - Disk partitioning and filesystem setup
3. **base-setup.sh** - Base system installation
4. **locale-setup.sh** - Language, keyboard, and hostname configuration
5. **clock-setup.sh** - Timezone and system clock configuration
6. **grub-setup.sh** - Bootloader installation and configuration
7. **user-setup.sh** - User account creation and configuration

Additionally, there's a main installation script:
- **install-arch.sh** - Orchestrates the entire installation process

## Prerequisites

- Boot from an Arch Linux installation ISO
- UEFI system (recommended, BIOS support available)
- Internet connection capability (wired or wireless)
- Target disk with at least 20GB of space

## Quick Start

1. Boot from Arch Linux ISO
2. Clone or download these scripts
3. Run the main installation script as root:
   ```bash
   sudo ./install-arch.sh
   ```

Alternatively, you can run individual scripts manually:
```bash
chmod +x boot-setup/*.sh
./boot-setup/network-setup.sh
./boot-setup/disk-setup.sh
./boot-setup/base-setup.sh
./boot-setup/locale-setup.sh
./boot-setup/clock-setup.sh
./boot-setup/grub-setup.sh
./boot-setup/user-setup.sh
```

## Detailed Script Documentation

### 1. network-setup.sh

**Purpose**: Establishes internet connectivity required for package downloads.

**Features**:
- Automatic detection of network interfaces
- Support for both wired (Ethernet) and wireless connections
- Interactive Wi-Fi setup with network scanning
- Connection validation with multiple fallback hosts
- Retry logic with exponential backoff
- NetworkManager installation for target system
- Error handling and user-friendly prompts

**Usage**:
```bash
./boot-setup/network-setup.sh
```

**What it does**:
1. Checks for existing internet connection
2. Lists available network interfaces
3. Guides through connection setup (DHCP for wired, iwctl for wireless)
4. Validates connectivity
5. Installs NetworkManager for the target system

**Configuration**:
- `RETRY_ATTEMPTS`: Number of connection attempts (default: 3)
- `CONNECTION_TIMEOUT`: DHCP timeout in seconds (default: 10)

### 2. disk-setup.sh

**Purpose**: Prepares storage devices for Arch Linux installation.

**Features**:
- Interactive drive selection with detailed information
- Safe drive wiping with multiple confirmations
- GPT partition table creation for UEFI systems
- Automatic partition sizing with customizable options
- Support for multiple filesystem types
- Proper handling of NVMe and SATA drives
- Comprehensive error checking and validation

**Usage**:
```bash
./boot-setup/disk-setup.sh
```

**Partition Layout**:
1. **EFI System Partition**: 512MB (FAT32)
2. **Swap Partition**: Equal to RAM size (optional)
3. **Root Partition**: Remaining space (ext4 by default)

**Configuration**:
- `EFI_PARTITION_SIZE`: Size of EFI partition (default: "512M")
- `SWAP_PARTITION_SIZE`: Size of swap partition (default: RAM size, "0" to disable)
- `ROOT_PARTITION_SIZE`: Size of root partition (default: "0" for remaining space)
- `ROOT_FS_TYPE`: Root filesystem type (default: "ext4")

**What it does**:
1. Displays available drives with detailed information
2. Prompts for drive selection with safety confirmations
3. Wipes existing partition table and signatures
4. Creates new GPT partition table
5. Formats partitions with appropriate filesystems
6. Mounts filesystems to /mnt

### 3. base-setup.sh

**Purpose**: Installs the core Arch Linux system and essential packages.

**Features**:
- Automatic mirror ranking for faster downloads
- CPU-specific microcode detection and installation
- Interactive optional package selection
- Comprehensive package list with descriptions
- Automatic fstab generation
- Progress feedback and error handling

**Usage**:
```bash
./boot-setup/base-setup.sh
```

**Base Packages Installed**:
- `base`, `linux`, `linux-firmware` - Core system
- `base-devel` - Development tools
- `networkmanager` - Network management
- `nano`, `vim` - Text editors
- `git` - Version control
- `sudo` - Privilege escalation
- `grub`, `efibootmgr` - Bootloader components
- `man-db`, `man-pages` - Documentation

**Optional Packages**:
- CPU microcode (`intel-ucode` or `amd-ucode`)
- Development tools (`linux-headers`, `dkms`)
- System utilities (`htop`, `neofetch`, `reflector`)
- Alternative shells (`zsh`, `fish`)

**What it does**:
1. Verifies mount points
2. Updates package mirrors
3. Detects CPU for microcode selection
4. Allows selection of optional packages
5. Installs packages with pacstrap
6. Generates fstab file

### 4. locale-setup.sh

**Purpose**: Configures system language, keyboard, and hostname.

**Features**:
- Support for common locales with custom option
- Keyboard layout configuration
- Hostname validation and setup
- Automatic locale generation
- Works in both live and chroot environments
- Comprehensive error checking

**Usage**:
```bash
./boot-setup/locale-setup.sh
```

**Configuration Options**:
- **Locale**: Common locales (en_US.UTF-8, de_DE.UTF-8, etc.) or custom
- **Keyboard**: Common layouts (US, UK, German, French, etc.) or custom
- **Hostname**: User-defined system name with validation

**What it does**:
1. Enables selected locale and generates locale files
2. Configures console keyboard layout
3. Sets system hostname and updates hosts file

### 5. clock-setup.sh

**Purpose**: Configures system timezone and hardware clock.

**Features**:
- Interactive timezone selection with region/city browsing
- Hardware clock synchronization
- Works in both live and chroot environments
- Automatic timezone detection and setup

**Usage**:
```bash
./boot-setup/clock-setup.sh
```

**Configuration Options**:
- **Timezone**: Interactive selection from zoneinfo database

**What it does**:
1. Sets system timezone
2. Syncs hardware clock with system time
3. Configures timezone for target system

### 6. grub-setup.sh

**Purpose**: Installs and configures the GRUB bootloader.

**Features**:
- Automatic UEFI/BIOS detection
- GRUB installation for both boot modes
- OS detection for dual-boot systems
- Essential service enablement
- Root password setup
- Initial ramdisk generation

**Usage**:
```bash
./boot-setup/grub-setup.sh
```

**Configuration**:
- `GRUB_TIMEOUT`: Boot menu timeout (default: 5 seconds)
- `GRUB_DEFAULT`: Default boot entry (default: 0)

**What it does**:
1. Detects boot mode (UEFI/BIOS)
2. Installs GRUB to appropriate location
3. Configures GRUB settings and appearance
4. Generates GRUB configuration file
5. Enables essential services (NetworkManager, time sync, fstrim)
6. Sets root password
7. Creates initial ramdisk

**Services Enabled**:
- `NetworkManager` - Network management
- `systemd-timesyncd` - Time synchronization
- `fstrim.timer` - SSD maintenance

### 7. user-setup.sh

**Purpose**: Creates and configures a user account with administrative privileges.

**Features**:
- Interactive user account creation
- Shell selection (bash, zsh, fish)
- Sudo configuration for wheel group
- User environment setup
- Optional AUR helper installation (yay or paru)
- Comprehensive user directory creation

**Usage**:
```bash
./boot-setup/user-setup.sh
```

**User Configuration**:
- Username validation and uniqueness checking
- Optional full name
- Shell selection with automatic installation
- Group membership: `wheel,audio,video,optical,storage`
- Home directory with standard folders

**What it does**:
1. Creates user account with home directory
2. Sets user password
3. Configures sudo access via wheel group
4. Sets up shell-specific configuration files
5. Creates standard user directories
6. Optionally installs AUR helper (yay or paru)

**AUR Helpers**:
- **yay**: Go-based AUR helper (recommended)
- **paru**: Rust-based AUR helper

### 8. install-arch.sh

**Purpose**: Main installation script that orchestrates the entire Arch Linux installation process.

**Features**:
- Automated execution of all installation scripts in correct order
- Environment validation and prerequisite checking
- Error handling and recovery guidance
- Progress tracking and user feedback
- Interactive confirmation at each step
- Colored output for better readability

**Usage**:
```bash
sudo ./install-arch.sh
```

**What it does**:
1. Validates installation environment
2. Checks for required scripts and permissions
3. Provides installation summary and confirmation
4. Executes each installation script in sequence
5. Handles errors and provides recovery instructions
6. Offers automatic reboot after completion

**Features**:
- **Step-by-step execution**: Pauses between each major step
- **Error recovery**: Provides clear instructions if a step fails
- **Environment checks**: Ensures running on Arch ISO as root
- **Automatic cleanup**: Offers to unmount and reboot after installation

## Error Handling

All scripts include comprehensive error handling:

- **Exit on error**: Scripts stop immediately if a critical command fails
- **Input validation**: User inputs are validated before processing
- **Retry logic**: Network operations include retry mechanisms
- **Rollback capabilities**: Some operations can be undone if they fail
- **Clear error messages**: Descriptive error messages help identify issues

## Customization

### Modifying Package Lists

Edit the package arrays in `base-setup.sh`:
```bash
BASE_PACKAGES=(
    # Add or remove packages here
)

OPTIONAL_PACKAGES=(
    # Add optional packages here
)
```

### Changing Partition Sizes

Modify variables in `disk-setup.sh`:
```bash
EFI_PARTITION_SIZE="512M"
SWAP_PARTITION_SIZE="4G"  # Or "0" to disable
ROOT_PARTITION_SIZE="0"   # 0 = use remaining space
```

### Adjusting GRUB Settings

Edit configuration in `grub-setup.sh`:
```bash
GRUB_TIMEOUT=10  # Boot menu timeout
GRUB_DEFAULT=0   # Default boot entry
```

## Troubleshooting

### Network Issues
- Ensure network interface is detected: `ip link show`
- Check if interface is up: `ip link set <interface> up`
- For Wi-Fi, verify iwd service is running: `systemctl status iwd`

### Disk Issues
- Verify disk is not mounted: `lsblk`
- Check for hardware issues: `dmesg | grep -i error`
- Ensure sufficient disk space (minimum 20GB recommended)

### Boot Issues
- Verify EFI partition is properly mounted
- Check GRUB installation: `efibootmgr -v`
- Ensure secure boot is disabled in BIOS/UEFI

### Package Installation Issues
- Update package database: `pacman -Sy`
- Check mirror status: `pacman-mirrors --status`
- Verify internet connectivity

## Security Considerations

- Root password is required and must be set securely
- User account is added to wheel group for sudo access
- Sudo is configured to require password authentication
- NetworkManager replaces temporary network configuration
- System services are enabled with minimal required permissions

## Post-Installation

After running all scripts:

1. **Exit chroot environment**: `exit`
2. **Unmount filesystems**: `umount -R /mnt`
3. **Reboot system**: `reboot`
4. **Remove installation media**
5. **Boot into new system**

### First Boot Checklist

- [ ] System boots successfully
- [ ] Network connectivity works
- [ ] User can log in
- [ ] Sudo access functions
- [ ] Time and timezone are correct
- [ ] Keyboard layout is correct

### Recommended Next Steps

1. **Update system**: `sudo pacman -Syu`
2. **Install additional software**: Use pacman or AUR helper
3. **Configure desktop environment**: Install DE/WM of choice
4. **Set up firewall**: `sudo ufw enable`
5. **Configure backup strategy**

## Contributing

To contribute improvements:

1. Test changes thoroughly in a virtual machine
2. Ensure backward compatibility
3. Update documentation for any new features
4. Follow existing code style and error handling patterns

## License

These scripts are provided as-is for educational and practical use. Please review and understand each script before running on your system.
