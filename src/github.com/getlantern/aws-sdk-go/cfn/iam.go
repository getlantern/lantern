package cfn

// A Role is an IAM role.
type Role struct {
	AssumeRolePolicyDocument interface{}
	Path                     string
	Policies                 interface{} `json:",omitempty"`
}

// An InstanceProfile is an IAM instance profile.
type InstanceProfile struct {
	Path  string
	Roles []interface{}
}
