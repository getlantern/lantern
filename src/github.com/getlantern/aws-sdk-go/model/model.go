// Package model contains functionality to generate clients for AWS APIs.
package model

import (
	"encoding/json"
	"fmt"
	"io"
	"regexp"
	"strings"
)

// Metadata contains various bits of metadata associated with an API.
type Metadata struct {
	APIVersion          string
	EndpointPrefix      string
	JSONVersion         string
	ServiceAbbreviation string
	ServiceFullName     string
	SignatureVersion    string
	TargetPrefix        string
	Protocol            string
	ChecksumFormat      string
	GlobalEndpoint      string
	TimestampFormat     string
}

// HTTPOptions contains the HTTP-specific options for an Operation.
type HTTPOptions struct {
	Method     string
	RequestURI string
}

// Operation is an API operation.
type Operation struct {
	Name          string
	Documentation string
	HTTP          HTTPOptions
	InputRef      *ShapeRef `json:"Input"`
	OutputRef     *ShapeRef `json:"Output"`
}

// Input returns the shape of the input parameter, if any.
func (o Operation) Input() *Shape {
	return o.InputRef.Shape()
}

// Output returns the shape of the output parameter, if any.
func (o Operation) Output() *Shape {
	return o.OutputRef.Shape()
}

// Error is an error returned by the API.
type Error struct {
	Code           string
	HTTPStatusCode int
	SenderFault    bool
}

// ShapeRef is a reference to a Shape.
type ShapeRef struct {
	ShapeName     string `json:"Shape"`
	Documentation string
	Location      string
	LocationName  string
	Wrapper       bool
	ResultWrapper string
	Streaming     bool
	XMLNamespace  XMLNamespace
}

// WrappedType returns the Go type of the reference shape, wrapped if a result
// wrapper was specified.
func (ref *ShapeRef) WrappedType() string {
	if ref.ResultWrapper != "" {
		return "*" + exportable(ref.ResultWrapper)
	}
	return ref.Shape().Type()
}

// WrappedLiteral returns an empty Go literal of the reference shape, wrapped if
// a result wrapper was specified.
func (ref *ShapeRef) WrappedLiteral() string {
	if ref.ResultWrapper != "" {
		return "&" + exportable(ref.ResultWrapper) + "{}"
	}
	return ref.Shape().Literal()
}

// Shape returns the wrapped shape.
func (ref *ShapeRef) Shape() *Shape {
	if ref == nil {
		return nil
	}
	return service.Shapes[ref.ShapeName]
}

// Member is a member of a shape.
type Member struct {
	ShapeRef
	Name     string
	Required bool
}

// JSONTag returns the field tag for JSON protocol members.
func (m Member) JSONTag() string {
	if m.ShapeRef.Location != "" || m.Name == "Body" {
		return "`json:\"-\"`"
	}
	if !m.Required {
		return fmt.Sprintf("`json:\"%s,omitempty\"`", m.Name)
	}
	return fmt.Sprintf("`json:\"%s\"`", m.Name)
}

// XMLTag returns the field tag for XML protocol members.
func (m Member) XMLTag(wrapper string) string {
	if m.ShapeRef.Location != "" || m.Name == "Body" {
		return "`xml:\"-\"`"
	}

	var path []string
	if wrapper != "" {
		path = append(path, wrapper)
	}

	if m.LocationName != "" {
		path = append(path, m.LocationName)
	} else {
		path = append(path, m.Name)
	}

	if m.Shape().ShapeType == "list" {
		loc := m.Shape().MemberRef.LocationName
		if loc != "" {
			path = append(path, loc)
		}
	}

	// We can't omit all empty values, because encoding/xml makes it impossible
	// to marshal pointers to empty values.
	// https://github.com/golang/go/issues/5452
	if m.Shape().ShapeType == "list" || m.Shape().ShapeType == "structure" {
		return fmt.Sprintf("`xml:%q`", strings.Join(path, ">")+",omitempty")
	}

	return fmt.Sprintf("`xml:%q`", strings.Join(path, ">"))
}

// QueryTag returns the field tag for Query protocol members.
func (m Member) QueryTag(wrapper string) string {
	var path, prefix []string
	if wrapper != "" {
		path = append(path, wrapper)
	}

	if !m.Shape().Flattened {
		if m.LocationName != "" {
			prefix = append(prefix, m.LocationName)
			path = append(path, m.LocationName)
		} else {
			prefix = append(prefix, m.Name)
			path = append(path, m.Name)
		}
	}

	if m.Shape().ShapeType == "list" || m.Shape().ShapeType == "map" {
		locPrefix := "member"
		if m.Shape().ShapeType == "map" {
			locPrefix = "entry"
		}

		if !m.Shape().Flattened {
			prefix = append(prefix, locPrefix)
		} else {
			if ref := m.Shape().MemberRef; ref != nil {
				prefix = append(prefix, ref.LocationName)
			} else {
				prefix = append(prefix, m.LocationName)
			}
		}

		var loc string
		if ref := m.Shape().MemberRef; ref != nil {
			loc = ref.LocationName
		} else {
			loc = m.LocationName
		}
		if loc == "" {
			loc = locPrefix
		}
		path = append(path, loc)
	}

	return fmt.Sprintf(
		"`query:%q xml:%q`",
		strings.Join(prefix, "."),
		strings.Join(path, ">"),
	)
}

// EC2Tag returns the field tag for EC2 protocol members.
func (m Member) EC2Tag() string {
	var path []string
	if m.LocationName != "" {
		path = append(path, m.LocationName)
	} else {
		path = append(path, m.Name)
	}

	if m.Shape().ShapeType == "list" {
		loc := m.Shape().MemberRef.LocationName
		if loc == "" {
			loc = "member"
		}
		path = append(path, loc)
	}

	// Literally no idea how to distinguish between a location name that's
	// required (e.g. DescribeImagesRequest#Filters) and one that's weirdly
	// misleading (e.g. ModifyInstanceAttributeRequest#InstanceId) besides this.

	// Use the locationName unless it's missing or unless it starts with a
	// lowercase letter. Not even making this up.
	var name = m.LocationName
	if name == "" || strings.ToLower(name[0:1]) == name[0:1] {
		name = m.Name
	}

	return fmt.Sprintf("`ec2:%q xml:%q`", name, strings.Join(path, ">"))
}

// Shape returns the member's shape.
func (m Member) Shape() *Shape {
	return m.ShapeRef.Shape()
}

// Type returns the member's Go type.
func (m Member) Type() string {
	if m.Streaming {
		return "io.ReadCloser" // this allows us to pass the S3 body directly
	}
	return m.Shape().Type()
}

// An XMLNamespace is an XML namespace. *shrug*
type XMLNamespace struct {
	URI string
}

// Shape is a type used in an API.
type Shape struct {
	Box             bool
	Documentation   string
	Enum            []string
	Error           Error
	Exception       bool
	Fault           bool
	Flattened       bool
	KeyRef          *ShapeRef `json:"Key"`
	LocationName    string
	Max             int
	MemberRef       *ShapeRef           `json:"Member"`
	MemberRefs      map[string]ShapeRef `json:"Members"`
	Min             int
	Name            string
	Pattern         string
	Payload         string
	Required        []string
	Sensitive       bool
	Streaming       bool
	TimestampFormat string
	ShapeType       string    `json:"Type"`
	ValueRef        *ShapeRef `json:"Value"`
	Wrapper         bool
	XMLAttribute    bool
	XMLNamespace    XMLNamespace
	XMLOrder        []string
}

var enumStrip = regexp.MustCompile(`[()\s]`)
var enumDelims = regexp.MustCompile(`[-_:\./]+`)
var enumCamelCase = regexp.MustCompile(`([a-z])([A-Z])`)

// Enums returns a map of enum constant names to their values.
func (s *Shape) Enums() map[string]string {
	if s.Enum == nil {
		return nil
	}

	fix := func(s string) string {
		s = enumStrip.ReplaceAllLiteralString(s, "")
		s = enumCamelCase.ReplaceAllString(s, "$1-$2")
		parts := enumDelims.Split(s, -1)
		for i, v := range parts {
			v = strings.ToLower(v)
			parts[i] = exportable(v)
		}
		return strings.Join(parts, "")
	}

	enums := map[string]string{}
	name := exportable(s.Name)
	for _, e := range s.Enum {
		if e != "" {
			enums[name+fix(e)] = fmt.Sprintf("%q", e)
		}
	}

	return enums
}

// Key returns the shape's key shape, if any.
func (s *Shape) Key() *Shape {
	return s.KeyRef.Shape()
}

// KeyXMLTag returns the field tag for key.
func (s *Shape) KeyXMLTag() string {
	if s.ShapeType != "map" || s.KeyRef == nil {
		return ""
	}

	if s.KeyRef.LocationName == "" {
		return "`xml:\"key\"`"
	}
	return fmt.Sprintf("`xml:\"%s\"`", s.KeyRef.LocationName)
}

// ValueXMLTag returns the field tag for value.
func (s *Shape) ValueXMLTag() string {
	if s.ShapeType != "map" || s.ValueRef == nil {
		return ""
	}

	if s.ValueRef.LocationName == "" {
		return "`xml:\"value\"`"
	}
	return fmt.Sprintf("`xml:\"%s\"`", s.ValueRef.LocationName)
}

// Value returns the shape's value shape, if any.
func (s *Shape) Value() *Shape {
	return s.ValueRef.Shape()
}

// Member returns the shape's member shape, if any.
func (s *Shape) Member() *Shape {
	return s.MemberRef.Shape()
}

// Members returns the shape's members.
func (s *Shape) Members() map[string]Member {
	required := func(v string) bool {
		for _, s := range s.Required {
			if s == v {
				return true
			}
		}
		return false
	}

	members := map[string]Member{}
	for name, ref := range s.MemberRefs {
		members[name] = Member{
			Name:     name,
			Required: required(name),
			ShapeRef: ref,
		}
	}
	return members
}

// ResultWrapper returns the shape's result wrapper, if and only if a single,
// unambiguous wrapper can be found in the API's operation outputs.
func (s *Shape) ResultWrapper() string {
	var wrappers []string

	for _, op := range service.Operations {
		if op.OutputRef != nil && op.OutputRef.ShapeName == s.Name {
			wrappers = append(wrappers, op.OutputRef.ResultWrapper)
		}
	}

	if len(wrappers) == 1 {
		return wrappers[0]
	}

	return ""
}

// Literal returns a Go literal of the given shape.
func (s *Shape) Literal() string {
	if s.ShapeType == "structure" {
		return "&" + s.Type()[1:] + "{}"
	}
	panic("trying to make a literal non-structure for " + s.Name)
}

// ElementType returns the Go type of the shape as an element of another shape
// (i.e., list or map).
func (s *Shape) ElementType() string {
	switch s.ShapeType {
	case "structure":
		return exportable(s.Name)
	case "integer":
		return "int"
	case "long":
		return "int64"
	case "float":
		return "float32"
	case "double":
		return "float64"
	case "string":
		return "string"
	case "map":
		if service.Metadata.Protocol == "query" {
			return exportable(s.Name)
		}
		return "map[" + s.Key().ElementType() + "]" + s.Value().ElementType()
	case "list":
		return "[]" + s.Member().ElementType()
	case "boolean":
		return "bool"
	case "blob":
		return "[]byte"
	case "timestamp":
		return "time.Time"
	}

	panic(fmt.Errorf("type %q (%q) not found", s.Name, s.ShapeType))
}

// Type returns the shape's Go type.
func (s *Shape) Type() string {
	switch s.ShapeType {
	case "structure":
		return "*" + exportable(s.Name)
	case "integer":
		if s.Name == "ContentLength" || s.Name == "Size" {
			return "aws.LongValue"
		}
		return "aws.IntegerValue"
	case "long":
		return "aws.LongValue"
	case "float":
		return "aws.FloatValue"
	case "double":
		return "aws.DoubleValue"
	case "string":
		return "aws.StringValue"
	case "map":
		if service.Metadata.Protocol == "query" {
			return exportable(s.Name)
		}
		return "map[" + s.Key().ElementType() + "]" + s.Value().ElementType()
	case "list":
		return "[]" + s.Member().ElementType()
	case "boolean":
		return "aws.BooleanValue"
	case "blob":
		return "[]byte"
	case "timestamp":
		// JSON protocol APIs use Unix timestamps
		if service.Metadata.Protocol == "json" {
			return "*aws.UnixTimestamp"
		}
		return "time.Time"
	}

	panic(fmt.Errorf("type %q (%q) not found", s.Name, s.ShapeType))
}

// A Service is an AWS service.
type Service struct {
	Name          string
	FullName      string
	PackageName   string
	Metadata      Metadata
	Documentation string
	Operations    map[string]Operation
	Shapes        map[string]*Shape
}

// Wrappers returns the service's wrapper shapes.
func (s Service) Wrappers() map[string]*Shape {
	wrappers := map[string]*Shape{}

	// collect all wrapper types
	for _, op := range s.Operations {
		if op.InputRef != nil && op.InputRef.ResultWrapper != "" {
			wrappers[op.InputRef.ResultWrapper] = op.Input()
		}

		if op.OutputRef != nil && op.OutputRef.ResultWrapper != "" {
			wrappers[op.OutputRef.ResultWrapper] = op.Output()
		}
	}

	// remove all existing types?
	for name := range wrappers {
		if _, ok := s.Shapes[name]; ok {
			delete(wrappers, name)
		}
	}

	return wrappers
}

var service Service

// Load parses the given JSON input and loads it into the singleton instance of
// the package.
func Load(name string, r io.Reader) error {
	service = Service{}
	if err := json.NewDecoder(r).Decode(&service); err != nil {
		return err
	}

	for name, shape := range service.Shapes {
		shape.Name = name
	}

	service.FullName = service.Metadata.ServiceFullName
	service.PackageName = strings.ToLower(name)
	service.Name = name

	return nil
}
