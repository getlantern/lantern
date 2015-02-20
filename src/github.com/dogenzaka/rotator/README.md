rotator
=======

[![Build Status](http://img.shields.io/travis/dogenzaka/rotator.svg?style=flat)](https://travis-ci.org/dogenzaka/rotator)
[![Coverage](http://img.shields.io/codecov/c/github/dogenzaka/rotator.svg?style=flat)](https://codecov.io/github/dogenzaka/rotator)
[![License](http://img.shields.io/badge/license-MIT-red.svg?style=flat)](https://github.com/dogenzaka/rotator/blob/master/LICENSE)

Rotator is a file writer which rotates by date and size. Rotator can be used any kind of files since it implments io.Writer.

```bash
go get github.com/dozenzaka/rotator
```

Size rotations
-----

Size based rotator will rotate target file when the size of the file is exceeded. Default size for the rotation is 10MiB.
When file is rotated, it will find available id for the file such as `rotated.log.5` and rename it.

```go
package main

import(
  "github.com/dogenzaka/rotator"
)

func main() {
  file := rotator.NewSizeRotator("/var/log/rotated.log")
  defer file.Close()
  file.Write([]byte("FIRST TEXT"))
  file.Write([]byte("SECOND TEXT"))
  file.WriteString("THIRD STRING")
}
```

To configure rotations, set properties of rotator instances.

```
file := rotator.NewSizeRotator("/var/log/rotated.log")
file.MaxRotation = 999 // Maximum counts of the file rotation. Default is 999
file.RotationSize = int64(1024*1024*10) // Size threashold which cause rotation. Default is 10MiB
```

Daily rotations
-----

Daily based rotator will rotate target file when the date is changed.
When file is rotated, it will rename the file to rotated name such as `rotated.log.2014-10-12`.

```go
package main

import (
  "github.com/dogenzaka/rotator"
)

func main() {
  file := rotator.NewDailyRotator("/var/log/rotated.log")
  defer file.Close()
  file.Write([]byte("FIRST TEXT"))
  file.Write([]byte("SECOND TEXT"))
  file.WriteString("THIRD STRING")
}
```

License
----
rotator is licensed under MIT

