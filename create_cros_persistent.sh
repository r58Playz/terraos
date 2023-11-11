#!/bin/bash

help(){
  echo "Usage:
    create_cros_persistent.sh <reven_recovery_image> <chromeos_recovery_image> <shim> <terraos_bootloader> <output_image>
    create_cros_persistent.sh -h | --help"
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
  die "this script needs to be run as root"
fi

if [ $# -le 0 ]; then
  die_help "you must pass an input reven (chromeOS flex) chromeos recovery image"
fi

if [ $# -le 1 ]; then
  die_help "you must pass an input board chromeos recovery image"
fi

if [ $# -le 2 ]; then
  die_help "you must pass an input RMA shim"
fi

if [ $# -le 3 ]; then
  die_help "you must pass a terraos bootloader"
fi

if [ $# -le 4 ]; then
  die_help "you must pass an output image path"
fi

if test ! -f "${1}"; then
  die "${1}: no such file"
fi

if test ! -f "${2}"; then
  die "${2}: no such file"
fi

if test ! -f "${3}"; then
  die "${3}: no such file"
fi

if test ! -f "${4}"; then
  die "${3}: no such file"
fi

if test ! -f "${5}" && test -b "${5}"; then
  die "passing block devices to this script is unsupported"
fi

if ! which pv >/dev/null 2>/dev/null; then
  die "this program requires pv"
fi

if ! which truncate >/dev/null 2>/dev/null; then
  die "this program requires truncate"
fi

rm "${5}"
touch "${5}"
truncate -s 5G "${5}"

ROOT_DEV=$(losetup -Pf --show "${1}")
RECO_DEV=$(losetup -Pf --show "${2}")
SHIM_DEV=$(losetup -Pf --show "${3}")
BOOTLOADER_DEV=$(losetup -Pf --show "${4}")
OUT_DEV=$(losetup -Pf --show "${5}")

(
echo "g"
echo "n"
echo "2"
echo ""
echo "+1"
echo "n"
echo "4"
echo ""
echo "+32M"
echo "n"
echo "5"
echo ""
echo "+48M"
echo "n"
echo "6"
echo ""
echo "+1"
echo "n"
echo "7"
echo ""
echo "+1"
echo "n"
echo "8"
echo ""
echo "+1"
echo "n"
echo "9"
echo ""
echo "+1"
echo "n"
echo "10"
echo ""
echo "+1"
echo "n"
echo "11"
echo ""
echo "+1"
echo "n"
echo "12"
echo ""
echo "+1"
echo "n"
echo "3"
echo ""
echo "+3G"
echo "n"
echo "1"
echo ""
echo ""
echo ""
echo "t"
echo "3"
echo "3cb8e202-3b7e-47dd-8a3c-7ff2a13cfcec"
echo "t"
echo "4"
echo "fe3a2a5d-4f32-41a7-b725-accc3285a309"
echo "t"
echo "5"
echo "3cb8e202-3b7e-47dd-8a3c-7ff2a13cfcec"
echo "w"
) | fdisk "${OUT_DEV}"

mkfs.ext4 "${OUT_DEV}p1"

dd if="${ROOT_DEV}p3" of="${OUT_DEV}p3" status=progress

dd if="${BOOTLOADER_DEV}p2" of="${OUT_DEV}p4" status=progress
dd if="${BOOTLOADER_DEV}p3" of="${OUT_DEV}p5" status=progress

cgpt add -i 4 -S 1 -T 5 -P 10 -l kernel ${OUT_DEV} 
cgpt add -i 3 -l terra_chromeos ${OUT_DEV}

printf '\000' | sudo dd of="${OUT_DEV}p3" seek=$((0x464 + 3)) conv=notrunc count=1 bs=1

fsck -fy "${OUT_DEV}p3"
resize2fs "${OUT_DEV}p3"

mkdir -p mnt/src mnt/dst
mount "${OUT_DEV}p3" mnt/dst
mount "${SHIM_DEV}p3" -o ro mnt/src
rm -rf mnt/dst/lib/modules/*
cp -r mnt/src/lib/modules mnt/dst/lib/
cp -r mnt/src/lib/firmware mnt/dst/lib/
sync
sleep 1 # my system keeps on giving me target is busy errors
umount mnt/src
mount "${RECO_DEV}p3" -o ro mnt/src
cp -r mnt/src/etc/modprobe.d/alsa* mnt/dst/etc/modprobe.d/
cp -r mnt/src/usr/share/chromeos-config/* mnt/dst/usr/share/chromeos-config
sync
sleep 1 # my system keeps on giving me target is busy errors
umount mnt/src
sed -i "s/^script/script\necho 'hiiii'>\/dev\/kmsg\nmkdir \/tmp\/empty\nmount --bind \/tmp\/empty \/sys\/class\/tpm\/\necho 'done!'>\/dev\/kmsg\nmodprobe zram\npkill frecon-lite\n/" mnt/dst/etc/init/boot-splash.conf
sed -i "s/reven_branding//" mnt/dst/etc/ui_use_flags.txt
sed -i "s/os_install_service//" mnt/dst/etc/ui_use_flags.txt
sed -i "s/DEVICETYPE=OTHER/DEVICETYPE=CHROMEBOOK/" mnt/dst/etc/lsb-release
mv mnt/dst/usr/bin/crossystem mnt/dst/usr/bin/crossystem.old
cp crossystem.sh mnt/dst/usr/bin/crossystem
chmod 777 mnt/dst/usr/bin/crossystem
git clone https://chromium.googlesource.com/chromiumos/third_party/linux-firmware fw --depth=1 -b master
cp -r fw/* mnt/dst/lib/firmware/
rm -r fw
sync
umount mnt/dst
mount "${OUT_DEV}p1" mnt/dst
mkdir -p mnt/dst/dev_image/etc/
touch mnt/dst/dev_image/etc/lsb-factory
sync
umount mnt/dst

rm -r mnt

losetup -d ${ROOT_DEV}
losetup -d ${RECO_DEV}
losetup -d ${SHIM_DEV}
losetup -d ${BOOTLOADER_DEV}
losetup -d ${OUT_DEV}

