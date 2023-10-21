# terraOS
Run "real" Linux on a RMA shim.

### But why is "real" in quotes?
The original rootfs of the RMA shim is already Linux, however it does not have features such as WiFi, audio, and a graphical environment. TerraOS replaces the original rootfs with a "bootloader" that takes care of starting other rootfses with potentially different init systems as the initramfs passes flags to the init executable that only work on Upstart. As a result, you can freely customise the rootfs and use any init system.

### FAQ
**Where is my WiFi, audio, etc?!**

Run `dmesg` and find the proper firmware for your board. Download it and manually add it to the rootfs. If you are using some exotic device it may not be in the RMA shim kernel. In that case you will have to compile the exact kernel version in the shim and then the module.

### How do I build the original TerraOS rootfs?
```
sudo bash create_rootfs.sh <path> <shim> <board recovery image> <systemd-chromiumos.pkg.tar.zst> <systemd-chromiumos-libs.pkg.tar.zst> <systemd-chromiumos-sysvcompat.pkg.tar.zst>
```

Then you can add extra firmware such as the ones from the crowdsourced list of firmware needed for WiFi below.

Manual instructions:

- `sudo pacstrap -iK <path> base linux-firmware networkmanager network-manager-applet xfce4 xfce4-goodies lightdm-gtk-greeter pulseaudio pavucontrol alsa-utils sof-firmware mesa-amber firefox noto-fonts which sudo vim neofetch`
- Build and install `systemd-chromiumos` from the AUR (ideally running makepkg on the host system and copying only the built packages to the rootfs)
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
- Enable `lightdm`, `NetworkManager`, `kill-frecon`
- Copy firmware from RMA shim
- Copy modules from RMA shim
- Copy modprobe.d from board recovery image
- Place any missing firmware files into the firmware folder (for octopus I included `iwlwifi-9000-pu-b0-jf-b0-41.ucode`)

`sudo tar cajvf ../<filename> *` seems to create a sane tarball of the generated rootfses.


## How do I build terrastage1.tar.zst?
- Extract the shim kernel with binwalk until you get to the cpio archive.
- Move `/init` to `/sbin/init`
- Edit it so it instead runs `exec /bootloader.sh` after `setup_environment` in the `main` function

## Crowdsourced list of firmware needed for WiFi
If you get WiFi working on your TerraOS install, check here to make sure someone hasn't already posted instructions for your board and make a PR modifying this section of the README.

### Octopus
Download `iwlwifi-9000-pu-b0-jf-b0-41.ucode` and place into firmware folder.
