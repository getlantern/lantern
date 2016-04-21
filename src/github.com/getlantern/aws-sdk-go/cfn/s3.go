package cfn

// An S3Bucket is a collection of blobs on S3.
type S3Bucket struct {
	AccessControl        string
	BucketName           interface{}
	LoggingConfiguration *S3LoggingConfiguration `json:",omitempty"`
	Tags                 []Tag                   `json:",omitempty"`
}

// An S3LoggingConfiguration configures logging for S3 buckets.
type S3LoggingConfiguration struct {
	DestinationBucketName interface{}
	LogFilePrefix         string `json:",omitempty"`
}

// An S3BucketPolicy is a policy for an S3 bucket.
type S3BucketPolicy struct {
	Bucket         interface{}
	PolicyDocument map[string]interface{}
}
