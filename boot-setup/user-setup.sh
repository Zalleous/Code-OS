#!/bin/bash

# --- Configuration ---
DEFAULT_SHELL="/bin/bash"
USER_GROUPS="wheel,audio,video,optical,storage"

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
    
    if [ ! -f /mnt/etc/fstab ]; then
        echo "❌ Error: Base system not installed. Please run base-setup.sh first."
        exit 1
    fi
    
    # Check if sudo is installed
    if ! arch-chroot /mnt which sudo >/dev/null 2>&1; then
        echo "❌ Error: sudo is not installed. Please run base-setup.sh first."
        exit 1
    fi
    
    echo "✅ Environment check passed."
}

# Create user account
create_user() {
    echo "========================================================="
    echo "                  User Account Creation"
    echo "========================================================="
    
    # Get username
    while true; do
        read -p "Enter username for the new user: " username
        
        # Validate username
        if [[ "$username" =~ ^[a-z_][a-z0-9_-]*$ ]] && [ ${#username} -le 32 ]; then
            # Check if user already exists
            if arch-chroot /mnt id "$username" >/dev/null 2>&1; then
                echo "❌ User '$username' already exists. Please choose a different username."
                continue
            fi
            break
        else
            echo "❌ Invalid username. Use only lowercase letters, numbers, underscores, and hyphens."
            echo "   Username must start with a letter or underscore and be max 32 characters."
        fi
    done
    
    # Get full name
    read -p "Enter full name for $username (optional): " fullname
    
    # Select shell
    echo ""
    echo "Available shells:"
    echo "  1. bash (default)"
    echo "  2. zsh"
    echo "  3. fish"
    echo "  4. Custom shell"
    echo ""
    
    while true; do
        read -p "Select shell (1-4): " shell_choice
        
        case "$shell_choice" in
            1) SELECTED_SHELL="/bin/bash"; break ;;
            2) 
                SELECTED_SHELL="/bin/zsh"
                # Check if zsh is installed
                if ! arch-chroot /mnt which zsh >/dev/null 2>&1; then
                    echo "Installing zsh..."
                    arch-chroot /mnt pacman -S --noconfirm zsh
                fi
                break
                ;;
            3) 
                SELECTED_SHELL="/usr/bin/fish"
                # Check if fish is installed
                if ! arch-chroot /mnt which fish >/dev/null 2>&1; then
                    echo "Installing fish..."
                    arch-chroot /mnt pacman -S --noconfirm fish
                fi
                break
                ;;
            4) 
                read -p "Enter shell path: " SELECTED_SHELL
                if ! arch-chroot /mnt test -x "$SELECTED_SHELL"; then
                    echo "❌ Shell '$SELECTED_SHELL' not found or not executable."
                    continue
                fi
                break
                ;;
            *) echo "❌ Invalid selection. Please try again." ;;
        esac
    done
    
    echo ""
    echo "Creating user account..."
    echo "  Username: $username"
    echo "  Full name: ${fullname:-Not specified}"
    echo "  Shell: $SELECTED_SHELL"
    echo "  Groups: $USER_GROUPS"
    
    # Create user with home directory
    local useradd_cmd="useradd -m -G $USER_GROUPS -s $SELECTED_SHELL"
    if [[ -n "$fullname" ]]; then
        useradd_cmd="$useradd_cmd -c \"$fullname\""
    fi
    useradd_cmd="$useradd_cmd $username"
    
    if ! arch-chroot /mnt bash -c "$useradd_cmd"; then
        echo "❌ Failed to create user account."
        exit 1
    fi
    
    echo "✅ User account created successfully."
}

# Set user password
set_user_password() {
    echo "========================================================="
    echo "                   User Password Setup"
    echo "========================================================="
    
    echo "Setting password for user '$username'..."
    while true; do
        if arch-chroot /mnt passwd "$username"; then
            echo "✅ User password set successfully."
            break
        else
            echo "❌ Failed to set user password. Please try again."
        fi
    done
}

# Configure sudo access
configure_sudo() {
    echo "========================================================="
    echo "                    Sudo Configuration"
    echo "========================================================="
    
    echo "Configuring sudo access for wheel group..."
    
    # Backup original sudoers file
    arch-chroot /mnt cp /etc/sudoers /etc/sudoers.backup
    
    # Enable wheel group in sudoers
    arch-chroot /mnt sed -i 's/^# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers
    
    # Test sudoers file
    if ! arch-chroot /mnt visudo -c; then
        echo "❌ Sudoers file validation failed. Restoring backup."
        arch-chroot /mnt cp /etc/sudoers.backup /etc/sudoers
        exit 1
    fi
    
    echo "✅ Sudo access configured for wheel group."
    echo "User '$username' can now use sudo for administrative tasks."
}

# Set up user environment
setup_user_environment() {
    echo "========================================================="
    echo "                User Environment Setup"
    echo "========================================================="
    
    # Create common directories
    echo "Creating user directories..."
    arch-chroot /mnt sudo -u "$username" mkdir -p "/home/$username/"{Desktop,Documents,Downloads,Music,Pictures,Videos}
    
    # Set up shell-specific configurations
    case "$SELECTED_SHELL" in
        "/bin/bash")
            echo "Setting up bash configuration..."
            cat > "/mnt/home/$username/.bashrc" << 'EOF'
# ~/.bashrc

# If not running interactively, don't do anything
[[ $- != *i* ]] && return

# Aliases
alias ls='ls --color=auto'
alias ll='ls -alF'
alias la='ls -A'
alias l='ls -CF'
alias grep='grep --color=auto'

# History settings
HISTCONTROL=ignoreboth
HISTSIZE=1000
HISTFILESIZE=2000

# Enable programmable completion features
if ! shopt -oq posix; then
  if [ -f /usr/share/bash-completion/bash_completion ]; then
    . /usr/share/bash-completion/bash_completion
  elif [ -f /etc/bash_completion ]; then
    . /etc/bash_completion
  fi
fi

# Custom prompt
PS1='\[\033[01;32m\]\u@\h\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\$ '
EOF
            ;;
        "/bin/zsh")
            echo "Setting up zsh configuration..."
            cat > "/mnt/home/$username/.zshrc" << 'EOF'
# ~/.zshrc

# History settings
HISTFILE=~/.histfile
HISTSIZE=1000
SAVEHIST=1000
setopt appendhistory

# Completion
autoload -U compinit
compinit

# Aliases
alias ls='ls --color=auto'
alias ll='ls -alF'
alias la='ls -A'
alias l='ls -CF'
alias grep='grep --color=auto'

# Prompt
autoload -U promptinit
promptinit
prompt adam1
EOF
            ;;
        "/usr/bin/fish")
            echo "Setting up fish configuration..."
            arch-chroot /mnt sudo -u "$username" mkdir -p "/home/$username/.config/fish"
            cat > "/mnt/home/$username/.config/fish/config.fish" << 'EOF'
# ~/.config/fish/config.fish

# Aliases
alias ll='ls -alF'
alias la='ls -A'
alias l='ls -CF'

# Set greeting
set fish_greeting "Welcome to fish, the friendly interactive shell"
EOF
            ;;
    esac
    
    # Set proper ownership
    arch-chroot /mnt chown -R "$username:$username" "/home/$username"
    
    echo "✅ User environment configured."
}

# Install AUR helper (optional)
install_aur_helper() {
    echo "========================================================="
    echo "                   AUR Helper Installation"
    echo "========================================================="
    
    echo "AUR (Arch User Repository) helpers make it easier to install"
    echo "packages from the AUR. Popular options include:"
    echo "  1. yay (recommended)"
    echo "  2. paru"
    echo "  3. Skip AUR helper installation"
    echo ""
    
    while true; do
        read -p "Select AUR helper (1-3): " aur_choice
        
        case "$aur_choice" in
            1)
                echo "Installing yay..."
                install_yay
                break
                ;;
            2)
                echo "Installing paru..."
                install_paru
                break
                ;;
            3)
                echo "Skipping AUR helper installation."
                break
                ;;
            *) echo "❌ Invalid selection. Please try again." ;;
        esac
    done
}

# Install yay AUR helper
install_yay() {
    # Install dependencies
    arch-chroot /mnt pacman -S --needed --noconfirm git base-devel
    
    # Clone and build yay as the user
    arch-chroot /mnt sudo -u "$username" bash -c "
        cd /home/$username
        git clone https://aur.archlinux.org/yay.git
        cd yay
        makepkg -si --noconfirm
        cd ..
        rm -rf yay
    "
    
    echo "✅ yay installed successfully."
}

# Install paru AUR helper
install_paru() {
    # Install dependencies
    arch-chroot /mnt pacman -S --needed --noconfirm git base-devel rust
    
    # Clone and build paru as the user
    arch-chroot /mnt sudo -u "$username" bash -c "
        cd /home/$username
        git clone https://aur.archlinux.org/paru.git
        cd paru
        makepkg -si --noconfirm
        cd ..
        rm -rf paru
    "
    
    echo "✅ paru installed successfully."
}

# --- Main Execution ---
main() {
    echo "========================================================="
    echo "            Arch Linux User Account Setup"
    echo "========================================================="
    echo "This script will:"
    echo "  1. Create a new user account"
    echo "  2. Set user password"
    echo "  3. Configure sudo access"
    echo "  4. Set up user environment"
    echo "  5. Optionally install an AUR helper"
    echo ""
    
    check_environment
    
    create_user
    set_user_password
    configure_sudo
    setup_user_environment
    install_aur_helper
    
    echo ""
    echo "========================================================="
    echo "✅ User account setup completed successfully!"
    echo "========================================================="
    echo "User account summary:"
    echo "  Username: $username"
    echo "  Shell: $SELECTED_SHELL"
    echo "  Groups: $USER_GROUPS"
    echo "  Home directory: /home/$username"
    echo ""
    echo "The user '$username' has been created and configured with:"
    echo "  ✅ Password authentication"
    echo "  ✅ Sudo privileges (via wheel group)"
    echo "  ✅ Basic shell configuration"
    echo "  ✅ Standard user directories"
    echo ""
    echo "🎉 Arch Linux installation is now complete!"
    echo ""
    echo "Final steps:"
    echo "  1. Exit the chroot environment: exit"
    echo "  2. Unmount filesystems: umount -R /mnt"
    echo "  3. Reboot: reboot"
    echo "  4. Remove installation media"
    echo "  5. Boot into your new Arch Linux system"
    echo ""
    echo "You can log in as '$username' or 'root' after reboot."
    echo "========================================================="
}

# Run the main function
main
