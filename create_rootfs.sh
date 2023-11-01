die() {
  echo -e "\x1b[31m${1}\x1b[0m" >&2
  exit 1
}

if [ ${EUID} -ne 0 ]; then
  die "this script must be run as root!"
fi

if [ $# -le 0 ]; then
  die "you must pass an output rootfs path"
fi

if [ $# -le 1 ]; then
  die "you must pass an input RMA shim"
fi

if [ $# -le 2 ]; then
  die "you must pass an input board recovery image"
fi

if [ $# -le 3 ]; then
  die "you must pass the built systemd-chromiumos package"
fi

if [ $# -le 4 ]; then
  die "you must pass the built systemd-chromiumos-libs package"
fi

if [ $# -le 5 ]; then
  die "you must pass the built systemd-chromiumos-sysvcompat package"
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

if test ! -f "${2}"; then
  die "${2}: No such file"
fi

if test ! -f "${3}"; then
  die "${3}: No such file"
fi

if test ! -f "${4}"; then
  die "${4}: No such file"
fi

if test ! -f "${5}"; then
  die "${5}: No such file"
fi

if test ! -f "${6}"; then
  die "${6}: No such file"
fi

# fix for people not removing the old rootfs before re-creating it
rm -rf "${1}"
mkdir "${1}"

if test -d mnt; then rm -r mnt; fi

pacstrap -K "${1}" base linux-firmware networkmanager network-manager-applet xfce4 xfce4-goodies lightdm-gtk-greeter pulseaudio pavucontrol alsa-utils sof-firmware mesa-amber firefox noto-fonts which sudo vim neofetch || die "failed to bootstrap rootfs"
cp "${4}" "${5}" "${6}" "${1}/" || die "failed to copy packages to root"
mount --bind "${1}" "${1}" || die "failed to bindmount root"
arch-chroot "${1}" pacman --noconfirm -Rdd systemd systemd-libs systemd-sysvcompat || die "failed to remove systemd"
arch-chroot "${1}" bash -c 'pacman --noconfirm -U *.pkg.tar.zst' || die "failed to install packages"
arch-chroot "${1}" bash -c 'rm *.pkg.tar.zst' || die "failed to remove packages"
arch-chroot "${1}" bash -c 'rm /var/cache/pacman/pkg/*' || die "failed to remove package cache" 
arch-chroot "${1}" useradd -m terraos || die "failed to add terraos user"
arch-chroot "${1}" bash -c 'echo -e "terraos\nterraos" | passwd terraos' || die "failed to set terraos user password"
arch-chroot "${1}" bash -c "echo 'terraos ALL=(ALL:ALL) NOPASSWD:ALL' >> /etc/sudoers" || die "failed to add terraos to sudoers"
cat <<EOT > "${1}/etc/systemd/system/kill-frecon.service"
[Unit]
Description=Tell frecon to kill itself

[Service]
Type=simple
ExecStart=/usr/bin/killall frecon-lite

[Install]
WantedBy=basic.target
EOT
arch-chroot "${1}" systemctl enable NetworkManager lightdm kill-frecon || die "failed to enable services"

lsof -t +D "${1}" 2>/dev/null | xargs kill -9 

umount -R "${1}" || die "failed to unmount root bindmount"

SHIM_DEV=$(losetup -Pf --show "${2}")

mkdir mnt || die "failed to create temporary mountpoint"

mount "${SHIM_DEV}p3" -o ro mnt || die "failed to mount shim"
cp -a mnt/lib/firmware "${1}/lib/" || die "failed to copy firmware"
cp -a mnt/lib/modules  "${1}/lib/" || die "failed to copy modules"
umount -f mnt || die "failed to unmount shim"

losetup -d ${SHIM_DEV} || die "failed to remove shim loop device"

RECO_DEV=$(losetup -Pf --show "${3}")

mount "${RECO_DEV}p3" -o ro mnt || die "failed to mount recovery image"
cp -a mnt/etc/modprobe.d/alsa* "${1}/etc/modprobe.d/" || die "failed to copy alsa drivers"
umount -f mnt || die "failed to unmount recovery image"

losetup -d ${RECO_DEV} || die "failed to remove recovery image loop device"

rm -r mnt || die "failed to remove temporary mountpoint"


