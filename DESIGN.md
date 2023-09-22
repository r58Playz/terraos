# Design
## Boot process
0. Find shim root
1. Load config
2. Display boot options, from now on assume that the user selected boot normally
   0. Boot normally (default)
   1. Boot into shim
   2. Shutdown
3. Create tmpfs of size specified in the config
4. Extract the rootfs tarball
6. Exec the init command specified in config
