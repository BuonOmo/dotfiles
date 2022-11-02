///usr/bin/env gcc ${0} -o ${0%%.c} -O3 && exit 0
// https://stackoverflow.com/a/73232182/6320039

#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>

int main(int argc, char *argv[]) {
	isatty(fileno(stdout)) && isatty(fileno(stderr)) &&
		setenv("GIT_EXTERNAL_DIFF", "difft", 1);
	execvp("/opt/homebrew/bin/git", argv);
}
