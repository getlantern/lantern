package refund

import (
	"strconv"
	"testing"

	stripe "github.com/stripe/stripe-go"
	"github.com/stripe/stripe-go/charge"
	"github.com/stripe/stripe-go/currency"
	. "github.com/stripe/stripe-go/utils"
)

func init() {
	stripe.Key = GetTestKey()
}

func TestRefundNew(t *testing.T) {
	chargeParams := &stripe.ChargeParams{
		Amount:   1000,
		Currency: currency.USD,
		Source: &stripe.SourceParams{
			Card: &stripe.CardParams{
				Number: "378282246310005",
				Month:  "06",
				Year:   "20",
			},
		},
	}

	res, err := charge.New(chargeParams)

	if err != nil {
		t.Error(err)
	}

	// full refund
	ref, err := New(&stripe.RefundParams{Charge: res.ID})

	if err != nil {
		t.Error(err)
	}

	if ref.Charge != res.ID {
		t.Errorf("Refund charge %q does not match expected value %v\n", ref.Charge, res.ID)
	}

	target, err := charge.Get(res.ID, nil)

	if err != nil {
		t.Error(err)
	}

	if !target.Refunded || target.Refunds == nil {
		t.Errorf("Expected to have refunded this charge\n")
	}

	if len(target.Refunds.Values) != 1 {
		t.Errorf("Expected to have a refund, but instead have %v\n", len(target.Refunds.Values))
	}

	if target.Refunds.Values[0].Amount != target.AmountRefunded {
		t.Errorf("Refunded amount %v does not match amount refunded %v\n", target.Refunds.Values[0].Amount, target.AmountRefunded)
	}

	if target.Refunds.Values[0].Currency != target.Currency {
		t.Errorf("Refunded currency %q does not match charge currency %q\n", target.Refunds.Values[0].Currency, target.Currency)
	}

	if len(target.Refunds.Values[0].Tx.ID) == 0 {
		t.Errorf("Refund transaction not set\n")
	}

	if target.Refunds.Values[0].Charge != target.ID {
		t.Errorf("Refund charge %q does not match expected value %v\n", target.Refunds.Values[0].Charge, target.ID)
	}

	res, err = charge.New(chargeParams)

	// partial refund
	refundParams := &stripe.RefundParams{
		Charge: res.ID,
		Amount: 253,
	}

	New(refundParams)

	target, err = charge.Get(res.ID, nil)

	if err != nil {
		t.Error(err)
	}

	if target.Refunded {
		t.Errorf("Partial refund should not be marked as Refunded\n")
	}

	if target.AmountRefunded != refundParams.Amount {
		t.Errorf("Refunded amount %v does not match expected amount %v\n", target.AmountRefunded, refundParams.Amount)
	}

	// refund with reason
	res, err = charge.New(chargeParams)

	if err != nil {
		t.Error(err)
	}

	New(&stripe.RefundParams{Charge: res.ID, Reason: RefundFraudulent})
	target, err = charge.Get(res.ID, nil)

	if err != nil {
		t.Error(err)
	}

	if target.FraudDetails.UserReport != "fraudulent" {
		t.Errorf("Expected a fraudulent UserReport for charge refunded with reason=fraudulent but got: %s",
			target.FraudDetails.UserReport)
	}
}

func TestRefundGet(t *testing.T) {
	chargeParams := &stripe.ChargeParams{
		Amount:   1000,
		Currency: currency.USD,
		Source: &stripe.SourceParams{
			Card: &stripe.CardParams{
				Number: "378282246310005",
				Month:  "06",
				Year:   "20",
			},
		},
	}

	ch, err := charge.New(chargeParams)

	if err != nil {
		t.Error(err)
	}

	ref, err := New(&stripe.RefundParams{Charge: ch.ID})

	if err != nil {
		t.Error(err)
	}

	target, err := Get(ref.ID, &stripe.RefundParams{Charge: ch.ID})

	if err != nil {
		t.Error(err)
	}

	if target.Charge != ch.ID {
		t.Errorf("Refund charge %q does not match expected value %v\n", target.Charge, ch.ID)
	}
}

func TestRefundListByCharge(t *testing.T) {
	chargeParams := &stripe.ChargeParams{
		Amount:   1000,
		Currency: currency.USD,
		Source: &stripe.SourceParams{
			Card: &stripe.CardParams{
				Number: "378282246310005",
				Month:  "06",
				Year:   "20",
			},
		},
	}

	ch, err := charge.New(chargeParams)

	if err != nil {
		t.Error(err)
	}

	for i := 0; i < 4; i++ {
		_, err = New(&stripe.RefundParams{Charge: ch.ID, Amount: 200})
		if err != nil {
			t.Error(err)
		}
	}

	listParams := &stripe.RefundListParams{}
	listParams.Filters.AddFilter("charge", "", ch.ID)
	i := List(listParams)

	for i.Next() {
		target := i.Refund()

		if target.Amount != 200 {
			t.Errorf("Amount %v does not match expected value\n", target.Amount)
		}

		if target.Charge != ch.ID {
			t.Errorf("Refund charge %q does not match expected value %q\n", target.Charge, ch.ID)
		}

		if i.Meta() == nil {
			t.Error("No metadata returned")
		}
	}
	if err := i.Err(); err != nil {
		t.Error(err)
	}
}

func TestRefundListAll(t *testing.T) {
	limit := 15

	listParams := &stripe.RefundListParams{}
	listParams.Filters.AddFilter("limit", "", strconv.Itoa(limit))
	listParams.Single = true
	i := List(listParams)

	count := 0

	for i.Next() {
		if i.Refund() == nil {
			t.Error("No nil values expected")
		}

		if i.Meta() == nil {
			t.Error("No metadata returned")
		}

		count++
	}

	if count != limit {
		t.Errorf("Expected %v refunds; found %v.", limit, count)
	}

	if err := i.Err(); err != nil {
		t.Error(err)
	}
}
