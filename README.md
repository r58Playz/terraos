# terraOS
Run "real" Linux on a RMA shim.

### But why is "real" in quotes?
The original rootfs of the RMA shim is already Linux, however it does not have features such as WiFi, audio, and a graphical environment. TerraOS replaces the original rootfs with a "bootloader" that takes care of starting other rootfses with potentially different init systems as the initramfs passes flags to the init executable that only work on Upstart. As a result, you can freely customise the rootfs and use any init system.
