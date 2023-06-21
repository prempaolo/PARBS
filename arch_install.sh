#!/bin/sh

ROOT_PARTITION_SPACE="+30G"
SWAP_PARTITION_SPACE="+8G"
UEFI=false

# Check if there is a working internet connection, otherwise exits
ping -q -c 1 -W 1 8.8.8.8 &>/dev/null || { echo "Setup an internet connection before proceeding"; exit 1; }

# Check if system is UEFI or BIOS
ls /sys/firmware/efi/efivars &>/dev/null && UEFI=true

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
if [ $UEFI = true ]; then
	(echo o; echo n; echo p; echo 1; echo ""; echo "+260M"; echo t; echo ef; echo n; echo p; echo 2; echo ""; echo "$ROOT_PARTITION_SPACE"; echo n; echo p; echo 3; echo ""; echo "$SWAP_PARTITION_SPACE"; echo n; echo p; echo ""; echo ""; echo t; echo 3; echo 82; echo w) | fdisk "$PARTITION";
else
	sed -e 's/\s*\([\+0-9a-zA-Z]*\).*/\1/' << EOF | fdisk "$PARTITION"
  o # clear the in memory partition table
  n # new partition
  p # primary partition
  1 # partition number 1
    # default - start at beginning of disk 
  $ROOT_PARTITION_SPACE # Root partition space
  n # new partition
  p # primary partition
  2 # partition number 1
    # default - start at beginning of disk 
  $SWAP_PARTITION_SPACE # Swap partition space
  n # new partition
  p # primary partition
  3 # partion number 2
    # default, start immediately after preceding partition
    # default, extend partition to end of disk
  t # ???
  2 # 
  82 # 
  w # write the partition table
  q # and we're done
EOF
	#(echo n; echo p; echo 1; echo ""; echo "$ROOT_PARTITION_SPACE"; echo n; echo p; echo 2; echo ""; echo "$SWAP_PARTITION_SPACE"; echo n; echo p; echo 3; echo ""; echo ""; echo t; echo 2; echo 82; echo w) | fdisk "$PARTITION";
fi

[ $UEFI = true ] && mkfs.fat -F32 "$PARTITION"1
if [ $UEFI = true ]; then mkfs.ext4 "$PARTITION"2; else mkfs.ext4 "$PARTITION"1; fi
if [ $UEFI = true ]; then mkswap "$PARTITION"3; swapon "$PARTITION"3; else mkswap "$PARTITION"2; swapon "$PARTITION"2; fi
if [ $UEFI = true ]; then mkfs.ext4 "$PARTITION"4; else mkfs.ext4 "$PARTITION"3; fi
if [ $UEFI = true ]; then mount "$PARTITION"2 /mnt; else mount "$PARTITION"1 /mnt; fi
mkdir /mnt/home
if [ $UEFI = true ]; then mount "$PARTITION"4 /mnt/home; else mount "$PARTITION"3 /mnt/home; fi
[ $UEFI = true ] && { mkdir /mnt/efi; mount "$PARTITION"1 /mnt/efi; }

pacstrap /mnt base linux linux-firmware vim

genfstab -U /mnt >> /mnt/etc/fstab

# Commands to execute as chroot
if [ $UEFI = true ]; then cp uefi_chroot_cmds.sh /mnt/root/; else cp bios_chroot_cmds.sh /mnt/root; fi
if [ $UEFI = true ]; then arch-chroot /mnt /root/uefi_chroot_cmds.sh; else arch-chroot /mnt /root/bios_chroot_cmds.sh "$PARTITION"; fi
