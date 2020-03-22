ln -sf /usr/share/zoneinfo/Europe/Rome /etc/localtime

hwclock --systohc

sed -i '/#en_US.UTF-8 UTF-8/s/^#//g' /etc/locale.gen

echo "LANG=en_US.UTF-8" > /etc/locale.conf

echo "archlinux" > /etc/hostname

echo -e "127.0.0.1\tlocalhost\n::1\t\tlocalhost\n127.0.1.1\tarchlinux.local\tarchlinux" >> /etch/hosts

mkinitcpio -P

(echo root; echo root) | passwd

pacman -Sy grub

grub-install --target=i386-pc $PARTITION

grub-mkconfig -o /boot/grub/grub.cfg

exit
