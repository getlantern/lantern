all: checkin vet check-gofmt

check-gofmt:
	scripts/check_gofmt.sh

checkin:
	go test -run "TestCheckin*" ./client

test:
	go test ./... -p=1

build:
	go build ./...

vet:
	go vet ./...
