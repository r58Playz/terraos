#!/bin/bash
# crossystem.sh v3.1.0
# made by r58Playz and stackoverflow
# emulates crossystem but with static values to trick brunch into thinking it is a valid chromebook with a valid everything
# rip ultrablue o7
# version history:
# v3.1.0 - modified crossystem.sh to fetch values from crossystem except for the devmode ones specifically for terraos
# v3.0.0 - implemented mutable crossystem values
# v2.0.0 - implemented all functionality
# v1.1.1 - hotfix for stupid crossystem
# v1.1.0 - implemented <var>?<value> functionality (searches for value in var)
# v1.0.0 - basic functionality implemented

# Mutable values path (needs to be writable and persistent across boots - try /mnt/stateful_partition)
mutablepath="/mnt/stateful_partition/mwtrollinggoogleforfakemurk"
#mutablepath="./mwtrollinggoogleforfakemurk"


csys() {
  out="$(crossystem.old "${1}" 2>/dev/null)"
  if grep -i usage <<<"${out}">/dev/null 2>/dev/null; then
    echo -n "(error)"
  else
    echo -n "${out}"
  fi
}

arch="$(csys arch)"
backup_nvram_request="$(csys backup_nvram_request)"
battery_cutoff_request="$(csys battery_cutoff_request)"
block_devmode="$(csys block_devmode)"
clear_tpm_owner_done="$(csys clear_tpm_owner_done)"
clear_tpm_owner_request="$(csys clear_tpm_owner_request)"
cros_debug="1"
dbg_reset="$(csys dbg_reset)"
debug_build="$(csys debug_build)"
dev_boot_legacy="0"
dev_boot_signed_only="1"
dev_boot_usb="0"
dev_default_boot="disk"
dev_enable_udc="0"
devsw_boot="0"
devsw_cur="0"
disable_alt_os_request="$(csys disable_alt_os_request)"
disable_dev_request="$(csys disable_dev_request)"
ecfw_act="$(csys ecfw_act)"
enable_alt_os_request="$(csys enable_alt_os_request)"
post_ec_sync_delay="$(csys post_ec_sync_delay)"
alt_os_enabled="0"
fmap_base="$(csys fmap_base)"
fw_prev_result="$(csys fw_prev_result)"
fw_prev_tried="$(csys fw_prev_tried)"
fw_result="$(csys fw_result)"
fw_tried="$(csys fw_tried)"
fw_try_count="$(csys fw_try_count)"
fw_try_next="$(csys fw_try_next)"
fw_vboot2="$(csys fw_vboot2)"
fwb_tries="$(csys fwb_tries)"
fwid="$(csys fwid)"
fwupdate_tries="$(csys fwupdate_tries)"
hwid="$(csys hwid)"
inside_vm="$(csys inside_vm)"
kern_nv="$(csys kern_nv)"
kernel_max_rollforward="$(csys kernel_max_rollforward)"
kernkey_vfy="$(csys kernkey_vfy)"
loc_idx="$(csys loc_idx)"
mainfw_act="A"
mainfw_type="normal"
nvram_cleared="$(csys nvram_cleared)"
oprom_needed="$(csys oprom_needed)"
phase_enforcement="$(csys phase_enforcement)"
recovery_reason="0"
recovery_request="$(csys recovery_request)"
recovery_subcode="0"
recoverysw_boot="0"
recoverysw_cur="(error)"
recoverysw_ec_boot="0"
recoverysw_is_virtual="$(csys recoverysw_is_virtual)"
ro_fwid="$(csys ro_fwid)"
tpm_attack="$(csys tpm_attack)"
tpm_fwver="$(csys tpm_fwver)"
tpm_kernver="$(csys tpm_kernver)"
tpm_rebooted="$(csys tpm_rebooted)"
tried_fwb="$(csys tried_fwb)"
try_ro_sync="$(csys try_ro_sync)"
vdat_flags="$(csys vdat_flags)"
vdat_timers="$(csys vdat_timers)"
wipeout_request="$(csys wipeout_request)"
wpsw_boot="$(csys wpsw_boot)"
wpsw_cur="$(csys wpsw_cur)"

##############################################################################################################################################################################
#                               YOU SHOULD NOT NEED TO MODIFY THIS PART OF THE SCRIPT IF YOU ARE JUST A CONSUMER! BELOW IS THE INTERNAL LOGIC!                               #
##############################################################################################################################################################################

# make sure the mutable crossystem file exists lol
touch $mutablepath
# just in case
chmod a+rw $mutablepath

# load values from mutable crossystem
# shellcheck disable=SC1090 # crossystem needs to source an external file for mutable values
source $mutablepath >/dev/null 2>&1

################################################
# v3 now autopopulates this for you. be happy! #
################################################
read -r -d '' cwossystem << EOM
arch                    = $arch                            # [RO/str] Platform architecture
backup_nvram_request    = $backup_nvram_request                              # [RW/int] Backup the nvram somewhere at the next boot. Cleared on success.
battery_cutoff_request  = $battery_cutoff_request                              # [RW/int] Cut off battery and shutdown on next boot
block_devmode           = $block_devmode                              # [RW/int] Block all use of developer mode
clear_tpm_owner_done    = $clear_tpm_owner_done                              # [RW/int] Clear TPM owner done
clear_tpm_owner_request = $clear_tpm_owner_request                              # [RW/int] Clear TPM owner on next boot
cros_debug              = $cros_debug                              # [RO/int] OS should allow debug features
dbg_reset               = $dbg_reset                              # [RW/int] Debug reset mode request
debug_build             = $debug_build                              # [RO/int] OS image built for debug features
dev_boot_legacy         = $dev_boot_legacy                              # [RW/int] Enable developer mode boot Legacy OSes
dev_boot_signed_only    = $dev_boot_signed_only                              # [RW/int] Enable developer mode boot only from official kernels
dev_boot_usb            = $dev_boot_usb                              # [RW/int] Enable developer mode boot from USB/SD
dev_default_boot        = $dev_default_boot                           # [RW/str] Default boot from disk, legacy or usb
dev_enable_udc          = $dev_enable_udc                              # [RW/int] Enable USB Device Controller
devsw_boot              = $devsw_boot                              # [RO/int] Developer switch position at boot
devsw_cur               = $devsw_cur                              # [RO/int] Developer switch current position
disable_alt_os_request  = $disable_alt_os_request                              # [RW/int] Disable Alt OS mode on next boot (writable)
disable_dev_request     = $disable_dev_request                              # [RW/int] Disable virtual dev-mode on next boot
ecfw_act                = $ecfw_act                             # [RO/str] Active EC firmware
enable_alt_os_request   = $enable_alt_os_request                              # [RW/int] Enable Alt OS mode on next boot (writable)
post_ec_sync_delay      = $post_ec_sync_delay                              # [RW/int] Short delay after EC software sync (persistent, writable, eve only)
alt_os_enabled          = $alt_os_enabled                              # [RO/int] Alt OS state (1 if enabled, 0 if disabled)
fmap_base               = $fmap_base                     # [RO/int] Main firmware flashmap physical address
fw_prev_result          = $fw_prev_result                        # [RO/str] Firmware result of previous boot (vboot2)
fw_prev_tried           = $fw_prev_tried                              # [RO/str] Firmware tried on previous boot (vboot2)
fw_result               = $fw_result                        # [RW/str] Firmware result this boot (vboot2)
fw_tried                = $fw_tried                              # [RO/str] Firmware tried this boot (vboot2)
fw_try_count            = $fw_try_count                              # [RW/int] Number of times to try fw_try_next
fw_try_next             = $fw_try_next                              # [RW/str] Firmware to try next (vboot2)
fw_vboot2               = $fw_vboot2                              # [RO/int] 1 if firmware was selected by vboot2 or 0 otherwise
fwb_tries               = $fwb_tries                              # [RW/int] Try firmware B count
fwid                    = $fwid       # [RO/str] Active firmware ID
fwupdate_tries          = $fwupdate_tries                              # [RW/int] Times to try OS firmware update (inside kern_nv)
hwid                    = $hwid # [RO/str] Hardware ID
inside_vm               = $inside_vm                              # [RO/int] Running in a VM?
kern_nv                 = $kern_nv                         # [RO/int] Non-volatile field for kernel use
kernel_max_rollforward  = $kernel_max_rollforward                     # [RW/int] Max kernel version to store into TPM
kernkey_vfy             = $kernkey_vfy                            # [RO/str] Type of verification done on kernel key block
loc_idx                 = $loc_idx                              # [RW/int] Localization index for firmware screens
mainfw_act              = $mainfw_act                              # [RO/str] Active main firmware
mainfw_type             = $mainfw_type                         # [RO/str] Active main firmware type
nvram_cleared           = $nvram_cleared                              # [RW/int] Have NV settings been lost?  Write 0 to clear
oprom_needed            = $oprom_needed                              # [RW/int] Should we load the VGA Option ROM at boot?
phase_enforcement       = $phase_enforcement                        # [RO/int] Board should have full security settings applied
recovery_reason         = $recovery_reason                              # [RO/int] Recovery mode reason for current boot
recovery_request        = $recovery_request                              # [RW/int] Recovery mode request
recovery_subcode        = $recovery_subcode                              # [RW/int] Recovery reason subcode
recoverysw_boot         = $recoverysw_boot                              # [RO/int] Recovery switch position at boot
recoverysw_cur          = $recoverysw_cur                        # [RO/int] Recovery switch current position
recoverysw_ec_boot      = $recoverysw_ec_boot                              # [RO/int] Recovery switch position at EC boot
recoverysw_is_virtual   = $recoverysw_is_virtual                              # [RO/int] Recovery switch is virtual
ro_fwid                 = $ro_fwid       # [RO/str] Read-only firmware ID
tpm_attack              = $tpm_attack                              # [RW/int] TPM was interrupted since this flag was cleared
tpm_fwver               = $tpm_fwver                     # [RO/int] Firmware version stored in TPM
tpm_kernver             = $tpm_kernver                     # [RO/int] Kernel version stored in TPM
tpm_rebooted            = $tpm_rebooted                              # [RO/int] TPM requesting repeated reboot (vboot2)
tried_fwb               = $tried_fwb                              # [RO/int] Tried firmware B before A this boot
try_ro_sync             = $try_ro_sync                              # [RO/int] try read only software sync
vdat_flags              = $vdat_flags                     # [RO/int] Flags from VbSharedData
vdat_timers             = $vdat_timers     # [RO/str] Timer values from VbSharedData
wipeout_request         = $wipeout_request                              # [RW/int] Firmware requested factory reset (wipeout)
wpsw_boot               = $wpsw_boot                              # [RO/int] Firmware write protect hardware switch position at boot
wpsw_cur                = $wpsw_cur                              # [RO/int] Firmware write protect hardware switch current position
EOM

parse1arg() {
    if [[ $1 == *"?"* ]]; then
        # comparison mode
        aft="${1#*\?}" # value to check for
        bef="${1%\?*}" # key
        if [[ "${!bef}" == *"$aft"* ]]; then
            return 0
        fi
        return 1
    elif [[ $1 == *"="* ]]; then
        # mutable crossystem mode (NEW)
        aft="${1#*\=}" # value to set
        bef="${1%\=*}" # key
        # check if value exists in mutable file
        containsvalue=$(source $mutablepath >/dev/null 2>&1; [[ -z "${!aft}" ]] && echo 1 || echo 0)
        if [[ $containsvalue -eq 0 ]]; then # crossystem.sh: line 181: 0: command not found
            sed -i "s/${bef}.*/${bef}=${aft}/" $mutablepath
        else
            echo "${bef}=${aft}" >> $mutablepath
        fi
    else
        # get value mode
        echo -n "${!1//$'\n'}"
    fi
}

logicor() {
    if [[ $1 -eq 1 ]]; then
        return 1
    elif [[ $2 -eq 1 ]]; then
        return 1
    else
        return 0
    fi
}

if [[ $# -eq 0 ]]; then
    echo -e "$cwossystem"
elif [[ $# -eq 1 ]]; then
    parse1arg "$1"
    exit $?
else
    for arg in "$@"; do
        parse1arg "$arg"
        excode="$?"
        logicor "$current_excode" "$excode"
        current_excode=$?
        echo -n " "
    done
    exit "$current_excode"
fi
