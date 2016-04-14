package cfn

// An Alarm resource creates an CloudWatch alarm.
type Alarm struct {
	ActionsEnabled          interface{} `json:",omitempty"`
	AlarmActions            []string    `json:",omitempty"`
	AlarmDescription        string      `json:",omitempty"`
	AlarmName               string      `json:",omitempty"`
	ComparisonOperator      string
	Dimensions              []MetricDimension `json:",omitempty"`
	EvaluationPeriods       string
	InsufficientDataActions []string `json:",omitempty"`
	MetricName              string
	Namespace               string
	OKActions               []string `json:",omitempty"`
	Period                  string
	Statistic               string
	Threshold               string
	Unit                    string `json:",omitempty"`
}

// The MetricDimension is an embedded property of the AWS::CloudWatch::Alarm
// type. Dimensions are arbitrary name/value pairs that can be associated with a
// CloudWatch metric.
type MetricDimension struct {
	Name  string
	Value interface{}
}
