#!/bin/bash

timezone="Asia/Manila"
localization="en_US.UTF-8"

# AMD: amd-ucode
# Intel: intel-ucode
base_install="
	base base-devel linux linux-firmware neovim zsh grub git man reflector
"

aur_install="
	https://aur.archlinux.org/yay.git
"

service="
	sddm.service
	NetworkManager.service
	fstrim.timer
	reflector.service
"

if [ "$1" == "" ]; then

	# Update the system clock
	timedatectl set-ntp true
	timedatectl set-timezone ${timezone}
	timedatectl set-local-rtc 1
	
	# Partition the disks
	lsblk -f

	read -p 'Select block device (sda/sdb/...): ' drive
	cfdisk /dev/${drive}

	fdisk -l /dev/${drive}
	echo
	# Format the partitions
	read -p 'Root partition number: ' p_root

	mkfs.ext4 -F -L "Arch Linux" /dev/${drive}${p_root}

	# Mount the file systems
	mount /dev/${drive}${p_root} /mnt

	# Config pacman.conf
	sed -i "/Color/s/^#//g" /etc/pacman.conf
	sed -i "/TotalDownload/s/^#//g" /etc/pacman.conf
	sed -i '/^#\[multilib\]/{N;s/#//g}' /etc/pacman.conf

	# Install essential packages
	pacstrap /mnt ${base_install}

	# Fstab
	genfstab -U /mnt >> /mnt/etc/fstab

	cp $0 /mnt/setup
	
	echo -e "\nEnter user name:"
	read user
	echo "Enter ${user}'s password:"
	read userpwd
	echo "Enter root password:"
	read rootpwd

	# Chroot
	arch-chroot /mnt ./setup ${user} ${userpwd} ${rootpwd}
	rm /mnt/setup

else
	user=${1}
	userpwd=${2}
	rootpwd=${3}

	# Time zone
	ln -sf /usr/share/zoneinfo/${timezone} /etc/localtime
	hwclock --systohc

	# Localization
	sed -i "/${localization}/s/^#//g" /etc/locale.gen
	locale-gen
	echo "LANG=${localization}" > /etc/locale.conf
	#localectl set-locale LANG=${localization}
	#echo "KEYMAP=${keyboardlayout}" > /etc/vconsole.conf

	# Network configuration
	read -p "Hostname: " hostname
	echo "${hostname}" > /etc/hostname
	echo "127.0.0.1  localhost" > /etc/hosts
	echo "::1        localhost" >> /etc/hosts
	echo "127.0.1.1  ${hostname}.localdomain  ${hostname}" >> /etc/hosts

	# Default Editor
	echo "EDITOR=nvim" >> /etc/environment

	# visudo
	sed -i "/%wheel ALL=(ALL) NOPASSWD: ALL/s/^# //g" /etc/sudoers

	# Create Swap File
	read -p 'Do you want to create a swap file? [y/N]: ' swap
	if [ $swap = 'y' ] || [ $swap = 'Y' ]
	then 
		read -p "How big is the swap file? (GB _ Not support MB): " swapsize
		# fallocate -l ${swapsize} /swapfile
		dd if=/dev/zero of=/swapfile bs=1M count=${swapsize}G status=progress
		chmod 600 /swapfile
		mkswap /swapfile
		echo "# /swapfile" >> /etc/fstab
		echo "/swapfile    none    swap    defaults    0 0" >> /etc/fstab
	fi

	# Install Boot loader
	grub-install /dev/${drive}
	grub-mkconfig -o /boot/grub/grub.cfg

	# Create User
	useradd -m -G wheel,uucp -s /bin/zsh -c "Vu Duc Nguyen" ${user}
	#sudo -u ${user} xdg-user-dirs-update
	#eval userpath=~${user}

	# Create password for root and user account
	echo -en "${rootpwd}\n${rootpwd}" | passwd
	echo -en "${userpwd}\n${userpwd}" | passwd ${user}

	# Config pacman.conf
	sed -i "/Color/s/^#//g" /etc/pacman.conf
	sed -i "/TotalDownload/s/^#//g" /etc/pacman.conf
	sed -i '/^#\[multilib\]/{N;s/#//g}' /etc/pacman.conf

	# Install Packages
	pacman -Syu xorg-server
	pacman -S plasma-meta kde-applications-meta

	# Enable Service
	for item in ${service}; do
		systemctl enable ${item}
	done

fi
