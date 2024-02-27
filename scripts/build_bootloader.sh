help(){
  echo "Usage:
    build_bootloader.sh <shim> <output_filename>
    build_bootloader.sh -h | --help

Builds the TerraOS bootloader."
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
  die_help "you must pass an input RMA shim"
fi

if [ $# -le 1 ]; then
  die_help "you must pass an output image filename"
fi

if ! which cgpt >/dev/null 2>/dev/null; then
  die "this program requires cgpt"
fi

if ! which truncate >/dev/null 2>/dev/null; then
  die "this program requires truncate"
fi

if ! which gcc >/dev/null 2>/dev/null; then
  die "this program requires gcc"
fi

if test ! -f "${1}" && test -b "${1}"; then
  die "passing block devices to this script is unsupported"
fi


get_partition() {
  echo -n "${1}p${2}"
}

SHIM_PATH="${1}"
OUT_PATH="${2}"
OUT_SIZE="128M"

rm ${OUT_PATH}
touch ${OUT_PATH}
truncate -s ${OUT_SIZE} ${OUT_PATH}

SHIM_DEV=$(losetup -Pf --show "${SHIM_PATH}")
OUT_DEV=$(losetup -Pf --show "${OUT_PATH}")

(
echo "g"
echo "n"
echo "2"
echo ""
echo "+33M"
echo "t"
echo "fe3a2a5d-4f32-41a7-b725-accc3285a309"
echo "n"
echo "3"
echo ""
echo "+64M"
echo "t"
echo "3"
echo "3cb8e202-3b7e-47dd-8a3c-7ff2a13cfcec"
echo "n"
echo "1"
echo ""
echo ""
echo "w"
) | fdisk ${OUT_DEV}

dd if=$(get_partition ${SHIM_DEV} 2) of=$(get_partition ${OUT_DEV} 2)
mkfs.ext4 $(get_partition ${OUT_DEV} 3)
mkfs.ext4 $(get_partition ${OUT_DEV} 1)
cgpt add -i 2 -S 1 -T 5 -P 10 -l kernel ${OUT_DEV} 

mkdir shimmnt
mount $(get_partition ${SHIM_DEV} 3) shimmnt -o ro

mkdir mnt
mount $(get_partition ${OUT_DEV} 3) mnt
tar xf terra-stage1.tar -C mnt
cp -r shimmnt/lib/modules/ mnt/lib/
umount shimmnt
umount mnt

mount $(get_partition ${OUT_DEV} 1) mnt
mkdir -p mnt/dev_image/etc/
touch mnt/dev_image/etc/lsb-factory
umount mnt
rm -r mnt shimmnt

losetup -d ${SHIM_DEV}
losetup -d ${OUT_DEV}
