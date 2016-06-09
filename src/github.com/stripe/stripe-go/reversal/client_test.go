package reversal

import (
	"fmt"
	"testing"

	stripe "github.com/stripe/stripe-go"
	"github.com/stripe/stripe-go/charge"
	"github.com/stripe/stripe-go/currency"
	"github.com/stripe/stripe-go/recipient"
	"github.com/stripe/stripe-go/transfer"
	. "github.com/stripe/stripe-go/utils"
)

func init() {
	stripe.Key = GetTestKey()
}

func TestReversalNew(t *testing.T) {
	chargeParams := &stripe.ChargeParams{
		Amount:   1000,
		Currency: currency.USD,
		Source: &stripe.SourceParams{
			Card: &stripe.CardParams{
				Number: "4000000000000077",
				Month:  "06",
				Year:   "20",
			},
		},
	}

	charge.New(chargeParams)

	recipientParams := &stripe.RecipientParams{
		Name: "Recipient Name",
		Type: recipient.Individual,
		Bank: &stripe.BankAccountParams{
			Country: "US",
			Routing: "110000000",
			Account: "000123456789",
		},
	}

	rec, _ := recipient.New(recipientParams)

	transferParams := &stripe.TransferParams{
		Amount:    100,
		Currency:  currency.USD,
		Recipient: rec.ID,
		Desc:      "Transfer Desc",
		Statement: "Transfer",
	}

	trans, _ := transfer.New(transferParams)

	target, err := New(&stripe.ReversalParams{Transfer: trans.ID})

	if err != nil {
		// TODO: replace this with t.Error when this can be tested
		fmt.Println(err)
	}

	fmt.Printf("%+v\n", target)
}

func TestReversalGet(t *testing.T) {
	chargeParams := &stripe.ChargeParams{
		Amount:   1000,
		Currency: currency.USD,
		Source: &stripe.SourceParams{
			Card: &stripe.CardParams{
				Number: "4000000000000077",
				Month:  "06",
				Year:   "20",
			},
		},
	}

	charge.New(chargeParams)

	recipientParams := &stripe.RecipientParams{
		Name: "Recipient Name",
		Type: recipient.Individual,
		Bank: &stripe.BankAccountParams{
			Country: "US",
			Routing: "110000000",
			Account: "000123456789",
		},
	}

	rec, _ := recipient.New(recipientParams)

	transferParams := &stripe.TransferParams{
		Amount:    100,
		Currency:  currency.USD,
		Recipient: rec.ID,
		Desc:      "Transfer Desc",
		Statement: "Transfer",
	}

	trans, _ := transfer.New(transferParams)
	rev, _ := New(&stripe.ReversalParams{Transfer: trans.ID})

	target, err := Get(rev.ID, &stripe.ReversalParams{Transfer: trans.ID})

	if err != nil {
		// TODO: replace this with t.Error when this can be tested
		fmt.Println(err)
	}

	fmt.Printf("%+v\n", target)
}
