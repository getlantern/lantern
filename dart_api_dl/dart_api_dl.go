package dart_api_dl

/*
#include "stdint.h"
#include "include/dart_api_dl.c"
// Helper: Posts a C string message to a Dart port.
static inline bool postLogMessage(Dart_Port port, const char* message) {
    Dart_CObject cobj;
    cobj.type = Dart_CObject_kString;
    cobj.value.as_string = (char*) message;
    return Dart_PostCObject(port, &cobj);
}

bool GoDart_PostCObject(Dart_Port_DL port, Dart_CObject* obj) {
   return Dart_PostCObject_DL(port, obj);
}
*/
import "C"
import "unsafe"

func Init(api unsafe.Pointer) {
	if C.Dart_InitializeApiDL(api) != 0 {
		panic("failed to initialize Dart DL C API: version mismatch. " +
			"must update include/ to match Dart SDK version")
	}
}

func SendToPort(port int64, msg string) {
	var obj C.Dart_CObject
	obj._type = C.Dart_CObject_kString
	msg_obj := C.CString(msg)
	// cgo does not support unions so we are forced to do this
	ptr := unsafe.Pointer(&obj.value[0])
	*(**C.char)(ptr) = msg_obj
	C.GoDart_PostCObject(C.Dart_Port_DL(port), &obj)
}
