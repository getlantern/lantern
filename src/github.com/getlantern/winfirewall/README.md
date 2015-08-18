# Windows Firewall Interface

This library provides a Go interface for managing the Windows Firewall, using the Windows COM interface.


## Usage

<TODO>


## Internal documentation

### The C API

Normally Microsoft would expect that you would use C# for this sort of code. However, there is also documentation on how to access these APIs from C++. Accessing it from C is not well documented, but supported. Through code inspection, this conclusions can be reached:

In order to access _netfw.h_ C interface, the `CINTERFACE` and `COBJMACROS` must be used. This will effectively allow you to access the class methods through an interface like this:

```
ClassName_MethodName( Object, Arguments... )
```

### Building the code on MinGW

Besides defining the `CINTERFACE and `COBJMACROS`, the following libraries must be included:

* ole32
* oleaut32
* hnetcfg.dll

This last DLL is not provided by MinGW, so it is provided for allowing cross-compilation.


Example minimal MinGW GCC build line:

```
gcc myfile.c -DCINTERFACE -DCOBJMACROS -lole32 -loleaut32 -lhnetcfg
```



## Files in /doc folder

This folder keeps some files that should serve for documenting the process, since this library is touching internal parts of Windows and MinGW and required some fiddling.

These files are kept for documentation purposes:

* __cpp_api.c__: MSDN reference file that uses de C++ API.
* __netfw.h__: A reference implementation of netfw.h needed because MinGW didn't provide one. This had to be slighltly modified to compile properly.
