sudo pacman -S xf86-video-intel mesa lib32-mesa
sudo pacman -S intel-media-driver libva-intel-driver
sudo pacman -S alsa-utils pulseaudio pulseaudio-alsa
sudo pacman -S networkmanager wpa_supplicant
sudo systemctl enable networkmanager
sudo pacman -S acpi acpid thinkfan
sudo systemctl enable acpid
sudo pacman -S tp_smapi tlp
sudo systemctl enable tlp
sudo pacman -S xf86-input-synaptics xf86-input-libinput
sudo pacman -S linux-firmware
sudo pacman -S b43-fwcutter
sudo pacman -S fprintd

sudo modprobe -a thinkpad_acpi tp_smapi
lspci -k
lsusb
