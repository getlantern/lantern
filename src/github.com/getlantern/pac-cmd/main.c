#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "common.h"

void usage(const char* binName)
{
  printf("Usage: %s [on  <pac url> | off [old pac url]]\n", binName);
  exit(INVALID_FORMAT);
}

int main(int argc, char* argv[]) {
  if (argc < 2) {
    usage(argv[0]);
  }

#ifdef DARWIN
  if (strcmp(argv[1], "setuid") == 0) {
    return setUid();
  }
#endif

  if (strcmp(argv[1], "on") == 0) {
    if (argc < 3) {
      usage(argv[0]);
    }
    return togglePac(true, argv[2]);
  } else if (strcmp(argv[1], "off") == 0) {
    return togglePac(false, argc < 3 ? "" : argv[2]);
  } else {
    usage(argv[0]);
  }
  // code never reaches here, just stops compiler from complain
  return RET_NO_ERROR;
}
