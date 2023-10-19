# terraOS
Run "real" Linux on a RMA shim.

### But why is "real" in quotes?
The original rootfs of the RMA shim is already Linux, however it does not have features such as WiFi, audio, and a graphical environment. TerraOS replaces the original rootfs with a "bootloader" that takes care of starting other rootfses with potentially different init systems as the initramfs passes flags to the init executable that only work on Upstart. As a result, you can freely customise the rootfs and use any init system.

### How do I build the original TerraOS rootfs?
- `sudo pacstrap -iK <path> base linux-firmware networkmanager xfce4 xfce4-goodies sddm pipewire pipewire-jack wireplumber sof-firmware mesa-amber firefox noto-fonts which sudo vim`
- Build and install `systemd-chromiumos` from the AUR
- Make user `terraos`, give it sudo with no password perms
- Create `kill-frecon.service`
```ini
[Unit]
Description=Tell frecon to kill itself

[Service]
Type=simple
ExecStart=/usr/bin/killall frecon-lite

[Install]
WantedBy=basic.target
```
- Enable `sddm`, `NetworkManager`, `kill-frecon`
- Copy firmware from RMA shim
- Copy modules from RMA shim
- Copy modprobe.d from board recovery image
- Download iwlwifi-9000-pu-b0-jf-b0-41.ucode and place in firmware folder
