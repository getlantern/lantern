package Test

type Struct struct {
	Field1, Field2 int
	field3         string
	field4         *bool
}

func NewStruct() *Struct {
	return &Struct{}
}

func (s Struct) F1() ([]bool, [2]*string) {
}

func (Struct) F2() (result bool) {
}

type TestEmbed struct {
	Struct
	*io.Writer
}

func NewTestEmbed() TestEmbed {
}

type Struct2 struct {
}

func NewStruct2() (*Struct2, error) {
}

func Dial() (*Connection, error) {
}

type Connection struct {
}

func Dial2() (*Connection, *Struct2) {
}

func Dial3() (a, b *Connection) {
}
