help(){
  echo "Usage:
    build_rootfs.sh <rootfs_path> <shim> <board_recovery_image> [options]
    build_rootfs.sh -h | --help

Options:
    --no-xfce  Skip installing xfce and related packages
    --no-kill-frecon  Don't kill frecon during boot"
}

die() {
  echo -e "\x1b[31m${1}\x1b[0m" >&2
  exit 1
}

die_help() {
  echo -e "\x1b[31m${1}\x1b[0m" >&2
  help
  exit 1
}

has_arg(){
  #example: has_arg "--help" "$@"
  check=$1
  shift
  for arg in "$@"; do
    if [ $arg == $check ]; then
      return 0
    fi
  done
  return 1
}

if has_arg "--help" "$@" || has_arg "-h" "$@"; then
  help
  exit 0
fi

if [ ${EUID} -ne 0 ]; then
  die "this script must be run as root!"
fi

if [ $# -le 0 ]; then
  die_help "you must pass an output rootfs path"
fi

if [ $# -le 1 ]; then
  die_help "you must pass an input RMA shim"
fi

if [ $# -le 2 ]; then
  die_help "you must pass an input board recovery image"
fi

if ! which pacstrap >/dev/null 2>/dev/null; then
  die "this program requires pacstrap from arch-install-scripts"
fi

if ! which arch-chroot >/dev/null 2>/dev/null; then
  die "this program requires arch-chroot from arch-install-scripts"
fi

if ! which lsof >/dev/null 2>/dev/null; then
  die "this program requires lsof"
fi

if ! which xargs >/dev/null 2>/dev/null; then
  die "this program requires xargs"
fi

if ! which wget >/dev/null 2>/dev/null; then
  die "this program requires wget"
fi

if test ! -f "${2}"; then
  die "${2}: No such file"
fi

# fix for people not removing the old rootfs before re-creating it
rm -rf "${1}"
mkdir "${1}"

if test -d mnt; then rm -r mnt; fi

PACKAGES="base networkmanager pulseaudio pavucontrol alsa-utils mesa-amber which sudo vim neofetch base-devel cloud-utils util-linux"

if ! has_arg "--no-xfce" "$@"; then
  PACKAGES="${PACKAGES} network-manager-applet xfce4 xfce4-goodies lightdm-gtk-greeter firefox noto-fonts"
fi

pacstrap -McK "${1}" $PACKAGES || die "failed to bootstrap rootfs"
wget -O- https://archlinux.org/mirrorlist/all/ | sed "s/^#//" | tee "${1}/etc/pacman.d/mirrorlist" || die "failed to get mirrorlist"
cp *.pkg.tar.zst "${1}/" || die "failed to copy packages to root"
mount --bind "${1}" "${1}" || die "failed to bindmount root"
arch-chroot "${1}" pacman --noconfirm -Rdd systemd systemd-libs systemd-sysvcompat || die "failed to remove systemd"
arch-chroot "${1}" bash -c 'pacman --noconfirm -U *.pkg.tar.zst' || die "failed to install packages"
arch-chroot "${1}" bash -c 'rm *.pkg.tar.zst' || die "failed to remove packages"
arch-chroot "${1}" bash -c 'rm /var/cache/pacman/pkg/*' || die "failed to remove package cache" 
arch-chroot "${1}" useradd -m terraos || die "failed to add terraos user"
arch-chroot "${1}" bash -c 'echo -e "terraos\nterraos" | passwd terraos' || die "failed to set terraos user password"
arch-chroot "${1}" bash -c "echo 'terraos ALL=(ALL:ALL) NOPASSWD:ALL' >> /etc/sudoers" || die "failed to add terraos to sudoers"
arch-chroot "${1}" bash -c "ln -sf /usr/share/zoneinfo/America/Los_Angeles /etc/localtime" || die "failed to set time" 
sed -i "s/#en_US.UTF-8/en_US.UTF-8/" "${1}/etc/locale.gen" || die "failed to set locale" 
arch-chroot "${1}" locale-gen || die "failed to generate locale files"
echo "LANG=en_US.UTF-8" > "${1}/etc/locale.conf"
echo "terraos" > "${1}/etc/hostname"

cat <<"EOT" > "${1}/usr/local/bin/expand-root.sh"
set -xe
PART=$(findmnt -no SOURCE /)
DEV=$(lsblk -npo PKNAME ${PART})
echo "${DEV} ${PART} ${PART#${DEV}}"
echo "w" | fdisk ${DEV}
growpart ${DEV} ${PART#${DEV}}
resize2fs ${PART}
EOT

cat <<EOT > "${1}/etc/systemd/system/expand-root.service"
[Unit]
Description=Resize root on first boot
ConditionPathExists=!/usr/local/bin/expand-root.completed

[Service]
Type=simple
ExecStart=/usr/bin/bash /usr/local/bin/expand-root.sh
ExecStartPost=/usr/bin/touch /usr/local/bin/expand-root.completed

[Install]
WantedBy=basic.target
EOT

if ! has_arg "--no-kill-frecon" "$@"; then
cat <<EOT > "${1}/etc/systemd/system/kill-frecon.service"
[Unit]
Description=Tell frecon to kill itself

[Service]
Type=simple
ExecStart=/usr/bin/killall frecon-lite

[Install]
WantedBy=basic.target
EOT
  arch-chroot "${1}" systemctl enable kill-frecon || die "failed to enable kill-frecon service"
fi

if ! has_arg "--no-xfce" "$@"; then
  arch-chroot "${1}" systemctl enable lightdm || die "failed to enable lightdm service"
fi

arch-chroot "${1}" systemctl enable NetworkManager || die "failed to enable services"

lsof -t +D "${1}" 2>/dev/null | xargs kill -9 
rm -rf "${1}"/etc/pacman.d/gnupg/S.*

umount -R "${1}" || die "failed to unmount root bindmount"

SHIM_DEV=$(losetup -Pf --show "${2}")

mkdir mnt || die "failed to create temporary mountpoint"

mount "${SHIM_DEV}p3" -o ro mnt || die "failed to mount shim"
cp -a mnt/lib/modules  "${1}/lib/" || die "failed to copy modules"
cp -a mnt/lib/firmware "${1}/lib/" || die "failed to copy firmware from shim"
sync
umount -l mnt || die "failed to unmount shim"

losetup -d ${SHIM_DEV} || die "failed to remove shim loop device"

RECO_DEV=$(losetup -Pf --show "${3}")

mount "${RECO_DEV}p3" -o ro mnt || die "failed to mount recovery image"
cp -a mnt/etc/modprobe.d/alsa* "${1}/etc/modprobe.d/" || die "failed to copy alsa drivers"
sync
umount -l mnt || die "failed to unmount recovery image"

git clone https://chromium.googlesource.com/chromiumos/third_party/linux-firmware fw --depth=1 -b master || die "failed to clone firmware"
cp -r fw/* "${1}/lib/firmware/" || die "failed to copy firmware"
rm -r fw || die "failed to remove firmware"

losetup -d ${RECO_DEV} || die "failed to remove recovery image loop device"

rm -r mnt || die "failed to remove temporary mountpoint"

# it may already exist
mkdir -p "${1}/etc/modules-load.d" || true
echo "iwlmvm" >> "${1}/etc/modules-load.d/dedede-wifi.conf"
echo "ccm" >> "${1}/etc/modules-load.d/dedede-wifi.conf"
