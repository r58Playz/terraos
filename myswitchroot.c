// c :heart_mauve:

#include <errno.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/mount.h>
#include <sys/syscall.h>
#include <unistd.h>

void xchdir(const char *path) {
  if(chdir(path)) {
    printf("failed to chdir to %s: %s\n", path, strerror(errno));
    exit(1);
  }
}

void pivot_root(const char *from, const char *to) {
  if(syscall(SYS_pivot_root,from,to)) {
    printf("failed to pivot_root from %s to %s: %s\n", from, to, strerror(errno));
    exit(1);
  }
}

void xumount2(const char *target, int flags) {
  if(umount2(target, flags)) {
    printf("failed to umount %s: %s", target, strerror(errno));
    exit(1);
  }
}

void xexecv(const char *path, char *const argv[]) {
  if(execv(argv[0], argv)) {
    printf("failed to exec %s: %s", path, strerror(errno));
  }
}

int main(int argc, char *argv[]) {
  if(argc>1) {
    printf("right uhh um i'm gonna have to hack the shim. technical. uhmm you'll need to turn around while i do this.\nturn around, i'll only be a second. if you would mind.\nwould you mind uhh putting your back towards me so i can see only your back\ngo on just turn right the way around so you're not looking at me\n");
  }
  xchdir("/newroot");
  pivot_root(".",".");
  xumount2(".", MNT_DETACH);
  if(argc>1) {
    printf("done! hacked.\n");
  }
  char *cmd[] = { "/sbin/init", NULL };
  xexecv(cmd[0], cmd);
  return 0;
}
