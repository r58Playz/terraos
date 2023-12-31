#!/bin/bash

set +x

export_args() {
  # We trust our kernel command line explicitly.
  local arg=
  local key=
  local val=
  local acceptable_set='[A-Za-z0-9]_'
  for arg in "$@"; do
    key=$(echo "${arg%%=*}" | tr 'a-z' 'A-Z' | \
                   tr -dc "$acceptable_set" '_')
    val="${arg#*=}"
    export "KERN_ARG_$key"="$val"
  done
}

NOSCREENS=0
MAIN_TTY="/dev/pts/0"
DEBUG_TTY="/dev/pts/1"

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

hide_cursor() {
  printf '\x1b[?25l' >> "${1}"
}

show_cursor() {
  printf '\x1b[?25h' >> "${1}"
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
    kern_dev="$(blkid --match-token "PARTUUID=$KERN_ARG_KERN_GUID" -o device 2>/dev/null )"
    kern_num=${kern_dev##[/a-z]*[/a-z]}
    root_dev="${kern_dev%${kern_num}}"
    if [ -b "$root_dev" ]; then
      ROOT_DEV="$root_dev"
      ROOT_NUM="$((kern_num+1))"
      log "found: ${USB_DEV}"
      return 0
    fi
    sleep 1
  done
  log "failed."
  return 1
}

find_by_part_type() {
  lsblk -Aprn -o NAME,PARTUUID,PARTTYPE,PARTLABEL | sed '/\S\s\s\s/d' | grep -i "${1}"
}

find_usable_roots() {
  find_by_part_type 3cb8e202-3b7e-47dd-8a3c-7ff2a13cfcec | awk '{if ($4) print $1":"$4; else print $1}'
}

ROOT_DEV="/"
ROOT_NUM="2"

disable_input "${DEBUG_TTY}"
killall less script 

show_screen "boot/root/searching"

find_root || (
  show_screen "boot/root/failed"
  sleep 1d
  exit 1
)

show_screen "boot/mounting"

mkdir /data
mount "${ROOT_DEV}1" /data || (
  show_screen "boot/mount_failed"
  sleep 1d
  exit 1
)

show_screen "boot/starting"

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

action_boot_squash() {
  log "booting from squashfs ${1}..."
  
  show_screen "ui/bootloader/copying"

  mkdir /newroot
  mkdir /squashfs

  mount "${1}" /squashfs

  SQUASHFS_SIZE=$(du -sm /squashfs | cut -f 1)
  PV_SIZE=$(du -sb /squashfs | cut -f 1)
  SQUASHFS_SIZE=$(( SQUASHFS_SIZE + 256 ))

  log "tmpfs size: ${SQUASHFS_SIZE}M"
  log "pv size: ${PV_SIZE}"

  mount -t tmpfs -o size="${SQUASHFS_SIZE}M" tmpfs /newroot 

  tar -cf - -C /squashfs . | pv -fs "${PV_SIZE}" -w 96 | tar -xf - -C /newroot

  umount /squashfs

  show_screen "ui/bootloader/booting"

  boot_from_newroot
}

boot_from_newroot() {
  enable_input "${MAIN_TTY}"

  umount /data

  local mounts="/sys"

  if cat /newroot/etc/lsb-release 2>/dev/null | grep -i chromeos >/dev/null 2>/dev/null; then
    mounts="$mounts /proc"
    mount -o move /dev /newroot/dev
  else
    mounts="$mounts /dev /proc"
  fi

  # no dev after this point

  for mnt in $mounts; do
    umount -l $mnt
  done

  # fuck pivot_root (systemd buggy) and switch_root (doesn't work for some odd reason), let's do it ourselves
  exec /myswitchroot
}

action_bash() {
  log "opening bash..."
  clear_tty ${MAIN_TTY}
  show_cursor ${MAIN_TTY}
  setsid -c /bin/bash -i
  hide_cursor ${MAIN_TTY}
}

action_shutdown() {
  reboot -f
  sleep 1d
}

action_boot_squash_selector() {
  options=( /data/*.squashfs )
  enable_input "${MAIN_TTY}"
  selection=$(bash /assets/selector.sh "${options[*]}")
  disable_input "${MAIN_TTY}"
  if [[ $selection != 'exit' ]]; then
    # bash quirk? idk why but i can't index the array with the var so i use awk instead
    # awk starts at 1 not 0 i'm so dumb 
    squash=$(echo -n "${options[*]}" | awk "{printf \$$((selection+1))}")
    action_boot_squash "${squash}"
  fi
}

action_boot_partition_selector() {
  options=( "$(find_usable_roots | tr '\n' ' ')" )
  local root_part="${ROOT_DEV}${ROOT_NUM}"
  # using ^[ as the sed separator as that's an invalid character for both the path and GPT name
  options=( "$(echo "${options[*]}" | sed "s${root_part}:\S* " | sed "s${root_part} ")" )
  enable_input "${MAIN_TTY}"
  selection=$(bash /assets/selector.sh "${options[*]}")
  disable_input "${MAIN_TTY}"
  if [[ $selection != 'exit' ]]; then
    # bash quirk? idk why but i can't index the array with the var so i use awk instead
    # awk starts at 1 not 0 i'm so dumb 
    part=$(echo -n "${options[*]}" | awk "{printf \$$((selection+1))}" | sed "s/:.*//")
    action_boot_partition "${part}" 
  fi
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
          action_boot_squash_selector
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
      esac
      ;;
  esac
done

sleep 1d
