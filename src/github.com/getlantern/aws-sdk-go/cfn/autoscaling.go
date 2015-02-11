package cfn

import "time"

// An AutoScalingGroup resource creates an Auto Scaling group.
type AutoScalingGroup struct {
	AvailabilityZones         interface{}
	Cooldown                  string      `json:",omitempty"`
	DesiredCapacity           int         `json:",omitempty"`
	HealthCheckGracePeriod    int         `json:",omitempty"`
	HealthCheckType           string      `json:",omitempty"`
	InstanceID                string      `json:"InstanceId,omitempty"`
	LaunchConfigurationName   interface{} `json:",omitempty"`
	LoadBalancerNames         []string    `json:",omitempty"`
	MaxSize                   int
	MetricsCollection         []MetricsCollection `json:",omitempty"`
	MinSize                   int
	NotificationConfiguration *NotificationConfiguration `json:",omitempty"`
	PlacementGroup            string                     `json:",omitempty"`
	Tags                      []AutoScalingTag           `json:",omitempty"`
	TerminationPolicies       []string                   `json:",omitempty"`
	VPCZoneIdentifier         []string                   `json:",omitempty"`
}

// The NotificationConfiguration property is an embedded property of the
// AWS::AutoScaling::AutoScalingGroup resource that specifies the events for
// which the Auto Scaling group sends notifications.
type NotificationConfiguration struct {
	NotificationTypes string
	TopicARN          []string
}

// The MetricsCollection is a property of the AutoScalingGroup resource that
// describes the group metrics that an Auto Scaling group sends to CloudWatch.
type MetricsCollection struct {
	Granularity string
	Metrics     []string `json:",omitempty"`
}

// An AutoScalingTag is like a regular tag, but can propagate to ASG instances
// when they launch.
type AutoScalingTag struct {
	Key               string
	Value             string
	PropagateAtLaunch bool
}

// The LaunchConfiguration resource creates an Auto Scaling launch configuration
// that can be used by an Auto Scaling group to configure Amazon EC2 instances
// in the Auto Scaling group.
type LaunchConfiguration struct {
	AssociatePublicIPAddress bool                 `json:"AssociatePublicIpAddress,omitempty"`
	BlockDeviceMappings      []BlockDeviceMapping `json:",omitempty"`
	EBSOptimized             bool                 `json:"EbsOptimized,omitempty"`
	IAMInstanceProfile       string               `json:"IamInstanceProfile,omitempty"`
	ImageID                  string               `json:"ImageId"`
	InstanceID               string               `json:"InstanceId,omitempty"`
	InstanceMonitoring       *bool                `json:",omitempty"`
	InstanceType             string
	KernelID                 string      `json:"KernelId,omitempty"`
	KeyName                  string      `json:",omitempty"`
	RAMDiskID                string      `json:"RamDiskId,omitempty"`
	SecurityGroups           interface{} `json:",omitempty"`
	SpotPrice                string      `json:",omitempty"`
	UserData                 []byte      `json:",omitempty"`
}

// The BlockDeviceMapping type is an embedded property of the
// LaunchConfiguration type.
type BlockDeviceMapping struct {
	DeviceName  string
	EBS         *EBSBlockDevice `json:"Ebs,omitempty"`
	NoDevice    bool            `json:",omitempty"`
	VirtualName string          `json:",omitempty"`
}

// The EBSBlockDevice type is an embedded property of the AutoScaling Block
// Device Mapping type.
type EBSBlockDevice struct {
	DeleteOnTermination bool   `json:",omitempty"`
	IOPS                int    `json:",omitempty"`
	SnapshotID          string `json:"SnapshotId,omitempty"`
	VolumeSize          int    `json:",omitempty"`
	VolumeType          string `json:",omitempty"`
}

// Possible values for ScalingPolicy's AdjustmentType.
const (
	ChangeInCapacityAdjustment        = "ChangeInCapacity"
	ExactCapacityAdjustment           = "ExactCapacity"
	PercentChangeInCapacityAdjustment = "PercentChangeInCapacity"
)

// A ScalingPolicy specifies whether to scale the auto scaling group up or down,
// and by how much.
type ScalingPolicy struct {
	AdjustmentType       string
	AutoScalingGroupName interface{}
	Cooldown             string `json:",omitempty"`
	ScalingAdjustment    string
}

// ScheduledAction creates a scheduled scaling action for an Auto Scaling group,
// changing the number of servers available for your application in response to
// predictable load changes.
type ScheduledAction struct {
	AutoScalingGroupName interface{}
	DesiredCapacity      int       `json:",omitempty"`
	EndTime              time.Time `json:",omitempty"`
	MaxSize              int       `json:",omitempty"`
	MinSize              int       `json:",omitempty"`
	Recurrence           time.Time `json:",omitempty"`
	StartTime            time.Time `json:",omitempty"`
}
