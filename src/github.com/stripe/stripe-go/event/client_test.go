package event

import (
	"testing"

	stripe "github.com/stripe/stripe-go"
	. "github.com/stripe/stripe-go/utils"
)

func init() {
	stripe.Key = GetTestKey()
}

func TestEvent(t *testing.T) {
	params := &stripe.EventListParams{}
	params.Filters.AddFilter("limit", "", "5")
	params.Single = true
	params.Type = "charge.*"

	i := List(params)
	for i.Next() {
		e := i.Event()

		if e == nil {
			t.Error("No nil values expected")
		}

		if len(e.ID) == 0 {
			t.Errorf("ID is not set\n")
		}

		if e.Created == 0 {
			t.Errorf("Created date is not set\n")
		}

		if len(e.Type) == 0 {
			t.Errorf("Type is not set\n")
		}

		if len(e.Req) == 0 {
			t.Errorf("Request is not set\n")
		}

		if e.Data == nil {
			t.Errorf("Data is not set\n")
		}

		if len(e.Data.Obj) == 0 {
			t.Errorf("Object is empty\n")
		}

		target, err := Get(e.ID, nil)

		if err != nil {
			t.Error(err)
		}

		if e.ID != target.ID {
			t.Errorf("ID %q does not match expected id %q\n", e.ID, target.ID)
		}

		var targetVal string
		var val string

		if e.GetObjValue("source", "object") == "card" {
			targetVal = e.GetObjValue("source", "last4")
			val = target.Data.Obj["source"].(map[string]interface{})["last4"].(string)
		} else { // is bitcoin receiver
			targetVal = e.GetObjValue("source", "currency")
			val = target.Data.Obj["source"].(map[string]interface{})["currency"].(string)
		}

		if targetVal != val {
			t.Errorf("Value %q does not match expected value %q\n", targetVal, val)
		}

		if len(target.Data.Raw) == 0 {
			t.Errorf("Raw data is nil\n")
		}

		// no need to actually check the value, we're just validating this doesn't bomb
		e.GetObjValue("does not exist")
	}

	if err := i.Err(); err != nil {
		t.Error(err)
	}
}
