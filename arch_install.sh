#!/bin/bash

timezone="Asia/Manila"
localization="en_US.UTF-8"

# AMD: amd-ucode
# Intel: intel-ucode
base_install="
	base base-devel linux-zen linux-firmware ntfs-3g neovim zsh grub os-prober intel-ucode efibootmgr dnsmasq zip unzip p7zip unrar tlp git man reflector
"

gnome3="
	baobab cheese eog evince file-roller gdm gedit gnome-backgrounds gnome-boxes gnome-calculator gnome-calendar gnome-characters gnome-clocks gnome-color-manager gnome-contacts gnome-control-center gnome-disk-utility gnome-font-viewer gnome-keyring gnome-logs gnome-menus gnome-music gnome-photos gnome-screenshot gnome-session gnome-settings-daemon gnome-shell gnome-shell-extensions gnome-system-monitor gnome-terminal gnome-themes-extra gnome-user-share gnome-video-effects gnome-weather grilo-plugins gvfs gvfs-afc gvfs-goa gvfs-google gvfs-gphoto2 gvfs-mtp gvfs-nfs gvfs-smb mutter nautilus networkmanager simple-scan sushi totem tracker3 tracker3-miners xdg-user-dirs-gtk
"
# Gnome extra
gnome3+="
	dconf-editor ghex gnome-multi-writer gnome-nettool gnome-sound-recorder gnome-tweaks gnome-usage sysprof
"

apps_install="
	chromium firefox reflector
"

aur_install="
	https://aur.archlinux.org/yay.git
"

service="
	gdm.service
	NetworkManager.service
	dnsmasq.service
	bluetooth.service
	fstrim.timer
	tlp.service
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
	# Format the partitions
	read -p 'Boot (GRUB) partition number: ' p_boot
	read -p 'Root partition number: ' p_root

	read -p 'You have dual boot with windows??? [Y/n]: ' dual_on
	if [ $dual_on = 'n' ] && [ $dual_on = 'N' ]
	then 
		mkfs.fat -F32 -n "EFI System" /dev/${drive}${p_boot}
	fi

	mkfs.ext4 -F -L "Arch Linux" /dev/${drive}${p_root}

	# Mount the file systems
	mount /dev/${drive}${p_root} /mnt
	mkdir -v /mnt/boot
	mount /dev/${drive}${p_boot} /mnt/boot

	# Config pacman.conf
	sed -i "/Color/s/^#//g" /etc/pacman.conf
	sed -i "/TotalDownload/s/^#//g" /etc/pacman.conf
	sed -i '/^#\[multilib\]/{N;s/#//g}' /etc/pacman.conf

	# Install essential packages
	pacstrap /mnt ${base_install}

	# Config pacman.conf
	sed -i "/Color/s/^#//g" mnt/etc/pacman.conf
	sed -i "/TotalDownload/s/^#//g" mnt/etc/pacman.conf
	sed -i '/^#\[multilib\]/{N;s/#//g}' mnt/etc/pacman.conf

	# Fstab
	genfstab -U /mnt >> /mnt/etc/fstab

	cp $0 /mnt/setup
	
	echo "Enter user name:"
	read user
	echo "Enter ${user}'s password:"
	read userpwd
	echo "Enter root password:"
	read rootpwd

	# Chroot
	arch-chroot /mnt ./setup ${user} ${userpwd} ${rootpwd}
	rm /mnt/setup

	umount -R /mnt
else
	user=${1}
	userpwd=${2}
	rootpwd=${3}

	# Time zone
	ln -sf /usr/share/zoneinfo/${timezone} /etc/localtime
	timedatectl set-local-rtc 1
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
	sed -i "/%wheel ALL=(ALL) ALL/s/^# //g" /etc/sudoers

	# Create Swap File
	read -p 'Do you want to create a swap file? [y/N]: ' swap
	if [ $swap = 'y' ] && [ $swap = 'Y' ]
	then 
		read -p "How big is the swap file? (GB _ Not support MB)" swapsize
		# fallocate -l ${swapsize} /swapfile
		dd if=/dev/zero of=/swapfile bs=1M count=${swapsize}G status=progress
		chmod 600 /swapfile
		mkswap /swapfile
		echo "# /swapfile" >> /etc/fstab
		echo "/swapfile    none    swap    defaults    0 0" >> /etc/fstab
	fi

	# Install Boot loader
	grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB --recheck
	grub-mkconfig -o /boot/grub/grub.cfg

	# Create User
	useradd -m -G wheel,uucp -s /bin/zsh -c "Vu Duc Nguyen" ${user}
	#sudo -u ${user} xdg-user-dirs-update
	#eval userpath=~${user}

	# Install Packages
	pacman -Syu gnome3
	pacman -S apps_install

	for item in ${aurinstall}; do
		name=$(basename ${item} .git)
		echo "Installing ${name}"
		cd /tmp
		sudo -u ${user} git clone ${item}
		cd ${name}
		sudo -u ${user} makepkg -si
		cd /tmp
		rm -rf ${name}
	done

	# Enable Service
	for item in ${service}; do
		systemctl enable ${item}
	done

	# Create password for root and user account
	echo -en "${rootpwd}\n${rootpwd}" | passwd
	echo -en "${userpwd}\n${userpwd}" | passwd ${user}
fi
