package cfn

// Ref returns a reference to the given resource.
func Ref(resource interface{}) interface{} {
	return map[string]interface{}{"Ref": resource}
}

// Fn returns a function with the given name and body.
func Fn(name string, body interface{}) interface{} {
	return map[string]interface{}{"Fn::" + name: body}
}

// Base64 returns the argument, encoded with Base64.
func Base64(v interface{}) interface{} {
	return Fn("Base64", v)
}

// And returns the conjunction of the terms.
func And(v []interface{}) interface{} {
	return Fn("And", v)
}

// Or returns the disjunction of the terms.
func Or(v []interface{}) interface{} {
	return Fn("Or", v)
}

// Equals returns true if the arguments are equal.
func Equals(a, b interface{}) interface{} {
	return Fn("Equals", []interface{}{a, b})
}

// If returns the t argument if the condition is true; otherwise, it returns the
// f argument.
func If(cond, t, f interface{}) interface{} {
	return Fn("If", []interface{}{cond, t, f})
}

// Not returns the negation of the argument.
func Not(v interface{}) interface{} {
	return Fn("Not", v)
}

// FindInMap returns the value corresponding to keys in a two-level map that is
// declared in the Mappings section of a template.
func FindInMap(name, key, subkey interface{}) interface{} {
	return Fn("FindInMap", []interface{}{name, key, subkey})
}

// GetAtt returns the value of an attribute from a resource in the template.
func GetAtt(name, attribute interface{}) interface{} {
	return Fn("GetAtt", []interface{}{name, attribute})
}

// GetAZs returns an array that lists Availability Zones for a specified
// region. For the EC2-VPC platform, GetAZs returns only the Availablity Zones
// that have default subnets. For the EC2-Classic platform, GetAZs returns all
// Availability Zones for a region.
func GetAZs(region interface{}) interface{} {
	return Fn("GetAZs", region)
}

// Join appends a set of values into a single value, separated by the specified
// delimiter. If a delimiter is the empty string, the set of values are
// concatenated with no delimiter.
func Join(delim interface{}, values ...interface{}) interface{} {
	return Fn("Join", []interface{}{delim, values})
}

// Select returns a single object from a list of objects by index.
func Select(index, values interface{}) interface{} {
	return Fn("Select", []interface{}{index, values})
}

// AccountID returns the AWS account ID of the account in which the stack is
// being created.
func AccountID() interface{} {
	return Ref("AWS::AccountId")
}

// NotificationARNs returns the list of notification Amazon Resource Names
// (ARNs) for the current stack.
func NotificationARNs() interface{} {
	return Ref("AWS::NotificationARNs")
}

// NoValue removes the corresponding resource property when specified as a
// return value in the If function.
func NoValue() interface{} {
	return Ref("AWS::NoValue")
}

// Region returns a string representing the AWS Region in which the encompassing
// resource is being created.
func Region() interface{} {
	return Ref("AWS::Region")
}

// StackID returns the ID of the stack as specified with the CreateStack
// operation.
func StackID() interface{} {
	return Ref("AWS::StackId")
}

// StackName returns the name of the stack as specified with the CreateStack
// operation.
func StackName() interface{} {
	return Ref("AWS::StackName")
}
