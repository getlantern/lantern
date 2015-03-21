package cfn

// The CloudTrail resource creates a trail and specifies where logs are
// published. A CloudTrail trail can capture AWS API calls made by your AWS
// account and publishes the logs to an Amazon S3 bucket.
type CloudTrail struct {
	IncludeGlobalServiceEvents bool `json:",omitempty"`
	IsLogging                  bool
	S3BucketName               interface{}
	S3KeyPrefix                interface{} `json:",omitempty"`
	SNSTopicName               interface{} `json:"SnsTopicName,omitempty"`
}
