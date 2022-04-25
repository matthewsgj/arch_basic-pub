### Do all this before running amending and running the script ###
timedatectl set-ntp true

#cfdisk /dev/sda
# * disklable: gpt
# * part1: 512Mb EFI System
# * part2: 2Gb Linux swap
# * part3: +Gb Linux filesystem

mkfs.fat -F32 /dev/sda1
mkswap /dev/sda2
swapon /dev/sda2
mkfs.btrfs /dev/sda3

mount /dev/sda3 /mnt
cd /mnt
btrfs subvolume create @
btrfs subvolume create @var
btrfs subvolume create @home
cd /
umount /mnt
mount -o subvol=@ /dev/sda3 /mnt
mkdir -p /mnt/{boot,home,var}
mount /dev/sda1 /mnt/boot
mount -o subvol=@home /dev/sda3 /mnt/home
mount -o subvol=@var /dev/sda3 /mnt/var


#select mirrors - /etc/pacman.d/mirrorlist
sed -i '/internode/s/#//' /etc/pacman.d/mirrorlist

#enable multilib in /etc/pacman.conf
cat <<-EOT >> /etc/pacman.conf
	[multilib]
	Include = /etc/pacman.d/mirrorlist
EOT

pacstrap /mnt base linux linux-firmware \
# dev essentials
	base-devel \
# bootloader
	grub \
# Text editor \
	vim \
# Admin tools \
	openssh sudo \
# Documentation \
	man-db man-pages texinfo
# UEFI stuff \
	efibootmgr dosfstools os-prober mtools \
# disk utilities \
	btrfs-progs \

genfstab -U /mnt >> /mnt/etc/fstab

arch-chroot /mnt

### End pre-run setup ###

# set timezone
ln -sf /usr/share/zoneinfo/Australia/Brisbane /etc/localtime
hwclock --systohc

#vim /etc/locale.gen # en_AU.UTF-8
sed -ie '/en_AU.UTF/s/# //' /etc/locale.gen
locale-gen

# create hostname
hostnamectl set-hostname arch_basic

# host name resolution
cat <<-EOT >>/etc/hosts
  127.0.0.1        localhost
  ::1              localhost
  127.0.1.1        arch_basic
EOT

## GRUB2 bootloader
#grub-install --target=x86_64-efi --bootloader-id=grub_uefi [ --efi-directory=/efi/ ] --recheck
#
#grub-mkconfig -o /boot/grub/grub.cfg
#
# OR #
#
# systemd-boot boot loader
bootctl --esp-path=/boot install
(echo "timeout 5" && echo "default arch") >> /boot/loader/loader.conf

cat <<-EOT >> /boot/loader/entries/arch.conf
  title Arch Linux
  linux /vmlinuz-linux
  initrd /initramfs-linux.img
  options root=UUID=$(blkid -o value /dev/sda2|head -1) rootflags=subvol=@ rw
EOT

cp /boot/loader/entries/arch.conf /boot/loader/entries/arch-fallback.conf
sed -i '/initrd/s/linux.img/linux-fallback.img/' /boot/loader/entries/arch-fallback.conf

# add a user and set passwords - CHANGE THIS
useradd -mg users -G wheel,storage,power -s /bin/bash user1
echo "root:password" |chpasswd
echo "user1:password" |chpasswd

# Enable %wheel group in sudoers
#visudo
echo '%wheel ALL=(ALL) ALL' >> /etc/sudoers

# DHCP networking
cat <<-EOT > /etc/systemd/network/10-dhcpcd.network
  [Match]
  Name=*

  [Network]
  DHCP=ipv4
EOT

# OR #
##Address=10.0.2.100
##Gateway=10.0.2.2
##DNS=10.0.2.2

systemctl enable --now systemd-networkd.service
systemctl enable --now systemd-resolved.service
systemctl enable --now sshd.service
