#!/bin/bash

timezone="Asia/Manila"
localization="en_US.UTF-8"
keyboardlayout="us"
xkeyboardlayout="us"
hostname="ThinkPad"
swapsize="2G"

base_install="
	base base-devel linux-zen linux-firmware ntfs-3g neovim zsh grub os-prober intel-ucode efibootmgr dnsmasq
	zip unzip p7zip unrar tlp git
"

# install= "xf86-video-intel libva-intel-driver
# 	xf86-input-synaptics pulseaudio networkmanager dnsmasq
# 	xorg-server xorg-xinit xorg-xinput xorg-xbacklight libxft libxinerama
# 	git xdg-user-dirs maim xdotool zip unzip gst-libav dunst gpick dmenu
# 	thunar thunar-volman gvfs gvfs-mtp gvfs-gphoto2 ntfs-3g thunar-archive-plugin xarchiver tumbler ffmpegthumbnailer
# 	rxvt-unicode chromium mousepad eom gimp pragha parole galculator transmission-gtk
# 	nm-connection-editor blueman pavucontrol lxtask lxinput lxrandr lxappearance
# 	ttf-dejavu gnome-themes-extra papirus-icon-theme "

gnome3="
	baobab cheese eog evince file-roller gdm gedit gnome-backgrounds gnome-boxes gnome-calculator gnome-calendar gnome-characters gnome-clocks gnome-color-manager gnome-contacts gnome-control-center gnome-disk-utility gnome-font-viewer gnome-keyring gnome-logs gnome-menus gnome-music gnome-photos gnome-screenshot gnome-session gnome-settings-daemon gnome-shell gnome-shell-extensions gnome-system-monitor gnome-terminal gnome-themes-extra gnome-user-share gnome-video-effects gnome-weather grilo-plugins gvfs gvfs-afc gvfs-goa gvfs-google gvfs-gphoto2 gvfs-mtp gvfs-nfs gvfs-smb mutter nautilus networkmanager simple-scan sushi totem tracker3 tracker3-miners xdg-user-dirs-gtk
"

gnome3_extra="
	dconf-editor ghex gnome-multi-writer gnome-nettool gnome-sound-recorder gnome-tweaks gnome-usage sysprof
"

apps_install="
	chromium firefox
"

aur_install="
	https://aur.archlinux.org/yay.git
"
git_install="

"

service="
	NetworkManager.service
	dnsmasq.service
	bluetooth.service
	fstrim.timer
	tlp.service
"
if [ "$1" == "" ]; then
	# Set up network connection
	# ping -c 3 archlinux.org
	# read -p 'Are you connected to internet? [y/N]: ' neton
	# if ! [ $neton = 'y' ] && ! [ $neton = 'Y' ]
	# then
	# 	read -p 'Do you want to connect to the internet by wifi? [Y/n]: ' wfon
	# 	if ! [ $wfon = 'n' ] && ! [ $wfon = 'N' ]
	# 	then
	# 		echo "List all Wi-Fi devices"
	# 		iwd device list
	# 		echo "Scan for networks"
	# 		read -p 'Input Wi-Fi devices, you want scan: ' device
	# 		iwd station ${device} scan
	# 		echo "List all available networks"
	# 		iwd station ${device} get-networks
	# 		echo "Connect to a network"
	# 		read -p 'Input SSID you want connect: ' ssid
	# 		iwd station ${device} connect ${ssid}
	# 	elif [ $wfon = 'n' ] || [ $wfon = 'N' ]
	# 	then
	# 		echo "Connect to internet to continue..."
    # 		exit
	# 	fi
	# fi

	timedatectl set-ntp true
	timedatectl set-timezone ${timezone}
	
	fdisk -l
	read -p 'Input drive: ' drive

	# Filesystem mount warning
	echo "This script will create and format the partitions as follows:"
	echo "/dev/sda1 - 1Gb will be mounted as /mnt/efi"
	echo "/dev/sda5 - rest of space will be mounted as /"
	read -p 'Continue? [y/N]: ' fsok
	if ! [ $fsok = 'y' ] && ! [ $fsok = 'Y' ]
	then 
		echo "Edit the script to continue..."
		exit
	fi

	# parted -s /dev/${drive} mklabel gpt mkpart ESP fat32 0% 256MiB mkpart primary ext4 256MiB 100% set 1 boot on
	# to create the partitions programatically (rather than manually)
	# https://superuser.com/a/984637
# 	sed -e 's/\s*\([\+0-9a-zA-Z]*\).*/\1/' << EOF | fdisk /dev/${drive}
# 		g # clear the in memory partition table
# 		n # new partition
# 		p # primary partition
# 		1 # partition number 1
# 			# default - start at beginning of disk 
# 		+200M # 200 MB boot parttion
# 		n # new partition
# 		p # primary partition
# 		2 # partion number 1
# 			# default, start immediately after preceding partition
# 			# default, extend partition to end of disk
# 		a # make a partition bootable
# 		1 # bootable partition is partition 1 -- /dev/sda1
# 		p # print the in-memory partition table
# 		w # write the partition table
# 		q # and we're done
# EOF
	cfdisk /dev/${drive}
	#mkfs.fat -F32 -L "EFI System" /dev/${drive}1
	mkfs.ext4 -F -L "Arch Linux" /dev/${drive}5

	mount /dev/${drive}5 /mnt
	mkdir /mnt/efi
	mount /dev/${drive}1 /mnt/efi

	pacstrap /mnt ${base_install}

	genfstab -U /mnt >> /mnt/etc/fstab

	cp $0 /mnt/setup
	
	echo "Enter user name:"
	read user
	echo "Enter ${user}'s password:"
	read userpassword
	echo "Enter root password:"
	read rootpassword

	arch-chroot /mnt ./setup ${user} ${userpassword} ${rootpassword}
	rm /mnt/setup

	umount -R /mnt
else
	user=${1}
	userpassword=${2}
	rootpassword=${3}

	ln -sf /usr/share/zoneinfo/${timezone} /etc/localtime
	hwclock --systohc
	timedatectl set-local-rtc 1

	sed -i "/${localization}/s/^#//g" /etc/locale.gen
	echo "LANG=${localization}" > /etc/locale.conf
	locale-gen
	#localectl set-locale LANG=${localization}
	#echo "KEYMAP=${keyboardlayout}" > /etc/vconsole.conf

	echo "${hostname}" > /etc/hostname
	echo "127.0.0.1  localhost" > /etc/hosts
	echo "::1        localhost" >> /etc/hosts
	echo "127.0.1.1  ${hostname}.localdomain  ${hostname}" >> /etc/hosts

	echo "EDITOR=nvim" >> /etc/environment

	sed -i "/%wheel ALL=(ALL) ALL/s/^# //g" /etc/sudoers

	# fallocate -l ${swapsize} /swapfile
	# chmod 600 /swapfile
	# mkswap /swapfile > /dev/null
	# echo "# /swapfile" >> /etc/fstab
	# echo "/swapfile    none    swap    defaults    0 0" >> /etc/fstab

	# Install bootloader
	grub-install --target=x86_64-efi --efi-directory=/mnt/efi --bootloader-id=GRUB
	grub-mkconfig -o /boot/grub/grub.cfg

	useradd -m -G wheel,uucp -s /bin/zsh -c "Vu Duc Nguyen" ${user}
	#sudo -u ${user} xdg-user-dirs-update
	#eval userpath=~${user}


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

	# for item in ${gitinstall}; do
	# 	name=$(basename ${item} .git)
	# 	echo "Installing ${name}"
	# 	cd ${userpath}/Documents
	# 	sudo -u ${user} git clone ${item} 2> /dev/null
	# 	cd ${name}
	# 	make install > /dev/null
	# done

	# for item in ${gitdownload}; do
	# 	name=$(basename ${item} .git)
	# 	echo "Downloading ${name}"
	# 	cd ${userpath}/Documents
	# 	sudo -u ${user} git clone ${item} 2> /dev/null
	# done

	for item in ${service}; do
		systemctl enable ${item}
	done

	echo -en "${rootpassword}\n${rootpassword}" | passwd
	echo -en "${userpassword}\n${userpassword}" | passwd ${user}
fi
