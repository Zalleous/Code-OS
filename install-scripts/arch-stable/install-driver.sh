sudo pacman -Sy --noconfirm

xargs -r sudo pacman -S --noconfirm --needed < packages.txt

sudo systemctl enable NetworkManager

sudo systemctl enable acpid

sudo systemctl enable tlp

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
