export GOOS=ios
export CGO_ENABLED=1

SDK_PATH=$(xcrun --sdk "$SDK" --show-sdk-path)

if [ "$GOARCH" = "amd64" ]; then
    CARCH="x86_64"
elif [ "$GOARCH" = "arm64" ]; then
    CARCH="arm64"
fi

if [ "$SDK" = "iphoneos" ]; then
  export TARGET="$CARCH-apple-ios$MIN_VERSION"
elif [ "$SDK" = "iphonesimulator" ]; then
  export TARGET="$CARCH-apple-ios$MIN_VERSION-simulator"
fi

CLANG=$(xcrun --sdk "$SDK" --find clang)
CC="$CLANG -target $TARGET -isysroot $SDK_PATH $@"
export CC

go build -trimpath -buildmode=c-archive -tags ios -o bin/${SDK}/${LIB_NAME}_${GOARCH}.a ./lantern-core/ffi

clang -c ios/Tunnel/Bridge.m -o bin/${SDK}/Bridge.o -arch ${CARCH} -isysroot $(xcrun --sdk ${SDK} --show-sdk-path)

libtool -static -o bin/${SDK}/${LIB_NAME}_${GOARCH}.a bin/${SDK}/${LIB_NAME}_${GOARCH}.a bin/${SDK}/Bridge.o