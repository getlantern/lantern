package wintunmgr

import (
	"encoding/json"

	"github.com/getlantern/lantern/lantern-core/common"
)

// IPC structs
type Request struct {
	ID     string          `json:"id"`
	Cmd    common.Command  `json:"cmd"`
	Params json.RawMessage `json:"params,omitempty"`
	Token  string          `json:"token,omitempty"`
}

type Response struct {
	ID     string      `json:"id"`
	Result interface{} `json:"result,omitempty"`
	Error  *RPCError   `json:"error,omitempty"`
}

type RPCError struct {
	Code    string `json:"code"`
	Message string `json:"message"`
}

func rpcErr(id, code, msg string) *Response {
	return &Response{ID: id, Error: &RPCError{Code: code, Message: msg}}
}
