This folder contains a copy of Dart SDK [include/](https://github.com/dart-lang/sdk/tree/master/runtime/include)
folder.

Note that you might need to update if Dart SDK makes an incompatible change to its DL C API.

If such change is made then this example will start failing with

```
panic: failed to initialize Dart DL C API: version mismatch. must update include/ to match Dart SDK version
```
