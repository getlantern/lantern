package cfn

// A LoadBalancer is an EC2 Elastic LoadBalancer (ELB).
type LoadBalancer struct {
	Name                     string   `json:"LoadBalancerName"`
	AvailabilityZones        []string `json:",omitempty"`
	CrossZone                bool
	Scheme                   string                    `json:",omitempty"`
	Subnets                  []string                  `json:",omitempty"`
	SecurityGroups           []interface{}             `json:",omitempty"`
	AccessLoggingPolicy      *AccessLoggingPolicy      `json:",omitempty"`
	ConnectionDrainingPolicy *ConnectionDrainingPolicy `json:",omitempty"`
	HealthCheck              *HealthCheck              `json:",omitempty"`
	Listeners                []Listener                `json:",omitempty"`
	Policies                 []LoadBalancerPolicy      `json:",omitempty"`
	Tags                     []Tag                     `json:",omitempty"`
}

// A HealthCheck determines if an instance registered with a load balancer is
// healthy.
type HealthCheck struct {
	HealthyThreshold   interface{} `json:",omitempty"`
	Interval           interface{} `json:",omitempty"`
	Target             interface{} `json:",omitempty"`
	Timeout            interface{} `json:",omitempty"`
	UnhealthyThreshold interface{} `json:",omitempty"`
}

// A Listener accepts connections for a load balancer and routes them to an
// instance port.
type Listener struct {
	InstancePort     interface{}   `json:",omitempty"`
	LoadBalancerPort interface{}   `json:",omitempty"`
	Protocol         interface{}   `json:",omitempty"`
	InstanceProtocol interface{}   `json:",omitempty"`
	SSLCertificateID interface{}   `json:",omitempty"`
	PolicyNames      []interface{} `json:",omitempty"`
}

// An AccessLoggingPolicy configures how the load balancer logs requests.
type AccessLoggingPolicy struct {
	LogEveryNMinutes int `json:"EmitInterval,omitempty"`
	Enabled          bool
	S3BucketName     string
	S3BucketPrefix   string
}

// A ConnectionDrainingPolicy configures how long the load balancer will wait
// before removing an instance from rotation.
type ConnectionDrainingPolicy struct {
	Enabled        bool
	TimeoutSeconds int `json:"Timeout,omitempty"`
}

// A LoadBalancerPolicy configures some other arbitrary bits of load balancer
// behavior, like proxy protocol support and TLS config.
type LoadBalancerPolicy struct {
	Name              string                        `json:"PolicyName"`
	Type              string                        `json:"PolicyType"`
	Attributes        []LoadBalancerPolicyAttribute `json:",omitempty"`
	InstancePorts     []int                         `json:",omitempty"`
	LoadBalancerPorts []int                         `json:",omitempty"`
}

// A LoadBalancerPolicyAttribute is an attribute of a LoadBalancerPolicy.
type LoadBalancerPolicyAttribute struct {
	Name  string
	Value string
}
