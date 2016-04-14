package utils

import (
	"fmt"
	"io"
	"net/http"
)

func RespondOK(writer io.Writer, req *http.Request) error {
	defer func() {
		if err := req.Body.Close(); err != nil {
			fmt.Printf("Error closing body of OK response: %s", err)
		}
	}()

	resp := &http.Response{
		StatusCode: http.StatusOK,
		ProtoMajor: 1,
		ProtoMinor: 1,
	}

	return resp.Write(writer)
}

func RespondBadGateway(w io.Writer, req *http.Request, msgs ...string) {
	defer func() {
		if err := req.Body.Close(); err != nil {
			fmt.Printf("Error closing body of OK response: %s", err)
		}
	}()

	resp := &http.Response{
		StatusCode: http.StatusBadGateway,
		ProtoMajor: 1,
		ProtoMinor: 1,
	}
	err := resp.Write(w)
	if err == nil {
		for _, msg := range msgs {
			if _, err = w.Write([]byte(msg)); err != nil {
				fmt.Printf("Error writing error to io.Writer: %s", err)
			}
		}
	}
}
