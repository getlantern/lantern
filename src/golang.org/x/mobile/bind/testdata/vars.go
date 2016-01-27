package vars

var (
	AString = "String"

	AnInt         = -1
	AnInt8  int8  = 8
	AnInt16 int16 = 16
	AnInt32 int32 = 32
	AnInt64 int64 = 64

	AFloat           = -2.0
	AFloat32 float32 = 32.0
	AFloat64 float64 = 64.0

	ABool = true

	AStructPtr  *S
	AnInterface I
)

type S struct{}

type I interface{}
