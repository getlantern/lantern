package issue12403

type Parsable interface {
	FromJSON(jstr string) string
	ToJSON() (string, error)
}
