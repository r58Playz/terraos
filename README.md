# terraOS
Run "real" Linux on a RMA shim.

### But why is "real" in quotes?
The original rootfs of the RMA shim is already Linux, however it does not have features such as WiFi, audio, and a graphical environment. TerraOS replaces the original rootfs with a "bootloader" that takes care of starting other rootfses with potentially different init systems as the initramfs passes flags to the init executable that only work on Upstart. As a result, you can freely customise the rootfs and use any init system.

### How do I build the original TerraOS rootfs?
- Use [my buildroot fork](https://github.com/r58Playz/buildroot)'s `terraos` branch with the defconfig `terraos_defconfig`.
- Copy firmware from RMA shim
- Copy modules from RMA shim
- Copy modprobe.d from board recovery image
- Download iwlwifi-9000-pu-b0-jf-b0-41.ucode and place in firmware folder
