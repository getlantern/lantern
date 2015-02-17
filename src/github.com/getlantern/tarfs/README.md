tarfs
=====

tarfs provides a mechanism for embedding resources into Go executables. It was
created as an alternative to [go-bindata](https://github.com/jteeuwen/go-bindata)
and [go-bindata-assetfs](https://github.com/elazarl/go-bindata-assetfs) that
compiles more quickly, especially when embedding a large number of files.

Parts of the implementation of tarfs are taken from go-bindata-assetfs.

Look at [build.bash](demo/build.bash) to build the demo and see how it works.