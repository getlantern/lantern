# Windows Firewall Interface

This library provides Go with an interface for managing the Windows Firewall, using the Windows COM interface.


## Usage

See the [test program in Go](cmd/main.go) or the [test program](cmd/main.c) in C.

## Internal documentation

### The C API

Normally Microsoft would expect that you would use the C++ API. Accessing it from C is not well documented, but supported.

In order to access _netfw.h_ C interface, the `CINTERFACE` and `COBJMACROS` must be used. This will effectively allow you to access the class methods through an interface like this:

```
ClassName_MethodName( Object, Arguments... )
```

The C API wraps calls to the old Firewall API (*compat_xp* prefix) and the new *Advanced Security COM API* (*ascom* prefix).


### Building the code on MinGW

The code is largely in C, so a C program is provided for testing the API. Besides defining the `CINTERFACE` and `COBJMACROS`, the following libraries must be included:

* ole32.lib
* oleaut32.lib
* hnetcfg.dll

This last DLL is not provided by MinGW, so it is bundled with the library to allow cross-compilation. This one will provide the symbols normally provided by *FirewallAPI.dll* in more mothern versions of Windows.


Example minimal MinGW GCC build line:

```
mingw-gcc myfile.c -DCINTERFACE -DCOBJMACROS -lole32 -loleaut32 -lhnetcfg
```

In Go, configuration should be automatic thorugh CGO, so just providing the right C compiler backend should suffice:

```
CC=mingw-gcc CGO_ENABLED=1 GOOS=windows GOARCH=386 go build -o cmd/test-go.exe cmd/main.go
```

As before, substitute *mingw-gcc* for your MinGW binary.


### Files in /doc folder

This folder keeps some files that should serve for documenting the process, since this library is touching internal parts of Windows and MinGW and required some fiddling.

These files are kept for documentation purposes:

* **cpp_api.c**: MSDN reference file that uses de C++ API.
* **netfw.h**: A reference implementation of netfw.h needed because MinGW didn't provide one. This had to be slighltly modified to compile properly.
* **netfw-xp.h**: A modified version of netfw.h that works with MinGW. It only supports the old API for Windows XP.
* **WinXPSP2FireWall.{h,c}**: A reference implementation of the Firewall API for Windows XP, which has a more sparse documentation over the Internet.
