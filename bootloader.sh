#!/bash

set +x

NOSCREENS=0
MAIN_TTY="/dev/pts/0"
DEBUG_TTY="/dev/pts/1"
DATA_MNT="/mnt"
CONF_LOCATION="${DATA_MNT}/terra.conf"

# sane i/o
exec >>"${MAIN_TTY}" 2>&1
exec <"${MAIN_TTY}"

logf() {
  printf "${1}" >> "${DEBUG_TTY}"
}

log() {
  echo "${1}" >> "${DEBUG_TTY}"
}

disable_input() {
  printf '\x1b]input:off\a' >> "${1}"
}

enable_input() {
  printf '\x1b]input:on\a' >> "${1}"
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
DATA_NUM="1"

disable_input "${DEBUG_TTY}"
killall less script 

show_screen "boot/root/searching"

find_root || (
  show_screen "boot/root/failed"
  sleep 1d
  exit 1
)

show_screen "boot/starting"

mount "${ROOT_DEV}${DATA_NUM}" "${DATA_MNT}"

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

  mount "${1}" /newroot || (
    show_screen "ui/bootloader/mount_failed"
    sleep 1d
    exit 1;
  )

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
  enable_input "${MAIN_TTY}"
  # we don't need data anymore - if we don't unmount pivot_root will fail
  umount ${DATA_MNT}

  BASE_MOUNTS="/sys /proc /dev"
  for mnt in $BASE_MOUNTS; do
    umount -l $mnt
  done
  # fuck pivot_root (systemd buggy) and switch_root (doesn't work for some odd reason), let's do it ourselves
  cd /newroot
  mount -o move . /
  exec chroot . /bin/bash
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
  options=( "$(get_from_conf rootfs_files)" )
  enable_input "${MAIN_TTY}"
  selection=$(bash /assets/selector.sh "${options[*]}")
  disable_input "${MAIN_TTY}"
  if [ $selection -eq -1 ]; then
    return;
  fi
  action_boot_tar ${options[$selection]}
}

action_boot_partition_selector() {
  options=( "$(cgpt find -t rootfs | tr '\n' ' ')" )
  enable_input "${MAIN_TTY}"
  selection=$(bash /assets/selector.sh "${options[*]}")
  disable_input "${MAIN_TTY}"
  if [ $selection -eq -1 ]; then
    return;
  fi
  # bash quirk? idk why but i can't index the array with the var so i use awk instead
  # awk starts at 1 not 0 i'm so dumb 
  part=$(echo -n "${options[*]}" | awk "{printf \$$((selection+1))}")
  action_boot_partition $part 
}


CURRENT_OPTION=0
MAX_OPTIONS=4
while true; do
  show_screen "ui/options/${CURRENT_OPTION}"
  enable_input "${MAIN_TTY}"
  action="$(readinput)"
  disable_input "${MAIN_TTY}"
  case $action in
    "kU")
      CURRENT_OPTION=$(( CURRENT_OPTION - 1 ))
      if [[ "${CURRENT_OPTION}" -lt "0" ]]; then
        CURRENT_OPTION=$((MAX_OPTIONS-1))
      fi
      ;;
    "kD")
      CURRENT_OPTION=$(( CURRENT_OPTION + 1 ))
      if [[ "${CURRENT_OPTION}" -ge "${MAX_OPTIONS}" ]]; then
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
          enable_input "${MAIN_TTY}"
          action_bash
          disable_input "${MAIN_TTY}"
          ;;
        "3")
          action_shutdown
          ;;
      esac
      ;;
  esac
done

sleep 1d
