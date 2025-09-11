virsh --connect qemu:///system snapshot-revert 'win22' 'stable'
virsh --connect qemu:///system start 'win22'
virt-viewer --connect qemu:///system 'win22'

