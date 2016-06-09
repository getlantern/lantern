package token

import (
	"testing"

	stripe "github.com/stripe/stripe-go"
	"github.com/stripe/stripe-go/bankaccount"
	"github.com/stripe/stripe-go/currency"
	. "github.com/stripe/stripe-go/utils"
)

func init() {
	stripe.Key = GetTestKey()
}

func TestTokenNew(t *testing.T) {
	tokenParams := &stripe.TokenParams{
		Card: &stripe.CardParams{
			Number: "4242424242424242",
			Month:  "10",
			Year:   "20",
		},
	}

	target, err := New(tokenParams)

	if err != nil {
		t.Error(err)
	}

	if target.Created == 0 {
		t.Errorf("Created date is not set\n")
	}

	if target.Type != Card {
		t.Errorf("Type %v does not match expected value\n", target.Type)
	}

	if target.Card == nil {
		t.Errorf("Card is not set\n")
	}

	if target.Card.LastFour != "4242" {
		t.Errorf("Unexpected last four %q for card number %v\n", target.Card.LastFour, tokenParams.Card.Number)
	}

	tokenParamsCurrency := &stripe.TokenParams{
		Card: &stripe.CardParams{
			Number:   "4242424242424242",
			Month:    "10",
			Year:     "20",
			Currency: "usd",
		},
	}

	tokenWithCurrency, err := New(tokenParamsCurrency)

	if err != nil {
		t.Error(err)
	}

	if tokenWithCurrency.Card.Currency != currency.USD {
		t.Errorf("Currency %v does not match expected value %v\n", tokenWithCurrency.Card.Currency, currency.USD)
	}
}

func TestTokenGet(t *testing.T) {
	tokenParams := &stripe.TokenParams{
		Bank: &stripe.BankAccountParams{
			Country: "US",
			Routing: "110000000",
			Account: "000123456789",
		},
	}

	tok, _ := New(tokenParams)

	target, err := Get(tok.ID, nil)

	if err != nil {
		t.Error(err)
	}

	if target.Type != Bank {
		t.Errorf("Type %v does not match expected value\n", target.Type)
	}

	if target.Bank == nil {
		t.Errorf("Bank account is not set\n")
	}

	if target.Bank.Status != bankaccount.NewAccount {
		t.Errorf("Bank account status %q does not match expected value\n", target.Bank.Status)
	}
}

func TestPIITokenNew(t *testing.T) {
	tokenParams := &stripe.TokenParams{
		PII: &stripe.PIIParams{
			PersonalIDNumber: "000000000",
		},
	}

	target, err := New(tokenParams)

	if err != nil {
		t.Error(err)
	}

	if target.Created == 0 {
		t.Errorf("Created date is not set\n")
	}

	if target.Type != PII {
		t.Errorf("Type %v does not match expected value\n", target.Type)
	}
}
