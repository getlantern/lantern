#include <stdio.h>

extern void swift_log(const char* message);

void log_to_swift(const char* message) {
    swift_log(message);
}