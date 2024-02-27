set -e
if [ $# -lt 3 ]; then
  echo "usage: build_all.sh shim.bin board_recovery.bin reven_recovery.bin"
  exit 1
fi

if [ ${EUID} -ne 0 ]; then
  echo "this script must be run as root" >&2
  exit 1
fi

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

bash ${SCRIPT_DIR}/build_rootfs.sh arch_rootfs "${1}" "${2}"
bash ${SCRIPT_DIR}/build_bootloader.sh "${1}" bootloader.img
bash ${SCRIPT_DIR}/build_arch_only.sh arch_rootfs
bash ${SCRIPT_DIR}/build_cros_persistent.sh "${3}" "${2}" "${1}" bootloader.img terra_chromeos.img
zstd -k terra_chromeos.img
zip terra_chromeos.img.zip terra_chromeos.img
bash ${SCRIPT_DIR}/build_arch_chromeos.sh arch_rootfs
(
  cd arch_rootfs;
  mksquashfs * ../terra_arch_gzip.squashfs
  mksquashfs * ../terra_arch_zstd.squashfs -comp zstd -Xcompression-level 22
  tar caf ../terra_arch.tar.gz *
  tar caf ../terra_arch.tar.zst *
)
