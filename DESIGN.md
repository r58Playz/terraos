# Design

- TUI to maximize compatibility

## Boot process
0. Find shim root
1. Load config
2. Display boot menu 
   0. *All the tarballs in the rootfs folder*
   1. *All the detected partitions for localboot*
   2. Shutdown
3. Create tmpfs of size specified in the config
4. Extract the rootfs tarball
6. Exec the init command specified in config
