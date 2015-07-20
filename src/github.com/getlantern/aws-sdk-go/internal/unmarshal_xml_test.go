package internal

import (
	"encoding/xml"
	"reflect"
	"testing"

	"github.com/awslabs/aws-sdk-go/aws"
	"github.com/awslabs/aws-sdk-go/gen/iam"
	"github.com/awslabs/aws-sdk-go/gen/sqs"
)

func Test_SQSUnmarshalXML(t *testing.T) {
	var actualXML = []byte(`
<?xml version="1.0"?>
<ReceiveMessageResponse xmlns="http://queue.amazonaws.com/doc/2012-11-05/">
  <ReceiveMessageResult>
    <Message>
      <Body>body1</Body>
      <MD5OfBody>snip</MD5OfBody>
      <ReceiptHandle>snip</ReceiptHandle>
      <Attribute>
        <Name>SenderId</Name>
        <Value>snip</Value>
      </Attribute>
      <Attribute>
        <Name>ApproximateFirstReceiveTimestamp</Name>
        <Value>1420089460638</Value>
      </Attribute>
      <MessageAttribute>
        <Name>ATTR1</Name>
        <Value>
          <DataType>String</DataType>
          <StringValue>STRING!!</StringValue>
        </Value>
      </MessageAttribute>
      <MessageAttribute>
        <Name>ATTR2</Name>
        <Value>
          <DataType>Number</DataType>
          <StringValue>12345</StringValue>
        </Value>
      </MessageAttribute>
      <MessageId>snip</MessageId>
      <MD5OfMessageAttributes>snip</MD5OfMessageAttributes>
    </Message>
    <Message>
      <Body>body2</Body>
      <MD5OfBody>snip</MD5OfBody>
      <ReceiptHandle>snip</ReceiptHandle>
      <Attribute>
        <Name>SenderId</Name>
        <Value>snip</Value>
      </Attribute>
      <Attribute>
        <Name>ApproximateFirstReceiveTimestamp</Name>
        <Value>1420089460638</Value>
      </Attribute>
      <MessageAttribute>
        <Name>ATTR1</Name>
        <Value>
          <DataType>String</DataType>
          <StringValue>STRING!!</StringValue>
        </Value>
      </MessageAttribute>
      <MessageAttribute>
        <Name>ATTR2</Name>
        <Value>
          <DataType>Number</DataType>
          <StringValue>12345</StringValue>
        </Value>
      </MessageAttribute>
      <MessageId>snip</MessageId>
      <MD5OfMessageAttributes>snip</MD5OfMessageAttributes>
    </Message>
  </ReceiveMessageResult>
  <ResponseMetadata>
    <RequestId>snip</RequestId>
  </ResponseMetadata>
</ReceiveMessageResponse>`)

	expectedMessageAttributes := sqs.MessageAttributeMap{
		"ATTR1": sqs.MessageAttributeValue{
			DataType:    aws.String("String"),
			StringValue: aws.String("STRING!!"),
		},
		"ATTR2": sqs.MessageAttributeValue{
			DataType:    aws.String("Number"),
			StringValue: aws.String("12345"),
		},
	}

	expectedAttributes := sqs.AttributeMap{
		"SenderId":                         "snip",
		"ApproximateFirstReceiveTimestamp": "1420089460638",
	}

	expectedString := aws.String("snip")

	expected := &sqs.ReceiveMessageResult{
		Messages: []sqs.Message{
			sqs.Message{
				Attributes:             expectedAttributes,
				Body:                   aws.String("body1"),
				MD5OfBody:              expectedString,
				MD5OfMessageAttributes: expectedString,
				MessageAttributes:      expectedMessageAttributes,
				MessageID:              expectedString,
				ReceiptHandle:          expectedString,
			},
			sqs.Message{
				Attributes:             expectedAttributes,
				Body:                   aws.String("body2"),
				MD5OfBody:              expectedString,
				MD5OfMessageAttributes: expectedString,
				MessageAttributes:      expectedMessageAttributes,
				MessageID:              expectedString,
				ReceiptHandle:          expectedString,
			},
		},
	}

	actual := &sqs.ReceiveMessageResult{}
	if err := xml.Unmarshal(actualXML, actual); err != nil {
		t.Fatal(err)
	}

	if !reflect.DeepEqual(actual, expected) {
		t.Errorf("Got \n%v\n but expected \n%v", actual, expected)
	}
}

func Test_IAMUnmarshal(t *testing.T) {
	actualXML := []byte(`
<GetAccountSummaryResponse>
<GetAccountSummaryResult>
  <SummaryMap>
    <entry>
      <key>Groups</key>
      <value>31</value>
    </entry>
    <entry>
      <key>GroupsQuota</key>
      <value>50</value>
    </entry>
  </SummaryMap>
</GetAccountSummaryResult>
<ResponseMetadata>
  <RequestId>f1e38443-f1ad-11df-b1ef-a9265EXAMPLE</RequestId>
</ResponseMetadata>
</GetAccountSummaryResponse>`)

	expected := &iam.GetAccountSummaryResponse{
		SummaryMap: iam.SummaryMapType{
			"Groups":      31,
			"GroupsQuota": 50,
		},
	}

	actual := &iam.GetAccountSummaryResponse{}
	if err := xml.Unmarshal(actualXML, actual); err != nil {
		t.Fatal(err)
	}

	if !reflect.DeepEqual(actual, expected) {
		t.Errorf("Got \n%v\n but expected \n%v", actual, expected)
	}
}
