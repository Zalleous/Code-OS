sudo pacman -Sy --noconfirm

sudo pacman -S --noconfirm base-devel
sudo pacman -S --noconfirm xf86-video-intel mesa lib32-mesa
sudo pacman -S --noconfirm intel-media-driver libva-intel-driver
sudo pacman -S --noconfirm alsa-utils pulseaudio pulseaudio-alsa
sudo pacman -S --noconfirm networkmanager wpa_supplicant

sudo systemctl enable NetworkManager

sudo pacman -S --noconfirm acpi acpid thinkfan

sudo systemctl enable acpid

sudo pacman -S --noconfirm tp_smapi tlp

sudo systemctl enable tlp

sudo pacman -S --noconfirm xf86-input-synaptics xf86-input-libinput
sudo pacman -S --noconfirm b43-fwcutter
sudo pacman -S --noconfirm fprintd

sudo modprobe -a thinkpad_acpi tp_smapi
lspci -k
lsusb

clear

echo "=== Hardware Detection ==="
lspci -k | grep -A 3 VGA

echo -e "\n=== Audio Devices ==="
aplay -l

echo -e "\n=== Network Interfaces ==="
ip link show

echo -e "\n=== Battery Status ==="
acpi -b

echo -e "\n=== Loaded Graphics Driver ==="
lsmod | grep -E "(i915|radeon|nouveau)"

echo -e "\n=== ThinkPad ACPI ==="
lsmod | grep thinkpad_acpi
