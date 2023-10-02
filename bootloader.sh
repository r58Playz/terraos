#!/bash

set +x

NOSCREENS=1
MAIN_TTY="/dev/pts/0"
DEBUG_TTY="/dev/pts/1"
DATA_MNT="/mnt"
CONF_LOCATION="${DATA_MNT}/terra.conf"

# sane i/o
exec &>>"${MAIN_TTY}"
exec <"${MAIN_TTY}"

logf() {
  printf "${1}" >> "${DEBUG_TTY}"
}

log() {
  echo "${1}" >> "${DEBUG_TTY}"
}

disable_input() {
  printf '\x1b]input:off' >> "${1}"
}

enable_input() {
  printf '\x1b]input:on' >> "${1}"
}

hide_input() {
  printf '\x1b[?25l\x1b[8m' >> "${1}"
}

show_input() {
  printf '\x1b[?25h\x1b[28m' >> "${1}"
}

clear_tty() {
  printf '\x1b[2J\x1b[H' >> "${1}"
}

show_screen() {
  if [[ "${NOSCREENS}" == "1" ]]; then
    clear_tty ${MAIN_TTY}
    echo "screen: ${1}"
  else
    clear_tty ${MAIN_TTY}
    source "/assets/${1}"
  fi
}

# https://chromium.googlesource.com/chromiumos/platform/initramfs/+/refs/heads/master/factory_shim/bootstrap.sh#75
find_root() {
  [ -z "$KERN_ARG_KERN_GUID" ] && return 1
  logf "finding root with kern_guid \"$KERN_ARG_KERN_GUID\" "
  local try kern_dev kern_num
  local root_dev 
  for try in $(seq 20); do
    # crbug.com/463414: when the cgpt supports MTD (cgpt.bin), redirecting its
    # output will get duplicated data.
    kern_dev="$(cgpt find -1 -u $KERN_ARG_KERN_GUID 2>/dev/null | uniq)"
    kern_num=${kern_dev##[/a-z]*[/a-z]}
    root_dev="${kern_dev%${kern_num}}"
    if [ -b "$root_dev" ]; then
      ROOT_DEV="$root_dev"
      ROOT_NUM="$kern_num"
      log "found: ${USB_DEV}"
      return 0
    fi
    sleep 1
  done
  log "failed."
  return 1
}

get_from_conf() {
  cat "${2:-${CONF_LOCATION}}" | sed -e '/^#.*$/d' -e '/^$/d' | grep "${1}" | sed -e "s/${1}\\=\"//" -e 's/"$//'
}

ROOT_DEV="/"
ROOT_NUM="2"

disable_input "${MAIN_TTY}"
disable_input "${DEBUG_TTY}"

show_screen "boot/root/searching"

find_root || (
  show_screen "boot/root/failed"
  sleep 1d
  exit 1
)

show_screen "boot/starting"

mount "${ROOT_DEV}$(( ROOT_NUM + 2 ))" "${DATA_MNT}"

readinput() {
	read -rsn1 mode

	case $mode in
		'') read -rsn2 mode ;;
		'') echo kB ;;
		'') echo kE ;;
		*) echo $mode ;;
	esac

	case $mode in
		'[A') echo kU ;;
		'[B') echo kD ;;
		'[D') echo kL ;;
		'[C') echo kR ;;
	esac
}

action_boot_partition() {
  log "booting from partition ${1}..."

  show_screen "ui/bootloader/mounting"

  mkdir /newroot

  mount "${1}" /newroot

  show_screen "ui/bootloader/booting"

  boot_from_newroot 
}

action_boot_tar() {
  log "booting from tar ${1}..."

  show_screen "ui/bootloader/copying"

  mkdir /newroot
  mount -t tmpfs -o size="$(get_from_conf rootfs_size ${1}.conf)" none /newroot 

  tar xf "${DATA_MNT}/${1}" -C /newroot

  show_screen "ui/bootloader/booting"

  boot_from_newroot
}

boot_from_newroot() {
  BASE_MOUNTS="/sys /proc /dev"
  for mnt in $BASE_MOUNTS; do
    mkdir -p "/newroot$mnt"
    mount -n -o move "$mnt" "/newroot$mnt"
  done
  mkdir /newroot/initramfs
  pivot_root /newroot /newroot/initramfs
  exec /sbin/init <"${DEBUG_TTY}" >>"${DEBUG_TTY}" 2>&1
}

action_bash() {
  log "opening bash..."
  clear_tty ${MAIN_TTY}
  /bash  
}

action_shutdown() {
  exit 0
}

action_boot_tar_selector() {
  action_boot_tar $(bash /assets/selector.sh $(get_from_conf rootfs_files))
}

action_boot_partition_selector() {
  action_boot_partition $(bash /assets/selector.sh $(cgpt find -t rootfs | tr '\n' ' '))
}


CURRENT_OPTION=0
MAX_OPTIONS=4

while 1; do
  show_screen "ui/options/${CURRENT_OPTION}"
  case "$(readinput)" in
    "kU")
      CURRENT_OPTION=$(( CURRENT_OPTION - 1 ))
      if [[ "${CURRENT_OPTION}" == "-1" ]]; then
        CURRENT_OPTION=$MAX_OPTIONS
      fi
      ;;
    "kD")
      CURRENT_OPTION=$(( CURRENT_OPTION + 1 ))
      if [[ "${CURRENT_OPTION}" == "${MAX_OPTIONS}" ]]; then
        CURRENT_OPTION=0
      fi
      ;;
    "kE")
      case "${CURRENT_OPTION}" in
        "0")
          action_boot_tar_selector
          ;;
        "1")
          action_boot_partition_selector
          ;;
        "2")
          action_bash
          ;;
        "3")
          action_shutdown
          ;;
      esac
      ;;
  esac
done

sleep 1d
