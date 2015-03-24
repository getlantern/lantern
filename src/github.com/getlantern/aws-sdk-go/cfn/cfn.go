// Package cfn provides functionality for creating AWS CloudFormation templates.
package cfn

// Version is the version of the CloudFormation templates supported by this
// package.
const Version = "2010-09-09"

// A Parameter is a value which can be passed into a template.
type Parameter struct {
	Type           string
	Default        string        `json:",omitempty"`
	NoEcho         bool          `json:",omitempty"`
	AllowedValues  []interface{} `json:",omitempty"`
	AllowedPattern string        `json:",omitempty"`
	MaxLength      int           `json:",omitempty"`
	MinLength      int           `json:",omitempty"`
	MaxValue       interface{}   `json:",omitempty"`
	MinValue       interface{}   `json:",omitempty"`
	Description    string        `json:",omitempty"`
}

// A Template describes a set of AWS resources which belong to a stack.
type Template struct {
	AWSTemplateFormatVersion string                 `json:",omitempty"`
	Description              string                 `json:",omitempty"`
	Parameters               map[string]Parameter   `json:",omitempty"`
	Mappings                 map[string]interface{} `json:",omitempty"`
	Conditions               map[string]interface{} `json:",omitempty"`
	Resources                Resources              `json:",omitempty"`
	Outputs                  map[string]Output      `json:",omitempty"`
}

// Resources is a set of named resources.
type Resources map[string]Resource

// An Output is a value based on the resources in a stack.
type Output struct {
	Value       interface{}
	Description string `json:",omitempty"`
}

// A Resource is an AWS resource.
type Resource struct {
	Type           string
	CreationPolicy *CreationPolicy `json:",omitempty"`
	DeletionPolicy DeletionPolicy  `json:",omitempty"`
	DependsOn      []interface{}   `json:",omitempty"`
	Metadata       interface{}     `json:",omitempty"`
	Properties     interface{}
	UpdatePolicy   *UpdatePolicy `json:",omitempty"`
}

// A CreationPolicy is associated with a resource to prevent its status from
// reaching create complete until AWS CloudFormation receives a specified number
// of success signals or the timeout period is exceeded.
type CreationPolicy struct {
	ResouceSignal *ResourceSignal `json:",omitempty"`
}

// A ResourceSignal determines how many signals are required by a CreationPolicy.
type ResourceSignal struct {
	Count   int    `json:",omitempty"`
	Timeout string `json:",omitempty"`
}

// A DeletionPolicy dictates what is to be done with a resource when it is
// deleted.
type DeletionPolicy string

const (
	// Delete is the default deletion policy, and will simply delete the
	// resource in question.
	Delete DeletionPolicy = "Delete"
	// Retain will not delete the resource in question.
	Retain DeletionPolicy = "Retain"
	// Snapshot will create a snapshot of the resource and then delete it. (Not
	// available for all resource types.)
	Snapshot DeletionPolicy = "Snapshot"
)

// An UpdatePolicy dictates how a resource should be updated.
type UpdatePolicy struct {
	AutoScalingRollingUpdate   *AutoScalingRollingUpdate   `json:",omitempty"`
	AutoScalingScheduledAction *AutoScalingScheduledAction `json:",omitempty"`
}

// An AutoScalingRollingUpdate policy specifies how AWS CloudFormation handles
// rolling updates for a particular resource.
type AutoScalingRollingUpdate struct {
	MaxBatchSize          string        `json:",omitempty"`
	MinInstancesInService string        `json:",omitempty"`
	PauseTime             string        `json:",omitempty"`
	SuspendProcesses      []interface{} `json:",omitempty"`
	WaitOnResourceSignals bool          `json:",omitempty"`
}

// An AutoScalingScheduledAction policy describes how AWS CloudFormation handles
// updates for the MinSize, MaxSize, and DesiredCapacity properties if an
// autoscaling group has an associated scheduled action.
type AutoScalingScheduledAction struct {
	IgnoreUnmodifiedGroupSizeProperties bool `json:",omitempty"`
}

// A Tag is a key and value pair.
type Tag struct {
	Key   interface{}
	Value interface{}
}

// NewTemplate returns a new, blank template with the given description.
func NewTemplate(desc string) *Template {
	return &Template{
		AWSTemplateFormatVersion: Version,
		Description:              desc,
		Resources:                map[string]Resource{},
	}
}
