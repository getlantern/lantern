package cfn

// An InternetGateway is a VPC internet gateway.
type InternetGateway struct {
	Tags []Tag `json:",omitempty"`
}

// A Route is an entry in a route table.
type Route struct {
	DestinationCIDRBlock   string      `json:"DestinationCidrBlock"`
	GatewayID              interface{} `json:"GatewayId,omitempty"`
	InstanceID             interface{} `json:"InstanceId,omitempty"`
	NetworkInterfaceID     interface{} `json:"NetworkInterfaceId,omitempty"`
	RouteTableID           interface{} `json:"RouteTableId,omitempty"`
	VPCPeeringConnectionID interface{} `json:"VpcPeeringConnectionId,omitempty"`
}

// A RouteTable is a table of routes.
type RouteTable struct {
	VPCID interface{} `json:"VpcId,omitempty"`
	Tags  []Tag       `json:"Tags,omitempty"`
}

// A SecurityGroup determines which instances can communicate with each other.
type SecurityGroup struct {
	GroupDescription     interface{}
	SecurityGroupEgress  []SecurityGroupRule `json:",omitempty"`
	SecurityGroupIngress []SecurityGroupRule `json:",omitempty"`
	Tags                 []Tag               `json:",omitempty"`
	VPCID                interface{}         `json:"VpcId"`
}

// A SecurityGroupRule is a rule in a security group.
type SecurityGroupRule struct {
	CIDRIP                     interface{} `json:"CidrIp,omitempty"`
	DestinationSecurityGroupID interface{} `json:"DestinationSecurityGroupId,omitempty"`
	FromPort                   int
	IPProtocol                 interface{} `json:"IpProtocol"`
	SourceSecurityGroupID      interface{} `json:"SourceSecurityGroupId,omitempty"`
	SourceSecurityGroupName    string      `json:",omitempty"`
	SourceSecurityGroupOwnerID interface{} `json:"SourceSecurityGroupOwnerId,omitempty"`
	ToPort                     int
}

// A Subnet is an IP subnet in a VPC.
type Subnet struct {
	AvailabilityZone string      `json:"AvailabilityZone,omitempty"`
	CIDRBlock        string      `json:"CidrBlock,omitempty"`
	Tags             []Tag       `json:"Tags,omitempty"`
	VPCID            interface{} `json:"VpcId,omitempty"`
}

// A SubnetRouteTableAssociation associates a route table with a subnet.
type SubnetRouteTableAssociation struct {
	RouteTableID interface{} `json:"RouteTableId,omitempty"`
	SubnetID     interface{} `json:"SubnetId,omitempty"`
}

// A VPC is a virtual private cloud.
type VPC struct {
	CIDRBlock          string `json:"CidrBlock"`
	EnableDNSSupport   bool   `json:"EnableDnsSupport,omitempty"`
	EnableDNSHostnames bool   `json:"EnableDnsHostnames,omitempty"`
	InstanceTenancy    string `json:"InstanceTenancy,omitempty"`
	Tags               []Tag  `json:"Tags,omitempty"`
}

// A VPCGatewayAttachment attaches an internet gateway to a VPC.
type VPCGatewayAttachment struct {
	InternetGatewayID interface{} `json:"InternetGatewayId,omitempty"`
	VPCID             interface{} `json:"VpcId,omitempty"`
	VPNGatewayID      string      `json:"VpnGatewayId,omitempty"`
}
