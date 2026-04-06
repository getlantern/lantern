package main

import "C"

import (
	"encoding/json"
	"fmt"
	"os"

	"google.golang.org/protobuf/proto"
	"google.golang.org/protobuf/reflect/protoreflect"
)

func sendJson(resp any) *C.char {
	b, _ := json.Marshal(resp)
	return C.CString(string(b))
}

func SendError(err error) *C.char {
	if err == nil {
		return C.CString("")
	}
	return sendJson(map[string]interface{}{
		"error": err.Error(),
	})
}

// create binary data from proto
func CreateBinaryFile(name string, data protoreflect.ProtoMessage) error {
	b, err := proto.Marshal(data)
	if err != nil {
		return err
	}

	fileName := fmt.Sprintf("%s.bin", name)
	if err := os.WriteFile(fileName, b, 0644); err != nil {
		return err
	}
	return nil
}
