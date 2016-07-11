package dispute

import (
	"testing"
	"time"

	stripe "github.com/stripe/stripe-go"
	"github.com/stripe/stripe-go/charge"
	"github.com/stripe/stripe-go/currency"
	. "github.com/stripe/stripe-go/utils"
)

func init() {
	stripe.Key = GetTestKey()
}

func newDisputedCharge() (*stripe.Charge, error) {
	chargeParams := &stripe.ChargeParams{
		Amount:   1001,
		Currency: currency.USD,
	}

	chargeParams.SetSource(&stripe.CardParams{
		Number: "4000000000000259",
		Month:  "06",
		Year:   "20",
	})

	res, err := charge.New(chargeParams)
	if err != nil {
		return nil, err
	}

	target, err := charge.Get(res.ID, nil)

	if err != nil {
		return target, err
	}

	for target.Dispute == nil {
		time.Sleep(time.Second * 10)
		target, err = charge.Get(res.ID, nil)
		if err != nil {
			return target, err
		}
	}
	return target, err
}

// Use one large test here to avoid needing to create multiple disputed charges
func TestDispute(t *testing.T) {
	ch, err := newDisputedCharge()
	if err != nil {
		t.Fatal(err)
	}

	CheckGet(t, ch.Dispute.ID)
	CheckUpdate(t, ch.Dispute.ID)

	ch, err = newDisputedCharge()
	if err != nil {
		t.Fatal(err)
	}
	CheckClose(t, ch.Dispute.ID)
}

func CheckGet(t *testing.T, id string) {
	dp, err := Get(id, nil)
	if err != nil {
		t.Error(err)
	}

	if dp.ID != id {
		t.Errorf("Dispute id %q does not match expected id %q\n", dp.ID, id)
	}
}

func CheckUpdate(t *testing.T, id string) {
	disputeParams := &stripe.DisputeParams{
		Evidence: &stripe.DisputeEvidenceParams{
			ProductDesc: "original description",
		},
	}

	dp, err := Update(id, disputeParams)
	if err != nil {
		t.Error(err)
	}

	if dp.ID != id {
		t.Errorf("Dispute id %q does not match expected id %q\n", dp.ID, id)
	}

	if dp.Evidence.ProductDesc != disputeParams.Evidence.ProductDesc {
		t.Errorf("Original description %q does not match expected description %q\n",
			dp.Evidence.ProductDesc, disputeParams.Evidence.ProductDesc)
	}
}

func CheckClose(t *testing.T, id string) {
	dp, err := Close(id)
	if err != nil {
		t.Error(err)
	}

	if dp.ID != id {
		t.Errorf("Dispute id %q does not match expected id %q\n", dp.ID, id)
	}

	if dp.Status != "lost" {
		t.Errorf("Dispute status %q does not match expected status lost\n", dp.Status)
	}
}

func TestDisputeList(t *testing.T) {
	params := &stripe.DisputeListParams{}
	params.Filters.AddFilter("limit", "", "5")
	params.Single = true

	i := List(params)
	for i.Next() {
		if i.Dispute() == nil {
			t.Error("No nil values expected")
		}

		if i.Meta() == nil {
			t.Error("No metadata returned")
		}
	}
	if err := i.Err(); err != nil {
		t.Error(err)
	}
}
