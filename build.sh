die() {
  echo -e "\x1b[31m${1}\x1b[0m" >&2
  exit 1
}

if [ ${EUID} -ne 0 ]; then
  die "this script must be run as root!"
fi

if [ $# -le 0 ]; then
  die "you must pass an input RMA shim"
fi

if [ $# -le 1 ]; then
  die "you must pass an output image path"
fi

if ! which cgpt >/dev/null 2>/dev/null; then
  die "this program requires cgpt"
fi


get_partition() {
  echo -n "${1}p${2}"
}

SHIM_PATH="${1}"
OUT_PATH="${2}"
OUT_SIZE="64M"

touch ${OUT_PATH}
truncate -s ${OUT_SIZE} ${OUT_PATH}

SHIM_DEV=$(losetup -Pf --show "${SHIM_PATH}")
OUT_DEV=$(losetup -Pf --show "${OUT_PATH}")

(
echo "g"
echo "n"
echo "1"
echo ""
echo "+1M"
echo "n"
echo "2"
echo "4096"
echo "+32M"
echo "t"
echo "2"
echo "180"
echo "n"
echo "3"
echo ""
echo ""
echo "t"
echo "3"
echo "181"
echo "w"
) | fdisk ${OUT_DEV}

dd if=$(get_partition ${SHIM_DEV} 2) of=$(get_partition ${OUT_DEV} 2)
mkfs.ext4 $(get_partition ${OUT_DEV} 3)
mkfs.ext4 $(get_partition ${OUT_DEV} 1)
cgpt add -i 2 -S 1 -T 5 -P 10 -l kernel ${OUT_DEV} 

mkdir mnt
mount $(get_partition ${OUT_DEV} 3) mnt
tar xf terrastage1.tar.zst -C mnt
cp -a assets bootloader.sh mnt/
cp bash-static mnt/bash
gcc -static -o myswitchroot myswitchroot.c
mv myswitchroot mnt/
chmod +x mnt/myswitchroot mnt/bash mnt/bootloader.sh
umount mnt
mount $(get_partition ${OUT_DEV} 1) mnt
mkdir -p mnt/dev_image/etc/
touch mnt/dev_image/etc/lsb-factory
umount mnt
rm -r mnt

losetup -d ${SHIM_DEV}
losetup -d ${OUT_DEV}
