# Goals
Our goal is to make an operating system oriented for coding, with all our prefered configuration all ready to go from the installation.

# What we want to include

# Focused Arch Linux Coding Distribution Package List

## CORE SYSTEM (Essential for Boot/Function)

### Boot and Hardware
```bash
grub
efibootmgr
os-prober
intel-ucode
amd-ucode
```

### File Systems
```bash
dosfstools          # FAT32 support
ntfs-3g            # NTFS support
btrfs-progs        # Btrfs support
gvfs               # Virtual file system
gvfs-mtp           # Mobile device support
udisks2            # Disk management
```

### Network
```bash
networkmanager
network-manager-applet
iwd
openssh
wget
curl
```

### Graphics
```bash
# Wayland
wayland
wayland-protocols
xdg-desktop-portal
xdg-desktop-portal-hyprland

# X11 compatibility
xorg-xwayland

# Drivers
mesa
vulkan-intel
vulkan-radeon
nvidia              # Include all GPU drivers
nvidia-utils
lib32-mesa
lib32-vulkan-intel
lib32-vulkan-radeon
```

### Audio
```bash
pipewire
pipewire-alsa
pipewire-pulse
pipewire-jack
wireplumber
alsa-utils
pavucontrol
```

## SHELL AND TERMINAL

```bash
zsh
zsh-completions
zsh-autosuggestions
zsh-syntax-highlighting
alacritty           # Your chosen terminal
starship            # Modern prompt for Oh My Zsh
```

## DESKTOP ENVIRONMENTS

### Hyprland (Primary)
```bash
hyprland
waybar
wofi
mako
hyprpaper
grim
slurp
wl-clipboard
polkit-gnome
```

### LXQt (Lightweight Backup)
```bash
lxqt
openbox
sddm
```

### File Manager
```bash
dolphin            # Your chosen file manager
```

## DEVELOPMENT ENVIRONMENT

### Editors
```bash
neovim             # Your choice
code               # VS Code
```

### Version Control
```bash
git
```

### Programming Languages
```bash
# Python
python
python-pip

# Node.js
nodejs
npm

# Rust
rust
rustup

# Java/Kotlin
jdk-openjdk
kotlin

# C/C++
gcc
clang
cmake
ninja
gdb
```

### Development Tools
```bash
base-devel         # Build tools (make, etc.)
docker             # Your container choice
docker-compose
```

### Database CLI Tools
```bash
postgresql         # PostgreSQL client
mysql             # MySQL client
sqlite            # SQLite
redis             # Redis CLI
```

## APPLICATIONS

### Web Browsers
```bash
firefox           # Web development
tor-browser       # Privacy navigation
```

### Communication
```bash
discord           # Your choice
```

### Media Viewers
```bash
feh               # Image viewer
mpv               # Video player
```

## FONTS

```bash
# Essential fonts
ttf-dejavu
ttf-liberation
noto-fonts
noto-fonts-emoji

# Programming fonts
ttf-jetbrains-mono
ttf-fira-code

# Font rendering
fontconfig
freetype2
```

## SYSTEM UTILITIES

### Essential Utils
```bash
htop              # Process monitor
neofetch          # System info
tree              # Directory tree
unzip             # Archive extraction
p7zip             # 7zip support
rsync             # File sync
```

### Hardware Support
```bash
# Bluetooth
bluez
bluez-utils

# Printing (minimal)
cups

# Power management
tlp
```

## MULTIMEDIA CODECS (Minimal)

```bash
gst-plugins-base
gst-plugins-good
gst-plugins-bad
gst-plugins-ugly
ffmpeg
```

## ESSENTIAL AUR PACKAGES

### Development
```bash
# Install with yay after base system
visual-studio-code-bin     # VS Code binary
oh-my-zsh-git             # Zsh framework
```

### Applications
```bash
tor-browser               # Tor browser
discord                   # Discord app
```