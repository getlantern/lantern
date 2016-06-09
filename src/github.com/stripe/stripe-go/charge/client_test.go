package charge

import (
	"testing"
	"time"

	stripe "github.com/stripe/stripe-go"
	"github.com/stripe/stripe-go/bitcoinreceiver"
	"github.com/stripe/stripe-go/currency"
	"github.com/stripe/stripe-go/customer"
	"github.com/stripe/stripe-go/refund"
	"github.com/stripe/stripe-go/token"
	. "github.com/stripe/stripe-go/utils"
)

func init() {
	stripe.Key = GetTestKey()
}

func TestChargeNew(t *testing.T) {
	chargeParams := &stripe.ChargeParams{
		Amount:    1000,
		Currency:  currency.USD,
		Statement: "statement",
		Email:     "a@b.com",
		Shipping: &stripe.ShippingDetails{
			Name: "Shipping Name",
			Address: stripe.Address{
				Line1: "One Street",
				Line2: "Apt 1",
				City:  "Somewhere",
				State: "SW",
				Zip:   "10044",
			},
		},
	}
	chargeParams.SetSource(&stripe.CardParams{
		Name:   "Stripe Tester",
		Number: "378282246310005",
		Month:  "06",
		Year:   "20",
	})

	target, err := New(chargeParams)

	if err != nil {
		t.Error(err)
	}

	if target.Amount != chargeParams.Amount {
		t.Errorf("Amount %v does not match expected amount %v\n", target.Amount, chargeParams.Amount)
	}

	if target.Currency != chargeParams.Currency {
		t.Errorf("Currency %q does not match expected currency %q\n", target.Currency, chargeParams.Currency)
	}

	if target.Source.Card.Name != chargeParams.Source.Card.Name {
		t.Errorf("Card name %q does not match expected name %q\n", target.Source.Card.Name, chargeParams.Source.Card.Name)
	}

	if target.Statement != chargeParams.Statement {
		t.Errorf("Statement description %q does not match expected description %v\n", target.Statement, chargeParams.Statement)
	}

	if target.Email != chargeParams.Email {
		t.Errorf("Email %q does not match expected email %v\n", target.Email, chargeParams.Email)
	}

	if target.Shipping.Name != chargeParams.Shipping.Name {
		t.Errorf("Shipping name %q does not match expected name %v\n", target.Shipping.Name, chargeParams.Shipping.Name)
	}
	if target.Shipping.Address.Line2 != chargeParams.Shipping.Address.Line2 {
		t.Errorf("Shipping address line 2 %q does not match expected address line 2 %v\n", target.Shipping.Address.Line2, chargeParams.Shipping.Address.Line2)
	}
	if target.Shipping.Address.City != chargeParams.Shipping.Address.City {
		t.Errorf("Shipping address city %q does not match expected address city %v\n", target.Shipping.Address.City, chargeParams.Shipping.Address.City)
	}
	if target.Shipping.Address.State != chargeParams.Shipping.Address.State {
		t.Errorf("Shipping address state %q does not match expected address state %v\n", target.Shipping.Address.State, chargeParams.Shipping.Address.State)
	}
	if target.Shipping.Address.Zip != chargeParams.Shipping.Address.Zip {
		t.Errorf("Shipping address zip %q does not match expected address zip %v\n", target.Shipping.Address.Zip, chargeParams.Shipping.Address.Zip)
	}
}

func TestWithoutIdempotentTwoDifferentCharges(t *testing.T) {
	chargeParams := &stripe.ChargeParams{
		Amount:    1000,
		Currency:  currency.USD,
		Statement: "statement",
		Email:     "a@b.com",
	}
	chargeParams.SetSource(&stripe.CardParams{
		Name:   "Stripe Tester",
		Number: "378282246310005",
		Month:  "06",
		Year:   "20",
	})

	if chargeParams.Params.IdempotencyKey != "" {
		t.Errorf("The default value of a Params.IdempotencyKey was not blank, and it needs to be. (%q).", chargeParams.Params.IdempotencyKey)
	}

	first, err := New(chargeParams)

	if err != nil {
		t.Error(err)
	}

	second, err := New(chargeParams)

	if err != nil {
		t.Error(err)
	}

	if first.ID == second.ID {
		t.Errorf("Created two charges with no Idempotency Key (%s), but they resulted in charges with the same IDs (%q and %q).\n", chargeParams.Params.IdempotencyKey, first.ID, second.ID)
	}
}

func TestChargeNewWithCustomerAndCard(t *testing.T) {
	customerParams := &stripe.CustomerParams{}
	customerParams.SetSource(&stripe.CardParams{
		Number: "378282246310005",
		Month:  "06",
		Year:   "20",
	})

	cust, _ := customer.New(customerParams)

	chargeParams := &stripe.ChargeParams{
		Amount:    1000,
		Currency:  currency.USD,
		Customer:  cust.ID,
		Statement: "statement",
		Email:     "a@b.com",
	}
	chargeParams.SetSource(cust.Sources.Values[0].Card.ID)

	target, err := New(chargeParams)

	if err != nil {
		t.Error(err)
	}

	if target.Amount != chargeParams.Amount {
		t.Errorf("Amount %v does not match expected amount %v\n", target.Amount, chargeParams.Amount)
	}

	if target.Currency != chargeParams.Currency {
		t.Errorf("Currency %q does not match expected currency %q\n", target.Currency, chargeParams.Currency)
	}

	if target.Customer.ID != cust.ID {
		t.Errorf("Customer ID %q doesn't match expected customer ID %q", target.Customer.ID, cust.ID)
	}

	if target.Source.Card.ID != cust.Sources.Values[0].Card.ID {
		t.Errorf("Card ID %q doesn't match expected card ID %q", target.Source.Card.ID, cust.Sources.Values[0].Card.ID)
	}

}

func TestChargeNewWithToken(t *testing.T) {
	tokenParams := &stripe.TokenParams{
		Card: &stripe.CardParams{
			Number: "4242424242424242",
			Month:  "10",
			Year:   "20",
		},
	}

	tok, _ := token.New(tokenParams)

	chargeParams := &stripe.ChargeParams{
		Amount:   1000,
		Currency: currency.USD,
	}

	chargeParams.SetSource(tok.ID)

	target, err := New(chargeParams)

	if err != nil {
		t.Error(err)
	}

	if target.Amount != chargeParams.Amount {
		t.Errorf("Amount %v does not match expected amount %v\n", target.Amount, chargeParams.Amount)
	}

	if target.Currency != chargeParams.Currency {
		t.Errorf("Currency %q does not match expected currency %q\n", target.Currency, chargeParams.Currency)
	}

	if target.Source.Card.ID != tok.Card.ID {
		t.Errorf("Card Id %q doesn't match card id %q of token %q", target.Source.Card.ID, tok.Card.ID, tok.ID)
	}
}

func TestChargeGet(t *testing.T) {
	chargeParams := &stripe.ChargeParams{
		Amount:   1001,
		Currency: currency.USD,
	}

	chargeParams.SetSource(&stripe.CardParams{
		Number: "378282246310005",
		Month:  "06",
		Year:   "20",
	})

	res, _ := New(chargeParams)

	target, err := Get(res.ID, nil)

	if err != nil {
		t.Error(err)
	}

	if target.ID != res.ID {
		t.Errorf("Charge id %q does not match expected id %q\n", target.ID, res.ID)
	}
}

func TestChargeUpdate(t *testing.T) {
	chargeParams := &stripe.ChargeParams{
		Amount:   1002,
		Currency: currency.USD,
		Desc:     "original description",
	}

	chargeParams.SetSource(&stripe.CardParams{
		Number: "378282246310005",
		Month:  "06",
		Year:   "20",
	})

	res, _ := New(chargeParams)

	if res.Desc != chargeParams.Desc {
		t.Errorf("Original description %q does not match expected description %q\n", res.Desc, chargeParams.Desc)
	}

	updated := &stripe.ChargeParams{
		Desc: "updated description",
	}

	target, err := Update(res.ID, updated)

	if err != nil {
		t.Error(err)
	}

	if target.Desc != updated.Desc {
		t.Errorf("Updated description %q does not match expected description %q\n", target.Desc, updated.Desc)
	}
}

func TestChargeCapture(t *testing.T) {
	chargeParams := &stripe.ChargeParams{
		Amount:    1004,
		Currency:  currency.USD,
		NoCapture: true,
	}

	chargeParams.SetSource(&stripe.CardParams{
		Number: "378282246310005",
		Month:  "06",
		Year:   "20",
	})

	res, _ := New(chargeParams)

	if res.Captured {
		t.Errorf("The charge should not have been captured\n")
	}

	// full capture
	target, err := Capture(res.ID, nil)

	if err != nil {
		t.Error(err)
	}

	if !target.Captured {
		t.Errorf("Expected to have captured this charge after full capture\n")
	}

	res, err = New(chargeParams)

	// partial capture
	capture := &stripe.CaptureParams{
		Amount: 554,
		Email:  "a@b.com",
	}

	target, err = Capture(res.ID, capture)

	if err != nil {
		t.Error(err)
	}

	if !target.Captured {
		t.Errorf("Expected to have captured this charge after partial capture\n")
	}

	if target.AmountRefunded != chargeParams.Amount-capture.Amount {
		t.Errorf("Refunded amount %v does not match expected amount %v\n", target.AmountRefunded, chargeParams.Amount-capture.Amount)
	}

	if target.Email != capture.Email {
		t.Errorf("Email %q does not match expected email %v\n", target.Email, capture.Email)
	}
}

func TestChargeList(t *testing.T) {
	params := &stripe.ChargeListParams{}
	params.Filters.AddFilter("limit", "", "5")
	params.Single = true

	i := List(params)
	for i.Next() {
		if i.Charge() == nil {
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

func TestMarkFraudulent(t *testing.T) {
	chargeParams := &stripe.ChargeParams{
		Amount:    1000,
		Currency:  currency.USD,
		Statement: "statement",
		Email:     "a@b.com",
	}
	chargeParams.SetSource(&stripe.CardParams{
		Name:   "Stripe Tester",
		Number: "378282246310005",
		Month:  "06",
		Year:   "20",
	})

	target, _ := New(chargeParams)
	refund.New(&stripe.RefundParams{Charge: target.ID})

	ch, _ := MarkFraudulent(target.ID)

	if ch.FraudDetails.UserReport != ReportFraudulent {
		t.Error("UserReport was not fraudulent for a charge marked as fraudulent")
	}
}

func TestMarkSafe(t *testing.T) {
	chargeParams := &stripe.ChargeParams{
		Amount:    1000,
		Currency:  currency.USD,
		Statement: "statement",
		Email:     "a@b.com",
	}
	chargeParams.SetSource(&stripe.CardParams{
		Name:   "Stripe Tester",
		Number: "378282246310005",
		Month:  "06",
		Year:   "20",
	})

	target, _ := New(chargeParams)

	ch, _ := MarkSafe(target.ID)

	if ch.FraudDetails.UserReport != ReportSafe {
		t.Error("UserReport was not safe for a charge marked as safe: ",
			ch.FraudDetails.UserReport)
	}
}

func TestChargeSourceForCard(t *testing.T) {
	chargeParams := &stripe.ChargeParams{
		Amount:    1000,
		Currency:  currency.USD,
		Statement: "statement",
		Email:     "a@b.com",
	}
	chargeParams.SetSource(&stripe.CardParams{
		Name:   "Stripe Tester",
		Number: "378282246310005",
		Month:  "06",
		Year:   "20",
	})

	ch, _ := New(chargeParams)

	if ch.Source == nil {
		t.Error("Source is nil for Charge `source` property created by a Card")
	}

	if ch.Source.Type != stripe.PaymentSourceCard {
		t.Error("Source Type for Charge created by Card should be `card`")
	}

	card := ch.Source.Card

	if len(card.ID) == 0 {
		t.Error("Source ID is nil for Charge `source` Card property")
	}

	if card.Display() != "American Express ending in 0005" {
		t.Error("Display value did not match expectation")
	}
}

func TestChargeSourceForBitcoinReceiver(t *testing.T) {
	bitcoinReceiverParams := &stripe.BitcoinReceiverParams{
		Amount:   1000,
		Currency: currency.USD,
		Email:    "do+fill_now@stripe.com",
		Desc:     "some details",
	}

	receiver, _ := bitcoinreceiver.New(bitcoinReceiverParams)

	chargeParams := &stripe.ChargeParams{
		Amount:   1000,
		Currency: currency.USD,
		Email:    "do+fill_now@stripe.com",
	}

	chargeParams.SetSource(receiver.ID)

	ch, _ := New(chargeParams)

	if len(ch.ID) == 0 {
		t.Error("ID is nil for Charge")
	}

	if ch.Source == nil {
		t.Error("Source is nil for Charge, should be BitcoinReceiver property")
	}

	if ch.Source.Type != stripe.PaymentSourceBitcoinReceiver {
		t.Error("Source Type for Charge created by BitcoinReceiver should be `bitcoin_receiver`")
	}

	rreceiver := ch.Source.BitcoinReceiver

	if len(rreceiver.ID) == 0 {
		t.Error("Source ID is nil for Charge `source` BitcoinReceiver property")
	}

	if rreceiver.Amount == 0 {
		t.Error("Amount is empty for Charge `source` BitcoinReceiver property")
	}

	if rreceiver.Display() != "Filled bitcoin receiver (1000/1000 usd)" {
		t.Error("Display value did not match expectation")
	}
}

func TestChargeOutcome(t *testing.T) {
	chargeParams := &stripe.ChargeParams{
		Amount:    1000,
		Currency:  currency.USD,
		Statement: "statement",
		Email:     "a@b.com",
	}
	chargeParams.SetSource(&stripe.CardParams{
		Name:   "Stripe Tester",
		Number: "4100000000000019",
		Month:  "06",
		Year:   "20",
	})

	_, err := New(chargeParams)

	// We expect an error for the shielded test card, we will grab the ChargeID
	// from the *stripe.Error and assert the charge's outcome from the result of Get
	if err == nil {
		t.Error("The shielded test card did not return an error for charge creation")
	}

	stripeErr := err.(*stripe.Error)
	cid := stripeErr.ChargeID

	target, err := Get(cid, nil)
	if err != nil {
		t.Error(err)
	}

	o := target.Outcome
	if o.NetworkStatus != "not_sent_to_network" {
		t.Error("The charge outcome's network status is not `not_sent_to_network`")
	}

	if o.Reason != "highest_risk_level" {
		t.Error("The charge outcome's reason is not `highest_risk_level`")
	}

	if o.SellerMessage == "" {
		t.Error("The charge outcome's seller message is not defined")
	}

	if o.Type != "blocked" {
		t.Error("The charge outcome's type is not `blocked`")
	}
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

	res, err := New(chargeParams)
	if err != nil {
		return nil, err
	}

	target, err := Get(res.ID, nil)

	if err != nil {
		return target, err
	}

	for target.Dispute == nil {
		time.Sleep(time.Second * 10)
		target, err = Get(res.ID, nil)
		if err != nil {
			return target, err
		}
	}
	return target, err
}

// Use one large test here to avoid needing to create multiple disputed charges
func TestUpdateDispute(t *testing.T) {
	ch, err := newDisputedCharge()
	if err != nil {
		t.Fatal(err)
	}

	disputeParams := &stripe.DisputeParams{
		Evidence: &stripe.DisputeEvidenceParams{
			ProductDesc: "original description",
		},
	}

	dp, err := UpdateDispute(ch.ID, disputeParams)
	if err != nil {
		t.Error(err)
	}

	if dp.Evidence.ProductDesc != disputeParams.Evidence.ProductDesc {
		t.Errorf("Original description %q does not match expected description %q\n",
			dp.Evidence.ProductDesc, disputeParams.Evidence.ProductDesc)
	}
}

func TestCheckClose(t *testing.T) {
	ch, err := newDisputedCharge()
	if err != nil {
		t.Fatal(err)
	}

	dp, err := CloseDispute(ch.ID)
	if err != nil {
		t.Error(err)
	}

	if dp.Status != "lost" {
		t.Errorf("Dispute status %q does not match expected status lost\n", dp.Status)
	}
}
