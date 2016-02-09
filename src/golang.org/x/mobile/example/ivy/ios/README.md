# Ivy iOS App source

This directory contains the source code to the Ivy iOS app.

To build, first create the mobile.framework out of the Go
implementation of Ivy. Run:

```
go get robpike.io/ivy
gomobile bind -target=ios robpike.io/ivy/mobile
```

Place the mobile.framework directory in this directory, and
then open ivy.xcodeproj in Xcode.
