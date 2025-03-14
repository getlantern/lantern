package dart_api_dl

/*
#include <stdlib.h>
#include "stdint.h"
#include "include/dart_api_dl.c"

bool GoDart_PostCObject(Dart_Port_DL port, Dart_CObject* obj) {
   return Dart_PostCObject_DL(port, obj);
}
*/
import "C"
import (
	"fmt"
	"unsafe"
)

// Init initializes the Dart API DL bridge.
func Init(api unsafe.Pointer) {
	if C.Dart_InitializeApiDL(api) != 0 {
		panic("failed to initialize Dart DL C API: version mismatch" +
			"must update include/ to match Dart SDK version")
	}
}

// SendToPort sends a message to the given Dart port.
func SendToPort(port uint32, msg string) {
	var obj C.Dart_CObject
	obj._type = C.Dart_CObject_kString

	msgObj := C.CString(msg)
	defer C.free(unsafe.Pointer(msgObj))

	ptr := unsafe.Pointer(&obj.value[0])
	*(**C.char)(ptr) = msgObj
	// Send to Dart
	if !C.GoDart_PostCObject(C.Dart_Port_DL(port), &obj) {
		fmt.Println("SendToPort: Failed to send message to Dart.")
	}
}
