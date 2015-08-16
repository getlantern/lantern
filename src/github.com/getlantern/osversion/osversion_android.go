package osversion

/*
#include <sys/system_properties.h>
#include <stdio.h>
#include <stdlib.h>

int android_get_prop_value_max() {
   return PROP_VALUE_MAX;
}

int android_get_release(char *sdk_ver_str) {
    int result = __system_property_get("ro.build.version.release", sdk_ver_str);
    return result;
}

int android_get_api(char *sdk_ver_str) {
    int result = __system_property_get("ro.build.version.sdk", sdk_ver_str);
    return result;
}
*/
import "C"

import (
	"errors"
	"fmt"
	"strconv"
	"unsafe"
)

func GetString() (string, error) {
	strSize := int(C.android_get_prop_value_max())
	verStr := (*C.char)(C.malloc(C.size_t(strSize)))
	defer C.free(unsafe.Pointer(verStr))
	C.android_get_release(verStr)
	return C.GoString(verStr), nil
}

func GetHumanReadable() (string, error) {
	// First get the semantic versioning scheme
	verStr, err := GetString()
	if err != nil {
		return verStr, err
	}

	// Then get the release name
	strSize := int(C.android_get_prop_value_max())
	apiStr := (*C.char)(C.malloc(C.size_t(strSize)))
	defer C.free(unsafe.Pointer(apiStr))
	C.android_get_api(apiStr)

	i, err := strconv.ParseUint(C.GoString(apiStr), 10, 16)
	if err != nil {
		return verStr, err
	}

	if i > 22 {
		return verStr, errors.New("Unknown Android API version")
	}

	return fmt.Sprintf("%s %s", versions[i-1], verStr), nil
}

var versions = []string{
	"",                    // 1
	"",                    // 2
	"Cupcake",             // 3
	"Donut",               // 4
	"Eclair",              // 5
	"Eclair",              // 6
	"Eclair",              // 7
	"Froyo",               // 8
	"Gingerbread",         // 9
	"Gingerbread",         // 10
	"Honeycomb",           // 11
	"Honeycomb",           // 12
	"Honeycomb",           // 13
	"Ice Cream Sandwhich", // 14
	"Ice Cream Sandwhich", // 15
	"Jelly Bean",          // 16
	"Jelly Bean",          // 17
	"Jelly Bean",          // 18
	"KitKat",              // 19
	"KitKat",              // 20
	"Lollipop",            // 21
	"Lollipop",            // 22
}
