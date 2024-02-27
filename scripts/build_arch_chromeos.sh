if [ ${EUID} -ne 0 ]; then
  echo "this script must be run as root" >&2
  exit 1
fi

if [ $# -lt 1 ]; then
  echo "usage: build_arch_chromeos.sh <rootfs_dir>"
  exit 1
fi

cp terra_chromeos.img terra_chromeos_arch.img
truncate -s 9G terra_chromeos_arch.img
OUT_DEV=$(losetup -Pf --show terra_chromeos_arch.img)

(
echo "n"
echo "13"
echo ""
echo ""
echo ""
echo "t"
echo "13"
echo "3cb8e202-3b7e-47dd-8a3c-7ff2a13cfcec"
echo "w"
) | fdisk "${OUT_DEV}"

cgpt add -i 13 -l terra_arch "${OUT_DEV}"

mkfs.ext4 "${OUT_DEV}"p13

mkdir mnt
mount "${OUT_DEV}"p13 mnt 
cp -a "${1}"/* mnt/
umount mnt
rm -r mnt

losetup -d ${OUT_DEV}

zstd -k terra_chromeos_arch.img
zip terra_chromeos_arch.img.zip terra_chromeos_arch.img
