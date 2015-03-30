package cfn

// A DynamoDBTable creates a DynamoDB table.
type DynamoDBTable struct {
	AttributeDefinitions   []AttributeDefinition
	GlobalSecondaryIndexes []GlobalSecondaryIndex `json:",omitempty"`
	KeySchema              []KeySchema
	LocalSecondaryIndexes  []LocalSecondaryIndex `json:",omitempty"`
	ProvisionedThroughput  ProvisionedThroughput
	TableName              string `json:",omitempty"`
}

// An AttributeDefinition defines an attribute of a DynamoDBTable.
type AttributeDefinition struct {
	AttributeName string
	AttributeType string
}

// A GlobalSecondaryIndex describes a global secondary index for the
// DynamoDBTable resource.
type GlobalSecondaryIndex struct {
	IndexName             string
	KeySchema             []KeySchema
	Projection            Projection
	ProvisionedThroughput ProvisionedThroughput
}

// LocalSecondaryIndex describes local secondary indexes for the DynamoDBTable
// resource. Each index is scoped to a given hash key value. Tables with one or
// more local secondary indexes are subject to an item collection size limit,
// where the amount of data within a given item collection cannot exceed 10 GB.
type LocalSecondaryIndex struct {
	IndexName  string
	KeySchema  []KeySchema
	Projection Projection
}

// Possible values for KeySchema's KeyType field.
const (
	KeyTypeHash  = "HASH"
	KeyTypeRange = "RANGE"
)

// KeySchema describes a primary key for the DynamoDBTable resource or a key
// schema for an index.
type KeySchema struct {
	AttributeName string
	KeyType       string
}

// Possible values for Projection's ProjectionType field.
const (
	ProjectionTypeKeysOnly = "KEYS_ONLY"
	ProjectionTypeInclude  = "INCLUDE"
	ProjectionTypeAll      = "ALL"
)

// A Projection defines attributes that are copied (projected) from the source
// table into the index. These attributes are additions to the primary key
// attributes and index key attributes, which are automatically projected.
type Projection struct {
	NonKeyAttributes []string `json:",omitempty"`
	ProjectionType   string
}

// ProvisionedThroughput describes a set of provisioned throughput values for a
// DynamoDBTable resource.
type ProvisionedThroughput struct {
	ReadCapacityUnits  int
	WriteCapacityUnits int
}
