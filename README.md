# AWS SDK for Go

[![GoDoc](http://img.shields.io/badge/godoc-reference-blue.svg)](http://godoc.org/github.com/awslabs/aws-sdk-go)
[![Build Status](https://img.shields.io/travis/awslabs/aws-sdk-go.svg)](https://travis-ci.org/awslabs/aws-sdk-go)
[![Apache V2 License](http://img.shields.io/badge/license-Apache%20V2-blue.svg)](https://github.com/awslabs/aws-sdk-go/blob/master/LICENSE)

The AWS SDK for Go is a set of clients for all Amazon Web Services APIs
that initially started as
[Stripe's aws-go](https://github.com/awslabs/aws-sdk-go/tree/50f5f12927d77de6ec71a7473fe1f1081734d908)
library, and is currently under development to implement full
service coverage and other standard AWS SDK features.

**Note**: Active development is currently happening in the
[develop](https://github.com/awslabs/aws-sdk-go/tree/develop) branch.
See this branch to follow along with API changes and ongoing refactors.
The `master` branch will continue to maintain the current API of
Stripe's aws-go library until the develop branch is more stable.

## Caution

It is currently **highly untested**, so please be patient and report any
bugs or problems you experience. The APIs may change radically without
much warning, so please vendor your dependencies w/ Godep or similar.

Please do not confuse this for a stable, feature-complete library.

## Installing

Let's say you want to use EC2:

    $ go get github.com/awslabs/aws-sdk-go/gen/ec2

## Using

```go
import "github.com/awslabs/aws-sdk-go/aws"
import "github.com/awslabs/aws-sdk-go/gen/ec2"

creds := aws.Creds(accessKey, secretKey, "")
cli := ec2.New(creds, "us-west-2", nil)
resp, err := cli.DescribeInstances(nil)
if err != nil {
    panic(err)
}
fmt.Println(resp.Reservations)
```

## Supported Services

 * AutoScaling
 * CloudFormation
 * CloudFront
 * CloudHSM
 * CloudSearch
 * CloudSearchdomain
 * CloudTrail
 * CloudWatch Metrics
 * CloudWatch Logs
 * CodeDeploy
 * Cognito Identity
 * Cognito Sync
 * Config
 * Data Pipeline
 * Direct Connect
 * DynamoDB
 * EC2
 * EC2 Container Service
 * Elasticache
 * Elastic Beanstalk
 * Elastic Transcoder
 * ELB
 * EMR
 * Glacier
 * IAM
 * Import/Export
 * Kinesis
 * Key Management Service
 * Lambda
 * OpsWorks
 * RDS
 * RedShift
 * Route53
 * Route53 Domains
 * S3
 * SimpleDB
 * Simple Email Service
 * SNS
 * SQS
 * Storage Gateway
 * STS
 * Support
 * SWF
