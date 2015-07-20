default: generate

install-gen:
	go install ./cmd/...

generate: install-gen
	go generate ./gen
	go install ./gen/...
