#!/bin/sh

ROOT_PARTITION_SPACE="+10G"
SWAP_PARTITION_SPACE="+1G"

# Check if there is a working internet connection, otherwise exits
ping -q -c 1 -W 1 8.8.8.8 &>/dev/null || { echo "Setup an internet connection before proceeding"; exit 1; }

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

(echo n; echo p; echo 1; echo ""; echo "$ROOT_PARTITION_SPACE"; echo n; echo p; echo 2; echo ""; echo "$SWAP_PARTITION_SPACE"; echo n; echo p; echo 3; echo ""; echo ""; echo t; echo 2; echo 82; echo w) | fdisk "$PARTITION"

mkfs.ext4 /dev/"$PARTITION"1
mkswap /dev/"$PARTITION"2
swapon /dev/"$PARTITION"2
mkfs.ext4 /dev/"$PARTITION"3

mount /dev/"$PARTITION"1 /mnt
mkdir /mnt/home
mount /dev/"$PARTITION"3 /mnt/home

pacstrap /mnt base linux linux-firmware

genfstab -U /mnt >> /mnt/etc/fstab

arch-chroot /mnt

ln -sf /usr/share/zoneinfo/Europe/Rome /etc/localtime

hwclock --systohc

sed -i '/#en_US.UTF-8 UTF-8/s/^#//g' /etc/locale.gen

echo "LANG=en_US.UTF-8" > /etc/locale.conf

echo "archlinux" > /etc/hostname

echo -e "127.0.0.1\tlocalhost\n::1\t\tlocalhost\n127.0.1.1\tarchlinux.local\tarchlinux" >> /etch/hosts

mkinitcpio -P

(echo root; echo root) | passwd

pacman -Sy grub
