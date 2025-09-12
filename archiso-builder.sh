#!/usr/bin/env bash
# Intelligent Arch Linux ISO Builder with Install Scripts Support
# Zero-argument script that auto-detects what needs to be done

set -euo pipefail

# Fixed configuration - consistent folder for .gitignore
readonly BUILD_DIR="./archiso-build"           # Always same name for .gitignore
readonly PROFILES_DIR="${BUILD_DIR}/profiles"
readonly OUTPUT_DIR="${BUILD_DIR}/output"
readonly CACHE_DIR="${BUILD_DIR}/cache"
readonly LOGS_DIR="${BUILD_DIR}/logs"

# Fixed output filename
readonly ISO_NAME="custom-arch.iso"
readonly ISO_FILE="${OUTPUT_DIR}/${ISO_NAME}"

# Default build profile
readonly DEFAULT_PROFILE="releng"

# tmpfs settings (optimized for 16GB RAM)
readonly TMPFS_BASE="/tmp/archiso-build"
readonly TMPFS_WORK="${TMPFS_BASE}/work"
readonly TMPFS_CACHE="${TMPFS_BASE}/cache"
readonly TMPFS_SIZE="6G"
readonly CACHE_SIZE="3G"

# Build settings
readonly MAX_JOBS="$(nproc)"
readonly COMPRESSION="lz4"  # Fast compression for testing

# Enable debug logging for development
LOG_LEVEL="${LOG_LEVEL:-DEBUG}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# Logging functions
log_info() { echo -e "${GREEN}[INFO]${NC} $*"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*"; }
log_debug() { [[ "$LOG_LEVEL" == "DEBUG" ]] && echo -e "${BLUE}[DEBUG]${NC} $*"; }
log_step() { echo -e "${CYAN}${BOLD}=== $* ===${NC}"; }

# Cleanup function
cleanup() {
    log_debug "Cleaning up tmpfs mounts..."
    
    if mountpoint -q "$TMPFS_WORK" 2>/dev/null; then
        sudo umount "$TMPFS_WORK" || log_warn "Failed to unmount $TMPFS_WORK"
    fi
    
    if mountpoint -q "$TMPFS_CACHE" 2>/dev/null; then
        sudo umount "$TMPFS_CACHE" || log_warn "Failed to unmount $TMPFS_CACHE"
    fi
    
    [[ -d "$TMPFS_BASE" ]] && sudo rm -rf "$TMPFS_BASE"
}

trap cleanup EXIT

# Check if setup is complete
is_setup_complete() {
    [[ -d "$BUILD_DIR" ]] && 
    [[ -d "$PROFILES_DIR" ]] && 
    [[ -d "$PROFILES_DIR/$DEFAULT_PROFILE" ]] &&
    [[ -d "$CACHE_DIR" ]] &&
    [[ -d "$OUTPUT_DIR" ]]
}

# Check if ISO exists
iso_exists() {
    [[ -f "$ISO_FILE" ]]
}

# Get ISO age in minutes
get_iso_age() {
    if [[ -f "$ISO_FILE" ]]; then
        local iso_time=$(stat -c %Y "$ISO_FILE" 2>/dev/null || stat -f %m "$ISO_FILE" 2>/dev/null)
        local now_time=$(date +%s)
        echo $(( (now_time - iso_time) / 60 ))
    else
        echo "999999"
    fi
}

# Get ISO size
get_iso_size() {
    if [[ -f "$ISO_FILE" ]]; then
        local size_bytes=$(stat -c%s "$ISO_FILE" 2>/dev/null || stat -f%z "$ISO_FILE" 2>/dev/null)
        echo "$((size_bytes / 1024 / 1024))MB"
    else
        echo "N/A"
    fi
}

# Check system requirements
check_requirements() {
    log_info "Checking system requirements..."
    
    # Check RAM
    local ram_gb=$(free -g | awk '/^Mem:/{print $2}')
    if [[ $ram_gb -lt 12 ]]; then
        log_error "Insufficient RAM: ${ram_gb}GB (need at least 12GB)"
        return 1
    fi
    log_info "RAM: ${ram_gb}GB ✓"
    
    # Check required packages
    local packages=("archiso" "squashfs-tools")
    local missing_packages=()
    
    for pkg in "${packages[@]}"; do
        if ! pacman -Q "$pkg" &>/dev/null; then
            missing_packages+=("$pkg")
        fi
    done
    
    if [[ ${#missing_packages[@]} -gt 0 ]]; then
        log_info "Installing required packages: ${missing_packages[*]}"
        if ! sudo pacman -S --noconfirm "${missing_packages[@]}"; then
            log_error "Failed to install required packages"
            return 1
        fi
    fi
    
    log_info "System requirements satisfied ✓"
    return 0
}

# Setup tmpfs mounts
setup_tmpfs() {
    log_debug "Setting up tmpfs mounts..."
    
    # Create directories
    sudo mkdir -p "$TMPFS_WORK" "$TMPFS_CACHE"
    
    # Mount tmpfs if not already mounted
    if ! mountpoint -q "$TMPFS_WORK"; then
        sudo mount -t tmpfs -o "size=$TMPFS_SIZE,noatime" tmpfs "$TMPFS_WORK"
        log_debug "Mounted tmpfs work directory: $TMPFS_SIZE"
    fi
    
    if ! mountpoint -q "$TMPFS_CACHE"; then
        sudo mount -t tmpfs -o "size=$CACHE_SIZE,noatime" tmpfs "$TMPFS_CACHE"
        log_debug "Mounted tmpfs cache directory: $CACHE_SIZE"
    fi
    
    # Set ownership
    sudo chown -R "$USER:$USER" "$TMPFS_BASE"
}

# Download archiso profiles
download_profiles() {
    log_info "Setting up archiso profiles..."
    
    mkdir -p "$PROFILES_DIR"
    
    # Use system profiles as base
    if [[ -d /usr/share/archiso/configs ]]; then
        cp -r /usr/share/archiso/configs/* "$PROFILES_DIR/"
        log_info "Copied system archiso profiles ✓"
    fi
    
    # Try to download latest (non-blocking)
    local temp_dir="/tmp/archiso-latest"
    if timeout 30 git clone --depth 1 https://gitlab.archlinux.org/archlinux/archiso.git "$temp_dir" 2>/dev/null; then
        cp -r "$temp_dir/configs/"* "$PROFILES_DIR/" 2>/dev/null || true
        rm -rf "$temp_dir"
        log_info "Updated with latest profiles ✓"
    else
        log_debug "Using system profiles (latest download failed/timeout)"
    fi
    
    # Verify default profile exists
    if [[ ! -d "$PROFILES_DIR/$DEFAULT_PROFILE" ]]; then
        log_error "Default profile '$DEFAULT_PROFILE' not found!"
        log_info "Available profiles: $(ls "$PROFILES_DIR" 2>/dev/null | tr '\n' ' ')"
        return 1
    fi
    
    return 0
}

# Copy user scripts into ISO
copy_install_scripts() {
    local profile_dir="${PROFILES_DIR}/${DEFAULT_PROFILE}"
    local airootfs_dir="${profile_dir}/airootfs"
    local target_scripts_dir="${airootfs_dir}/root/install-scripts"
    
    log_debug "Profile dir: $profile_dir"
    log_debug "Airootfs dir: $airootfs_dir"
    log_debug "Target scripts dir: $target_scripts_dir"
    
    # Check if source scripts exist
    if [[ -d "./install-scripts" ]]; then
        log_info "Found install scripts folder: ./install-scripts"
        
        # List source scripts
        local source_scripts=$(ls ./install-scripts 2>/dev/null | tr '\n' ' ' || echo "none")
        log_info "Source scripts found: $source_scripts"
        
        # Verify profile directory exists
        if [[ ! -d "$airootfs_dir/root" ]]; then
            log_error "Target directory doesn't exist: $airootfs_dir/root"
            log_error "Profile directory structure may be incorrect"
            return 1
        fi
        
        # Create target directory
        log_debug "Creating target directory: $target_scripts_dir"
        mkdir -p "$target_scripts_dir"
        
        if [[ ! -d "$target_scripts_dir" ]]; then
            log_error "Failed to create target directory: $target_scripts_dir"
            return 1
        fi
        
        # Copy all scripts and preserve permissions
        log_info "Copying scripts to ISO..."
        if cp -r ./install-scripts/* "$target_scripts_dir/" 2>/dev/null; then
            log_info "Scripts copied successfully ✓"
        else
            log_error "Failed to copy scripts to $target_scripts_dir"
            return 1
        fi
        
        # Ensure scripts are executable
        find "$target_scripts_dir" -type f -name "*.sh" -exec chmod +x {} \;
        
        # Verify copy worked
        if [[ -d "$target_scripts_dir" ]]; then
            local copied_scripts=$(ls "$target_scripts_dir" 2>/dev/null | tr '\n' ' ' || echo "none")
            log_info "Copied scripts verified: $copied_scripts"
            log_debug "Target location in ISO: /root/install-scripts/"
        else
            log_error "Copy verification failed - target directory doesn't exist"
            return 1
        fi
        
        return 0
    else
        log_debug "No ./install-scripts/ folder found, skipping script copy"
        return 0
    fi
}

# Setup auto-execution of scripts
setup_auto_execution() {
    local profile_dir="${PROFILES_DIR}/${DEFAULT_PROFILE}"
    local airootfs_dir="${profile_dir}/airootfs"
    local root_dir="${airootfs_dir}/root"
    local auto_script="${root_dir}/.automated_script.sh"
    
    log_debug "Setting up auto-execution in: $auto_script"
    
    # Only setup if we have scripts to run
    if [[ -d "./install-scripts" ]] && [[ -n "$(ls ./install-scripts 2>/dev/null)" ]]; then
        log_info "Setting up auto-execution on boot..."
        
        # Verify the target directory exists
        if [[ ! -d "$root_dir" ]]; then
            log_error "Target root directory doesn't exist: $root_dir"
            return 1
        fi
        
        # Check if automated script already exists
        if [[ -f "$auto_script" ]]; then
            log_info "Found existing .automated_script.sh, appending custom commands"
            
            # Check if our custom lines are already there
            if grep -q "chmod +x ./install-scripts/install-arch.sh" "$auto_script"; then
                log_info "Custom commands already present in automated script"
                return 0
            fi
            
            # Append our custom lines to the existing script
            log_debug "Appending custom commands to existing automated script"
            cat >> "$auto_script" << 'EOF'

# Custom install scripts execution
if [[ $(tty) == "/dev/tty1" ]]; then
	chmod +x ./install-scripts/install-arch.sh
	./install-scripts/install-arch.sh
fi
EOF
        else
            log_info "No existing .automated_script.sh found, creating complete script"
            
            # Create complete script with archiso functionality + our custom parts
            cat > "$auto_script" << 'EOF'
#!/usr/bin/env bash
script_cmdline() {
    local param
    for param in $(</proc/cmdline); do
        case "${param}" in
            script=*)
                echo "${param#*=}"
                return 0
                ;;
        esac
    done
}
automated_script() {
    local script rt
    script="$(script_cmdline)"
    if [[ -n "${script}" && ! -x /tmp/startup_script ]]; then
        if [[ "${script}" =~ ^((http|https|ftp|tftp)://) ]]; then
            # there's no synchronization for network availability before executing this script
            printf '%s: waiting for network-online.target\n' "$0"
            until systemctl --quiet is-active network-online.target; do
                sleep 1
            done
            printf '%s: downloading %s\n' "$0" "${script}"
            curl "${script}" --location --retry-connrefused --retry 10 --fail -s -o /tmp/startup_script
            rt=$?
        else
            cp "${script}" /tmp/startup_script
            rt=$?
        fi
        if [[ ${rt} -eq 0 ]]; then
            chmod +x /tmp/startup_script
            printf '%s: executing automated script\n' "$0"
            # note that script is executed when other services (like pacman-init) may be still in progress, please
            # synchronize to "systemctl is-system-running --wait" when your script depends on other services
            /tmp/startup_script
        fi
    fi
}

# Standard archiso automated script functionality
automated_script

# Custom install scripts execution
if [[ $(tty) == "/dev/tty1" ]]; then
	chmod +x ./install-scripts/install-arch.sh
	./install-scripts/install-arch.sh
fi
EOF
        fi
        
        # Make script executable
        chmod +x "$auto_script"
        
        # Verify the script was created/modified
        if [[ -f "$auto_script" ]]; then
            log_info "Auto-execution script configured ✓"
            
            # Verify our custom lines are in the script
            if grep -q "chmod +x ./install-scripts/install-arch.sh" "$auto_script"; then
                log_info "Custom commands verified in automated script ✓"
            else
                log_error "Custom commands not found in automated script!"
                return 1
            fi
        else
            log_error "Failed to create automated script!"
            return 1
        fi
        
        # Ensure the script is called on login (if not already set up)
        local zlogin_file="${root_dir}/.zlogin"
        log_debug "Checking .zlogin file: $zlogin_file"
        
        # Only add to .zlogin if it doesn't already contain the automated script call
        if [[ ! -f "$zlogin_file" ]] || ! grep -q ".automated_script.sh" "$zlogin_file"; then
            log_debug "Adding automated script call to .zlogin"
            echo "/root/.automated_script.sh" >> "$zlogin_file"
        else
            log_debug "Automated script call already in .zlogin"
        fi
        
        log_info "Auto-execution setup completed ✓"
        log_debug "Scripts will auto-run on tty1 boot (preserving archiso functionality)"
        
        return 0
    else
        log_debug "No install scripts found, skipping auto-execution setup"
        return 0
    fi
}

# Verify install scripts integration
verify_install_scripts() {
    local profile_dir="${PROFILES_DIR}/${DEFAULT_PROFILE}"
    local airootfs_dir="${profile_dir}/airootfs"
    local root_dir="${airootfs_dir}/root"
    local scripts_dir="${root_dir}/install-scripts"
    local auto_script="${root_dir}/.automated_script.sh"
    
    log_info "Verifying install scripts integration..."
    
    # Check if install-scripts folder exists in ISO
    if [[ -d "$scripts_dir" ]]; then
        local script_count=$(ls "$scripts_dir" 2>/dev/null | wc -l)
        log_info "✓ Install scripts folder exists with $script_count files"
        
        # List the scripts
        if [[ $script_count -gt 0 ]]; then
            log_info "  Scripts: $(ls "$scripts_dir" | tr '\n' ' ')"
        fi
    else
        log_error "✗ Install scripts folder missing in ISO"
        return 1
    fi
    
    # Check if automated script exists and contains our commands
    if [[ -f "$auto_script" ]]; then
        log_info "✓ .automated_script.sh exists"
        
        if grep -q "chmod +x ./install-scripts/install-arch.sh" "$auto_script"; then
            log_info "✓ Custom commands found in automated script"
        else
            log_error "✗ Custom commands missing from automated script"
            log_debug "Automated script content:"
            cat "$auto_script" | while read line; do log_debug "  $line"; done
            return 1
        fi
    else
        log_error "✗ .automated_script.sh missing"
        return 1
    fi
    
    log_info "Install scripts integration verified ✓"
    return 0
}

# Optimize profile for fast builds
optimize_profile() {
    local profile_dir="${PROFILES_DIR}/${DEFAULT_PROFILE}"
    
    log_debug "Optimizing profile: $DEFAULT_PROFILE"
    log_debug "Profile directory: $profile_dir"
    
    # Verify profile directory exists
    if [[ ! -d "$profile_dir" ]]; then
        log_error "Profile directory not found: $profile_dir"
        return 1
    fi
    
    # Create optimized pacman.conf
    local pacman_conf="${profile_dir}/pacman.conf"
    if [[ -f "$pacman_conf" ]]; then
        log_debug "Updating pacman.conf: $pacman_conf"
        # Remove existing optimizations and add new ones
        sed -i '/# Build optimizations/,$d' "$pacman_conf"
        cat >> "$pacman_conf" << EOF

# Build optimizations
CacheDir = $CACHE_DIR/pkg
CacheDir = $TMPFS_CACHE
ParallelDownloads = 10
EOF
        log_debug "pacman.conf updated with build optimizations"
    else
        log_warn "pacman.conf not found: $pacman_conf"
    fi
    
    # Update profiledef.sh for fast compression
    local profiledef="${profile_dir}/profiledef.sh"
    if [[ -f "$profiledef" ]]; then
        log_debug "Updating profiledef.sh: $profiledef"
        # Add fast compression options if not present
        if ! grep -q "airootfs_image_tool_options" "$profiledef"; then
            echo 'airootfs_image_tool_options=("-comp" "lz4" "-Xhc" "-b" "1M")' >> "$profiledef"
            log_debug "Added fast compression options to profiledef.sh"
        else
            log_debug "Fast compression options already present in profiledef.sh"
        fi
    else
        log_warn "profiledef.sh not found: $profiledef"
    fi
    
    # Copy user scripts and setup auto-execution
    log_debug "Processing user install scripts..."
    if copy_install_scripts; then
        log_debug "Install scripts copied successfully"
    else
        log_error "Failed to copy install scripts"
        return 1
    fi
    
    if setup_auto_execution; then
        log_debug "Auto-execution setup completed successfully"
    else
        log_error "Failed to setup auto-execution"
        return 1
    fi
    
    return 0
}

# Perform initial setup
do_setup() {
    log_step "Setting up build environment"
    
    # Create directories
    mkdir -p "$BUILD_DIR" "$PROFILES_DIR" "$OUTPUT_DIR" "$CACHE_DIR" "$LOGS_DIR"
    
    if ! check_requirements; then
        return 1
    fi
    
    if ! download_profiles; then
        return 1
    fi
    
    # Create .gitignore if in git repo
    if [[ -d .git ]] && [[ ! -f .gitignore ]] || ! grep -q "archiso-build" .gitignore 2>/dev/null; then
        echo "archiso-build/" >> .gitignore
        log_info "Added 'archiso-build/' to .gitignore ✓"
    fi
    
    log_info "Setup completed ✓"
    echo
    return 0
}

# Build the ISO
do_build() {
    local clean_build="${1:-false}"
    local build_type="incremental"
    
    if [[ "$clean_build" == "true" ]]; then
        build_type="clean"
        log_step "Starting clean build"
        # Clean everything
        rm -rf "$TMPFS_WORK"/* "$TMPFS_CACHE"/* 2>/dev/null || true
        rm -rf "$CACHE_DIR"/* 2>/dev/null || true
    else
        log_step "Starting incremental build"
    fi
    
    # Setup
    setup_tmpfs
    log_info "Optimizing profile and copying install scripts..."
    if ! optimize_profile; then
        log_error "Profile optimization failed"
        return 1
    fi
    
    # Verify the integration worked
    if [[ -d "./install-scripts" ]]; then
        verify_install_scripts
    fi
    
    mkdir -p "$CACHE_DIR/pkg"
    
    # Build command
    local build_cmd=(
        "mkarchiso"
        "-v"
        "-w" "$TMPFS_WORK"
        "-o" "$OUTPUT_DIR"
        "${PROFILES_DIR}/${DEFAULT_PROFILE}"
    )
    
    log_info "Build command: ${build_cmd[*]}"
    log_info "Profile: $DEFAULT_PROFILE"
    log_info "Output: $ISO_FILE"
    echo
    
    # Start build with timing
    local start_time=$(date +%s)
    
    if sudo "${build_cmd[@]}"; then
        local end_time=$(date +%s)
        local duration=$((end_time - start_time))
        
        # Find and rename the built ISO
        local built_iso
        built_iso=$(find "$OUTPUT_DIR" -name "archlinux-*.iso" -type f | head -1)
        
        if [[ -n "$built_iso" && -f "$built_iso" ]]; then
            # Rename to consistent name
            if [[ "$built_iso" != "$ISO_FILE" ]]; then
                mv "$built_iso" "$ISO_FILE"
            fi
            
            local size_mb=$(($(stat -c%s "$ISO_FILE") / 1024 / 1024))
            
            echo
            log_step "Build completed successfully!"
            log_info "Build type: $build_type"
            log_info "Time: $((duration / 60))m $((duration % 60))s"
            log_info "Size: ${size_mb}MB"
            log_info "File: $ISO_FILE"
            
            # Generate checksum
            sha256sum "$ISO_FILE" > "${ISO_FILE}.sha256"
            log_info "Checksum: ${ISO_FILE}.sha256"
            
            echo
            log_info "Your ISO is ready! You can find it at:"
            log_info "  $(realpath "$ISO_FILE")"
            return 0
        else
            log_error "ISO file not found after build"
            return 1
        fi
    else
        log_error "Build failed"
        return 1
    fi
}

# Interactive prompt for rebuild decision
prompt_rebuild() {
    local age_min=$(get_iso_age)
    local size=$(get_iso_size)
    local age_text=""
    
    if [[ $age_min -lt 60 ]]; then
        age_text="${age_min} minutes ago"
    elif [[ $age_min -lt 1440 ]]; then
        age_text="$((age_min / 60)) hours ago"  
    else
        age_text="$((age_min / 1440)) days ago"
    fi
    
    echo
    log_info "Existing ISO found:"
    log_info "  File: $ISO_FILE"
    log_info "  Size: $size"
    log_info "  Built: $age_text"
    echo
    
    echo "What would you like to do?"
    echo "  1) Incremental rebuild (reuse cache, faster)"
    echo "  2) Clean rebuild (fresh build, slower)"
    echo "  3) Exit (use existing ISO)"
    echo
    
    while true; do
        read -p "Choose [1-3]: " -n 1 -r choice
        echo
        
        case $choice in
            1)
                log_info "Starting incremental rebuild..."
                if do_build false; then
                    return 0
                else
                    return 1
                fi
                ;;
            2)
                log_info "Starting clean rebuild..."
                if do_build true; then
                    return 0
                else
                    return 1
                fi
                ;;
            3)
                log_info "Using existing ISO"
                log_info "Location: $(realpath "$ISO_FILE")"
                return 0
                ;;
            *)
                echo "Invalid choice. Please select 1, 2, or 3."
                ;;
        esac
    done
}

# Main logic
main() {
    echo -e "${CYAN}${BOLD}"
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║              Intelligent Arch ISO Builder                   ║"
    echo "║                  Zero-argument automation                    ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    
    # Check current state and decide what to do
    if ! is_setup_complete; then
        log_info "Build environment not found, setting up..."
        do_setup
    else
        log_info "Build environment found ✓"
    fi
    
    if iso_exists; then
        log_info "Existing ISO detected"
        
        # Check for install scripts
        if [[ -d "./install-scripts" ]] && [[ -n "$(ls ./install-scripts 2>/dev/null)" ]]; then
            log_info "Install scripts found: $(ls ./install-scripts | tr '\n' ' ')"
        fi
        
        if prompt_rebuild; then
            log_debug "Operation completed successfully"
            return 0
        else
            log_error "Operation failed"
            return 1
        fi
    else
        log_info "No existing ISO found, building new one..."
        
        # Check for install scripts
        if [[ -d "./install-scripts" ]] && [[ -n "$(ls ./install-scripts 2>/dev/null)" ]]; then
            log_info "Install scripts found: $(ls ./install-scripts | tr '\n' ' ')"
            log_info "Scripts will auto-execute on ISO boot ✓"
        else
            log_info "No install scripts found (create ./install-scripts/ folder to add custom scripts)"
        fi
        
        echo
        if do_build false; then
            log_debug "Build completed successfully"
            return 0
        else
            log_error "Build failed"
            return 1
        fi
    fi
}

# Handle command line arguments (optional)
if [[ $# -eq 0 ]]; then
    # Zero arguments - intelligent mode
    if main; then
        exit 0
    else
        exit 1
    fi
else
    case "${1:-}" in
        setup)
            do_setup
            exit $?
            ;;
        build)
            if ! is_setup_complete; then
                do_setup
            fi
            if do_build false; then
                exit 0
            else
                exit 1
            fi
            ;;
        clean)
            if ! is_setup_complete; then
                do_setup  
            fi
            if do_build true; then
                exit 0
            else
                exit 1
            fi
            ;;
        rebuild)
            if ! is_setup_complete; then
                log_error "Run setup first or just run './archiso-builder.sh'"
                exit 1
            fi
            if iso_exists; then
                if prompt_rebuild; then
                    exit 0
                else
                    exit 1
                fi
            else
                if do_build false; then
                    exit 0
                else
                    exit 1
                fi
            fi
            ;;
        help|--help|-h)
            echo "Intelligent Arch Linux ISO Builder"
            echo
            echo "USAGE:"
            echo "  $0                    # Intelligent mode (recommended)"
            echo "  $0 setup              # Setup only"
            echo "  $0 build              # Build (setup if needed)"
            echo "  $0 clean              # Clean build"
            echo "  $0 rebuild            # Rebuild existing ISO"
            echo
            echo "INTELLIGENT MODE:"
            echo "  Just run './archiso-builder.sh' and it will:"
            echo "  - Auto-setup if needed"
            echo "  - Build ISO if none exists"  
            echo "  - Prompt for rebuild if ISO exists"
            echo
            echo "INSTALL SCRIPTS:"
            echo "  - Create ./install-scripts/ folder with your scripts"
            echo "  - Scripts will auto-execute on ISO boot (tty1)"
            echo "  - Main script should be: install-arch.sh"
            echo
            echo "OUTPUT:"
            echo "  - Creates: ./archiso-build/ (add to .gitignore)"
            echo "  - ISO: ./archiso-build/output/custom-arch.iso"
            echo "  - Profile: releng (full Arch installation)"
            exit 0
            ;;
        *)
            log_error "Unknown command: $1"
            echo "Run '$0 help' for usage information"
            exit 1
            ;;
    esac
fi