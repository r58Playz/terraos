#include <unistd.h>

int main() {
	char* argv[3] = {"/bin/bash", "/bootloader.sh", NULL};
	execv(argv[0],argv);
	return 0;
}
