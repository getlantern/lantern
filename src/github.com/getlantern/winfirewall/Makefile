c:
	i686-w64-mingw32-gcc cmd/main.c -o cmd/main.exe -DCINTERFACE -DCOBJMACROS -I. -L. -lole32 -loleaut32 -lhnetcfg

go:
	CC=i686-w64-mingw32-gcc CGO_ENABLED=1 GOOS=windows GOARCH=386 go build winfirewall.go
