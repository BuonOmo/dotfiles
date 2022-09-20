#!/usr/bin/env -S gcc git.c -o git -O3
// https://stackoverflow.com/a/73232182/6320039

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

#define MAX(x, y) (((x) > (y)) ? (x) : (y))

char* shellescape(const char* str);

int main(int argc, char *argv[]) {
	char *base;
	int size = 64;
	char *cmd = calloc(size, sizeof(char));
	int ret;

	if (isatty(fileno(stdout)) && isatty(fileno(stderr))) {
		base = "GIT_EXTERNAL_DIFF=difft /usr/bin/git";
	} else {
		base = "/usr/bin/git";
	}

	size -= strlen(base);
	strcat(cmd, base);

	for (int i = 1; i < argc; i++) {
		char *escaped = shellescape(argv[i]);
		int arg_size = strlen(escaped) + 1;
		if (arg_size >= size) {
			cmd = realloc(cmd, (MAX(arg_size, 64) + strlen(cmd)) * sizeof(char));
			size += MAX(arg_size, 64);
		}

		strcat(cmd, " ");
		strcat(cmd, escaped);
		size -= arg_size;
		free(escaped);
	}

	// printf(" == %s ==\n", cmd);
	ret = system(cmd);
	return WEXITSTATUS(ret);
}

// https://stackoverflow.com/a/11854550/6320039
char* shellescape(const char* str) {
	char *rv;
	int i,
		count = strlen(str),
		ptr_size = count+3;

	rv = (char *) calloc(ptr_size, sizeof(char));
	if (rv == NULL) {
		return NULL;
	}
	sprintf(rv, "'");

	for(i=0; i<count; i++) {
		if (str[i] == '\'') {
					ptr_size += 3;
			rv = (char *) realloc(rv,ptr_size * sizeof(char));
			if (rv == NULL) {
				return NULL;
			}
			sprintf(rv, "%s'\\''", rv);
		} else {
			sprintf(rv, "%s%c", rv, str[i]);
		}
	}

	sprintf(rv, "%s%c", rv, '\'');
	return rv;
}
