# arch-install
Arch Linux install script

# Usage

1. Have the github ssh keys saved in ~/.ssh
2. Check again that all the configs are set correctly!
3. Run `iso/build-iso.sh`
4. Create install medium (USB) and boot from it
5. Run the `bootstrap.sh` script

# TODO

* Test encrypted installation.
* Generate and save installation image artefact.

# Sources
https://wiki.archlinux.org/index.php/installation_guide

https://wiki.archlinux.org/index.php/User:Altercation/Bullet_Proof_Arch_Install
https://wiki.archlinux.org/index.php/Arch_boot_process#Boot_loader

Bootloader
https://www.maketecheasier.com/grub-vs-systemd-boot/
https://wiki.archlinux.org/index.php/Systemd-boot

UEFI
https://en.wikipedia.org/wiki/GUID_Partition_Table
https://wiki.archlinux.org/index.php/EFI_system_partition
https://wiki.archlinux.org/index.php/Unified_Extensible_Firmware_Interface#efibootmgr

Micro$osft
https://en.wikipedia.org/wiki/Microsoft_Reserved_Partition
https://docs.microsoft.com/en-us/windows-hardware/manufacture/desktop/configure-uefigpt-based-hard-drive-partitions
https://wiki.archlinux.org/index.php/Dual_boot_with_Windows
