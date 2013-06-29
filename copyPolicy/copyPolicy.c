#define _GNU_SOURCE
#include <dirent.h>
#include <fcntl.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

#include <sys/stat.h>
#include <sys/types.h>

#ifdef _WIN32
#include <windows.h>
ssize_t sendfile(int out_fd, int in_fd, off_t *offset, size_t count) {
    printf("Wrong OS\n");
    exit(0);
}

//this is a total hack
int asprintf(char** strp, const char *format, ...) {
    *strp = malloc(10000);
    va_list args;
    va_start (args, format);
    int result = vsprintf (*strp, format, args);
    va_end (args);
    return result;
}

#else
#include <sys/utsname.h>
#include <sys/sendfile.h>
#endif

typedef enum {
    macintosh, 
    gnu_linux, //not political; linux is #defined somewhere
    windows
} os;

static os detect_os() {

#ifdef _WIN32

    return windows;
#else
    struct utsname name;
    uname (&name);
    if (strncmp("Linux", name.sysname, 5) == 0) {
        return gnu_linux;
    } else if (strncmp("Darwin", name.sysname, 6) == 0) {
        return macintosh;
    } else {
        return windows;
    }
#endif
}

const char* MAC_JVM_PREFIXES [] = {
    "/System/Library/Java/JavaVirtualMachines/",
    "/Library/Java/JavaVirtualMachines/",
    0
};

const char* MAC_LANTERN_PATHS [] = {
    "/Applications/Lantern.app/Contents/java/app",
    "/Applications/Lantern/Lantern.app/Contents/java/app",
    0
};

const char* POLICY_JARS [] = {
    "local_policy.jar",
    "US_export_policy.jar",
    0
};

int is_dir(const char* path) {
    DIR* dh = opendir(path);
    if (dh) {
        closedir(dh);
        return 1;
    } else {
        return 0;
    }
}

char* get_policy_path(os the_os, int version) {
    switch(the_os) {
    case macintosh:
        for (const char** prefix = MAC_JVM_PREFIXES; *prefix; ++prefix) {
            char* full_path;
            asprintf(&full_path, "%s/java%d", *prefix, version);
            if (is_dir(full_path)) {
                return full_path;
            } else {
                free(full_path);
            }
        }
        break;
    case gnu_linux:
        /*
          This is unnecessary, since paths are fixed
         */
        break;
    case windows:
#ifdef windows
#define BUF_SIZE 100000
        char  username[BUF_SIZE];
        long size;

        bufCharCount = INFO_BUFFER_SIZE;
        GetUserName(username,&size);
        username[size] = 0;

        char* path;
        asprintf(&path, "C:\\Documents and Settings\\%s\\Application Data\\Lantern\\java7", username);
        if (is_dir(path)) {
            return path;
        } else {
            free(freepath);
        }
        
        path =  "C:\\Program Files\\Lantern\\java7";
        if (is_dir(path)) {
            return path;
        }

#else
        printf("Incorrectly detected OS as Windows\n");
        exit(3);
#endif
        break;
    }

    return NULL;

}

int copy_file(const char* src, const char* dest) {
    int in_fd = open(src, O_RDONLY);
    if (in_fd == -1) 
        return 1;
    int out_fd = open(dest, O_WRONLY | O_TRUNC | O_CREAT);
    if (out_fd == -1) {
        close(in_fd);
        return 1;
    }

    struct stat statbuf;
    fstat(in_fd, &statbuf);

    off_t off = 0;
    sendfile(out_fd, in_fd, &off, (size_t)statbuf.st_size);

    close(in_fd);
    close(out_fd);
    return 0;
}


int copy_policy_files(const char* java_home, os the_os, int version) {
    char* policy_path = get_policy_path(the_os, version);
    
    for (const char** policy_jar = POLICY_JARS; *policy_jar; ++ policy_jar) {
        char* policy_file_source_path;
        char* policy_file_destination_path;
        asprintf(&policy_file_source_path, "%s/%s", policy_path, *policy_jar);
        asprintf(&policy_file_destination_path, "%s/lib/security/%s", java_home, *policy_jar);

        int result = copy_file(policy_file_source_path, policy_file_destination_path);

        free(policy_file_destination_path);
        free(policy_file_source_path);
        if (result) {
            free(policy_path);
            return 1;
        }
    }

    free(policy_path);
    return 0;
}


int main(int argc, char** argv) {

    os the_os = detect_os();
    const char* java_home;

    switch(the_os) {
    case macintosh:
        /*
          We need to install the appropriate version of the policy
          files for the currently-running JVM.  Unfortunately, there
          is not a straightforward way to get this JVM.  In general,
          we can't trust that the correct value will be reported on
          the command-line.  But we can check that the directory given
          on the command-line (a) exists, (b) contains a lib/security
          directory, and (c) has a prefix of
          /System/Library/Java/JavaVirtualMachines or
          /Library/Java/JavaVirtualMachines.  (these are the two
          standard prefixes).

          FIXME: it would be better to use the system key store so
          that parts of Lantern can communicate securely with each
          other. But this would be a giant nightmare to code.

         */

        if (argc != 3) {
            printf("Required arguments: path to JAVA_HOME, version of java\n");
            return 1;
        }

        char* endptr;
        long int version = strtol (argv[2], &endptr, 10);
        if (*endptr != '\0' && (version != 6 || version != 7)) {
            printf("Version number must be a number (either 6 or 7)\n");
            return 2;
        }

        java_home = argv[1];
        for (const char** prefix = MAC_JVM_PREFIXES; *prefix; ++prefix) {
            if (strncmp(*prefix, java_home, strlen(*prefix)) == 0) {
                if (copy_policy_files(java_home, the_os, version)) {
                    printf("Failed to copy policy files\n");
                    return 5;
                } else {
                    return 0;
                }
            }
        }
        printf("Failed to copy policy files: prefix mismatch\n");
        return -1;
    case gnu_linux:
        if (copy_file("/opt/lantern/java6/local_policy.jar", "/opt/lantern/jre/lib/security/local_policy.jar")) {
            perror("Failed to copy policy files");
            return 5;
        }
        if (copy_file("/opt/lantern/java6/US_export_policy.jar", "/opt/lantern/jre/lib/security/US_export_policy.jar")) {
            perror("Failed to copy policy files");
            return 5;
        }
        return 0;

    case windows:
        /* FIXME: assumes Java 7 */

        if (argc != 2) {
            printf("Required arguments: path to JAVA_HOME\n");
            return 1;
        }

        java_home = argv[1];
        const char* prefix = "c:\\program files\\java\\";
        if (strncmp(prefix, java_home, strlen(prefix)) != 0) {
            printf("Not a valid Java path\n");
            return -1;
        }
        if (copy_policy_files(java_home, the_os, 7)) {
            printf("Failed to copy policy files\n");
            return 5;
        }

        return 0;
    }
}
