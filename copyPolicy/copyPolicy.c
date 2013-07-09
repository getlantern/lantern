#define _GNU_SOURCE
#include <ctype.h>
#include <dirent.h>
#include <fcntl.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

#include <sys/stat.h>
#include <sys/types.h>

#include "policy_jars.h"

#ifdef _WIN32
#include <windows.h>

//this is a total hack
int asprintf(char** strp, const char *format, ...) {
  *strp = malloc(10000);
  va_list args;
  va_start (args, format);
  int result = vsprintf (*strp, format, args);
  va_end (args);
  return result;
}
#endif

const char* POLICY_JARS [] = {
  "local_policy.jar",
  "US_export_policy.jar",
    0
};

int file_exists_and_is_owned_by_root(const char* filename) {
  //file exists (and has at least one byte)
  FILE* in_fp = fopen(filename, "rb");
  if (!in_fp) {
    printf("No existing file to overwrite: %s\n", filename);
    return 0;
  }
  int c = fgetc(in_fp);
  if (c == EOF) {
    printf("Existing file has no contents %s\n", filename);
    fclose(in_fp);
    return 0;
  }
  fclose(in_fp);

#ifdef _WIN32
  // on Windows, we'll ignore the owner and lstat checks
  // since setuid does not exist

  return 1;
#else

  struct stat info;
  if (lstat(filename, &info)) {
    printf("Can't lstat %s\n", filename);
    return 0;
  }

  if (S_ISLNK(info.st_mode)) {
    printf("Is symlink %s\n", filename);
    //symlinks are forbidden
    return 0;
  }

  if (info.st_uid==geteuid()) {
    return 1;
  } else {
    printf("Wrong owner %s\n", filename);
    return 0;
  }
#endif
}

/*
write _len_ bytes from _data_ to the file named _dest_
*/
int write_file(const char* data, const int len, const char* dest) {
  FILE* out_fp = fopen(dest, "wb");
  if (!out_fp) {
    char* error_message;
    asprintf(&error_message,"failed to open output file %s for writing", dest);
    perror(error_message);
    free(error_message);
    return 1;
  }

  size_t wrc = fwrite(data, 1, len, out_fp);
  if (wrc != len) {
    //too few bytes copied
    printf("Too few bytes copied to %s\n", dest);
    fclose(out_fp);
    return 1;
  }

  if (ferror(out_fp)) {
    perror("Error reading or writing");
    fclose(out_fp);
    return 1;
  }
  fclose(out_fp);
  return 0;
}

int main(int argc, char** argv) {
  if (argc != 2) {
    printf("Required argument: path to JAVA_HOME\n");
    return 1;
  }
  for (int i = 0; POLICY_JARS[i]; ++i) {
    const char* jar = POLICY_JARS[i];
    char* dest;
    asprintf(&dest, "%s/lib/security/%s", argv[1], jar);
    if (file_exists_and_is_owned_by_root(dest)) {
      const char* data = POLICY_JAR_CONTENTS[i];
      int len = POLICY_JAR_LEN[i];
      if (write_file(data, len, dest)) {
          return 1;
      }
    }
  }
  return 0;
}
