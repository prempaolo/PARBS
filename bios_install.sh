#!/bin/sh

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

fdisk "$PARTITION"
