# terraOS
Run "real" Linux on a RMA shim.

## But why is "real" in quotes?
The original rootfs of the RMA shim is already Linux, however it does not have features such as WiFi, audio, and a graphical environment. TerraOS replaces the original rootfs with a "bootloader" that takes care of starting other rootfses with potentially different init systems as the initramfs passes flags to the init executable that only work on Upstart. As a result, you can freely customise the rootfs and use any init system.


## How do I use it?
- Clone this repository.
- Build the bootloader by running `sudo bash build.sh <input RMA shim> <output image path>`.
- Flash it to a USB.
- If you want to boot from squashfs, expand the 1st partition.
- Copy all squashfses you want to boot from into the 1st partition.
- For each rootfs you want to use with persistence, do these steps:
   - Create a new partition with type "ChromeOS rootfs" via fdisk or your favourite partitioning utility.
   - Format the partition.
   - Extract the tarball or bootstrap your rootfs as root into the root of the partition. If you are using `cp`, **make sure to use the `a` flag to preserve permissions and users**. To build the default rootfs, see [here](#how-do-i-build-the-terraos-rootfs).
   - Make sure the init program is at "/sbin/init" as that is the path that is executed.
   - TerraOS will autodetect all partitions on all GPT devices (including internal storage) with type "ChromeOS rootfs" and display them in a list that you can boot from.

## FAQ
### What works on the default rootfs?
`make_rootfs.sh` copies firmware and modules from the RMA shim and ALSA kernel module configurations from the recovery image, so most if not all features should work out of the box. If features do not work, see [here](#crowdsourced-list-of-compatibility).
- Systemd
- Graphics
- 3D Acceleration
- Audio (this is board dependent)
- WiFi (this is board dependent)

### Can I use a different distro?
Yes, you will need to either use a non-systemd distro or manually compile systemd with the [chromiumos patches](https://aur.archlinux.org/cgit/aur.git/tree/0002-Disable-mount_nofollow-for-ChromiumOS-kernels.patch?h=systemd-chromiumos). Then you can just follow the regular instructions and install your distro instead.

### Can I use this without a USB in?
Yes, you will need to create a "ChromeOS rootfs" partition on the internal storage and copy your rootfs there. In the future, there will be support for copying the filesystem to RAM.

### Where is my WiFi, audio, etc?!
Run `dmesg` and find the proper firmware for your board. Download it and manually add it to the rootfs. If you are using some exotic device it may not be in the RMA shim kernel. In that case you will have to compile the exact kernel version in the shim and then the module.

## How do I build the TerraOS rootfs?
**The password for the `terraos` user is `terraos`.**
```
sudo bash create_rootfs.sh <rootfs path - needs to be empty> <shim> <board recovery image> <systemd-chromiumos.pkg.tar.zst> <systemd-chromiumos-libs.pkg.tar.zst> <systemd-chromiumos-sysvcompat.pkg.tar.zst>
```

Then you can add extra firmware such as the ones from the crowdsourced list of firmware needed for WiFi below.

To build systemd-chromiumos:
```
git clone https://aur.archlinux.org/systemd-chromiumos
cd systemd-chromiumos
makepkg -Cs --skipinteg --nocheck
```

`sudo tar cajvf ../<filename> *` seems to create a sane tarball of the generated rootfses.
`sudo mksquashfs * ../<filename> -comp gzip` creates a squashfs image of the generated rootfs.

## How do I build ChromeOS for TerraOS?
```
sudo bash create_cros_persistent.sh <reven_recovery> <cros_recovery> <rma_shim> <path_to_image> 
```
The `path_to_image` must be a path to a file.


## How do I build terrastage1.tar.zst?
- Use the buildroot config located in this repo.

## Crowdsourced list of compatibility
If you get all features working on your TerraOS install, check here to make sure someone hasn't already posted data for your board and make a PR modifying this README.

### Octopus
All features work out of the box. Update your TerraOS rootfs, since this was fixed in a newer version.
