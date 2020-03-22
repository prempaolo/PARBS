#!/bin/sh

ROOT_PARTITION_SPACE="+10G"
SWAP_PARTITION_SPACE="+1G"
UEFI=false

# Check if there is a working internet connection, otherwise exits
ping -q -c 1 -W 1 8.8.8.8 &>/dev/null || { echo "Setup an internet connection before proceeding"; exit 1; }

# Check if system is UEFI or BIOS
ls /sys/firmware/efi/efivars >/dev/null && UEFI=true

timedatectl set-ntp true

COUNTER=1
echo -e "\nSelect which partition to install Arch to:\n"
while read -r line; do
	echo "$COUNTER) $line" 
	COUNTER=$((COUNTER+1))
done <<< "$(fdisk -l | grep 'Disk /dev')"

# Read input until user provides a valid input
read CHOICE
while ! [[ "$CHOICE" =~ ^[0-9]+$ ]] || [ "$CHOICE" -ge "$COUNTER" ] || [ "$CHOICE" -eq 0 ]; do
	[ "$CHOICE" = "q" ] && exit 1
	echo "Please insert a valid choice, press q to exit"
	read CHOICE
done

PARTITION="$(fdisk -l | grep 'Disk /dev' | sed "${CHOICE}q;d" | awk -F " " '{ print substr($2, 1, length($2)-1) }')"

# Creates three partitions, /, /home and swap
[ $UEFI ] && 
	(echo n; echo p; echo 1; echo ""; echo "$ROOT_PARTITION_SPACE"; echo n; echo p; echo 2; echo ""; echo "$SWAP_PARTITION_SPACE"; echo n; echo p; echo 3; echo ""; echo ""; echo t; echo 2; echo 82; echo w) | fdisk "$PARTITION" ||
	(echo n; echo p; echo 1; echo ""; echo "+260M"; echo t; echo ef; echo n; echo p; echo 2; echo ""; echo "$ROOT_PARTITION_SPACE"; echo n; echo p; echo 3; echo ""; echo "$SWAP_PARTITION_SPACE"; echo n; echo p; echo 4; echo ""; echo ""; echo t; echo 3; echo 82; echo w) | fdisk "$PARTITION"

[ $UEFI ] && mkdir /mnt/efi && mount "$PARTITION"1

[ $UEFI ] && mkfs.ext4 "$PARTITION"2 || mkfs.ext4 "$PARTITION"1
[ $UEFI ] && { mkswap "$PARTITION"3; swapon "$PARTITION"3; } || { mkswap "$PARTITION"2; swapon "$PARTITION"2 }
[ $UEFI ] && mkfs.ext4 "$PARTITION"4 || mkfs.ext4 "$PARTITION"3

[ $UEFI ] && mount "$PARTITION"2 /mnt || mount "$PARTITION"1 /mnt
mkdir /mnt/home
[ $UEFI ] && mount "$PARTITION"4 /mnt/home || mount "$PARTITION"3 /mnt/home

pacstrap /mnt base linux linux-firmware

genfstab -U /mnt >> /mnt/etc/fstab

# Commands to execute as chroot
[ $UEFI ] && cp uefi_chroot_cmds.sh /mnt/root/ || cp bios_chroot_cmds.sh /mnt/root

arch-chroot /mnt /root/chroot_cmds.sh
