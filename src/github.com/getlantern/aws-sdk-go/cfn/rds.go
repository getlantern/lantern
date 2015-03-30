package cfn

// A DBSubnetGroup places an RDS instance in a set of VPC subnets.
type DBSubnetGroup struct {
	DBSubnetGroupDescription string
	SubnetIDs                []string `json:"SubnetIds"`
	Tags                     []Tag    `json:",omitempty"`
}

// A DBParameterGroup is group of configuration parameters used for a set of DB
// instances.
type DBParameterGroup struct {
	Description string
	Family      string
	Parameters  map[string]string `json:",omitempty"`
	Tags        []Tag             `json:",omitempty"`
}

// A DBInstance is a RDS instance.
type DBInstance struct {
	AllocatedStorage           int
	AllowMajorVersionUpgrade   bool   `json:",omitempty"`
	AutoMinorVersionUpgrade    bool   `json:",omitempty"`
	AvailabilityZone           string `json:",omitempty"`
	BackupRetentionPeriod      int    `json:",omitempty"`
	DBInstanceClass            string
	DBInstanceIdentifier       string        `json:",omitempty"`
	DBName                     string        `json:",omitempty"`
	DBParameterGroupName       interface{}   `json:",omitempty"`
	DBSecurityGroups           []string      `json:",omitempty"`
	DBSnapshotIdentifier       string        `json:",omitempty"`
	DBSubnetGroupName          interface{}   `json:",omitempty"`
	Engine                     string        `json:",omitempty"`
	EngineVersion              string        `json:",omitempty"`
	Iops                       int           `json:",omitempty"`
	LicenseModel               string        `json:",omitempty"`
	MasterUsername             string        `json:",omitempty"`
	MasterUserPassword         string        `json:",omitempty"`
	MultiAZ                    bool          `json:",omitempty"`
	Port                       int           `json:",omitempty"`
	PreferredBackupWindow      string        `json:",omitempty"`
	PreferredMaintenanceWindow string        `json:",omitempty"`
	PubliclyAccessible         bool          `json:",omitempty"`
	SourceDBInstanceIdentifier string        `json:",omitempty"`
	Tags                       []Tag         `json:",omitempty"`
	VPCSecurityGroups          []interface{} `json:",omitempty"`
}
