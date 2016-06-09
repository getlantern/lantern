package stripe_test

import (
	"net/url"
	"reflect"
	"testing"

	stripe "github.com/stripe/stripe-go"
	. "github.com/stripe/stripe-go/testing"
)

func TestRequestValues(t *testing.T) {
	values := &stripe.RequestValues{}

	actual := values.Encode()
	expected := ""
	if expected != actual {
		t.Fatalf("Expected encoded value of %v but got %v.", expected, actual)
	}

	if !values.Empty() {
		t.Fatalf("Expected values to be empty.")
	}

	values = &stripe.RequestValues{}
	values.Add("foo", "bar")

	actual = values.Encode()
	expected = "foo=bar"
	if expected != actual {
		t.Fatalf("Expected encoded value of %v but got %v.", expected, actual)
	}

	if values.Empty() {
		t.Fatalf("Expected values to not be empty.")
	}

	values = &stripe.RequestValues{}
	values.Add("foo", "bar")
	values.Add("foo", "bar")
	values.Add("baz", "bar")

	actual = values.Encode()
	expected = "foo=bar&foo=bar&baz=bar"
	if expected != actual {
		t.Fatalf("Expected encoded value of %v but got %v.", expected, actual)
	}

	values.Set("foo", "firstbar")

	actual = values.Encode()
	expected = "foo=firstbar&foo=bar&baz=bar"
	if expected != actual {
		t.Fatalf("Expected encoded value of %v but got %v.", expected, actual)
	}

	values.Set("new", "appended")

	actual = values.Encode()
	expected = "foo=firstbar&foo=bar&baz=bar&new=appended"
	if expected != actual {
		t.Fatalf("Expected encoded value of %v but got %v.", expected, actual)
	}

	urlValues := values.ToValues()
	expectedURLValues := url.Values{
		"baz": {"bar"},
		"foo": {"firstbar", "bar"},
		"new": {"appended"},
	}
	if !reflect.DeepEqual(urlValues, expectedURLValues) {
		t.Fatalf("Expected body of %v but got %v.", expectedURLValues, urlValues)
	}
}

func TestParamsWithExtras(t *testing.T) {
	testCases := []struct {
		InitialBody  [][2]string
		Extras       [][2]string
		ExpectedBody [][2]string
	}{
		{
			InitialBody:  [][2]string{{"foo", "bar"}},
			Extras:       [][2]string{},
			ExpectedBody: [][2]string{{"foo", "bar"}},
		},
		{
			InitialBody:  [][2]string{{"foo", "bar"}},
			Extras:       [][2]string{{"foo", "baz"}, {"other", "thing"}},
			ExpectedBody: [][2]string{{"foo", "bar"}, {"foo", "baz"}, {"other", "thing"}},
		},
	}

	for _, testCase := range testCases {
		p := stripe.Params{}

		for _, extra := range testCase.Extras {
			p.AddExtra(extra[0], extra[1])
		}

		body := valuesFromArray(testCase.InitialBody)
		p.AppendTo(body)

		expected := valuesFromArray(testCase.ExpectedBody)
		if !reflect.DeepEqual(body, expected) {
			t.Fatalf("Expected body of %v but got %v.", expected, body)
		}
	}
}

func TestCheckinListParamsExpansion(t *testing.T) {
	testCases := []struct {
		InitialBody  [][2]string
		Expand       []string
		ExpectedBody [][2]string
	}{
		{
			InitialBody:  [][2]string{{"foo", "bar"}},
			Expand:       []string{},
			ExpectedBody: [][2]string{{"foo", "bar"}},
		},
		{
			InitialBody:  [][2]string{{"foo", "bar"}, {"foo", "baz"}},
			Expand:       []string{"data", "data.foo"},
			ExpectedBody: [][2]string{{"foo", "bar"}, {"foo", "baz"}, {"expand[]", "data"}, {"expand[]", "data.foo"}},
		},
	}

	for _, testCase := range testCases {
		p := stripe.ListParams{}

		for _, exp := range testCase.Expand {
			p.Expand(exp)
		}

		body := valuesFromArray(testCase.InitialBody)
		p.AppendTo(body)

		expected := valuesFromArray(testCase.ExpectedBody)
		if !reflect.DeepEqual(body, expected) {
			t.Fatalf("Expected body of %v but got %v.", expected, body)
		}
	}
}

func TestCheckinListParamsToParams(t *testing.T) {
	listParams := &stripe.ListParams{StripeAccount: TestMerchantID}
	params := listParams.ToParams()

	if params.StripeAccount != TestMerchantID {
		t.Fatalf("Expected StripeAccount of %v but got %v.",
			TestMerchantID, params.StripeAccount)
	}
}

func TestCheckinParamsSetAccount(t *testing.T) {
	p := &stripe.Params{}
	p.SetAccount(TestMerchantID)

	if p.Account != TestMerchantID {
		t.Fatalf("Expected Account of %v but got %v.", TestMerchantID, p.Account)
	}

	if p.StripeAccount != TestMerchantID {
		t.Fatalf("Expected StripeAccount of %v but got %v.", TestMerchantID, p.StripeAccount)
	}
}

func TestCheckinParamsSetStripeAccount(t *testing.T) {
	p := &stripe.Params{}
	p.SetStripeAccount(TestMerchantID)

	if p.StripeAccount != TestMerchantID {
		t.Fatalf("Expected Account of %v but got %v.", TestMerchantID, p.StripeAccount)
	}

	// Check that we don't set the deprecated parameter.
	if p.Account != "" {
		t.Fatalf("Expected empty Account but got %v.", TestMerchantID)
	}
}

// Converts a collection of key/value tuples in a two dimensional slice/array
// into RequestValues form. The purpose of this is that it's much cleaner to
// initialize the array all at once on a single line.
func valuesFromArray(arr [][2]string) *stripe.RequestValues {
	body := &stripe.RequestValues{}
	for _, v := range arr {
		body.Add(v[0], v[1])
	}
	return body
}
