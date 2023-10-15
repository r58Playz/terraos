// c :heart_mauve:

#include <stdio.h>
#include <string.h>
#include <sys/mount.h>
#include <sys/stat.h>
#include <sys/syscall.h>
#include <unistd.h>

int main() {
  // who needs error checking huh
  printf("right uhh um i'm gonna have to hack the shim. technical. uhmm you'll need to turn around while i do this.\nturn around, i'll only be a second. if you would mind.\nwould you mind uhh putting your back towards me so i can see only your back\ngo on just turn right the way around so you're not looking at me\n");
  mkdir("/newroot/mnt", 0770);
  chdir("/newroot");
  syscall(SYS_pivot_root,".",".");
  if(umount2(".", MNT_DETACH)) {
    printf("failed to umount old root!!\n");
  }
  //mountsystemd();
  char *argv[] = { "/sbin/init", NULL };
  printf("done! hacked.\n");
  execv(argv[0], argv);
  return 0;
}
