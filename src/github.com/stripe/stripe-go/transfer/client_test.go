package transfer

import (
	"testing"

	stripe "github.com/stripe/stripe-go"
	"github.com/stripe/stripe-go/account"
	"github.com/stripe/stripe-go/charge"
	"github.com/stripe/stripe-go/currency"
	"github.com/stripe/stripe-go/recipient"
	. "github.com/stripe/stripe-go/utils"
)

func init() {
	stripe.Key = GetTestKey()
}

func TestTransferNew(t *testing.T) {
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

	target, err := New(transferParams)

	if err != nil {
		t.Error(err)
	}

	if target.Amount != transferParams.Amount {
		t.Errorf("Amount %v does not match expected amount %v\n", target.Amount, transferParams.Amount)
	}

	if target.Currency != transferParams.Currency {
		t.Errorf("Curency %q does not match expected currency %q\n", target.Currency, transferParams.Currency)
	}

	if target.Created == 0 {
		t.Errorf("Created date is not set\n")
	}

	if target.Date == 0 {
		t.Errorf("Date is not set \n")
	}

	if target.Desc != transferParams.Desc {
		t.Errorf("Description %q does not match expected description %q\n", target.Desc, transferParams.Desc)
	}

	if target.Recipient.ID != transferParams.Recipient {
		t.Errorf("Recipient %q does not match expected recipient %q\n", target.Recipient.ID, transferParams.Recipient)
	}

	if target.Statement != transferParams.Statement {
		t.Errorf("Statement %q does not match expected statement %q\n", target.Statement, transferParams.Statement)
	}

	if target.Bank == nil {
		t.Errorf("Bank account is not set\n")
	}

	if target.Status != Pending {
		t.Errorf("Unexpected status %q\n", target.Status)
	}

	if target.Type != Bank {
		t.Errorf("Unexpected type %q\n", target.Type)
	}

	recipient.Del(rec.ID)
}

func TestTransferToAccount(t *testing.T) {
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

	charge, err := charge.New(chargeParams)
	if err != nil {
		t.Error(err)
	}

	params := &stripe.AccountParams{
		Managed: true,
		Country: "US",
		LegalEntity: &stripe.LegalEntity{
			Type: stripe.Individual,
			DOB: stripe.DOB{
				Day:   1,
				Month: 2,
				Year:  1990,
			},
		},
	}

	acc, err := account.New(params)
	if err != nil {
		t.Error(err)
	}

	transferParams := &stripe.TransferParams{
		Amount:   100,
		Currency: currency.USD,
		Dest:     acc.ID,
		SourceTx: charge.ID,
	}

	target, err := New(transferParams)

	if err != nil {
		t.Error(err)
	}

	if target.Amount != transferParams.Amount {
		t.Errorf("Amount %v does not match expected amount %v\n", target.Amount, transferParams.Amount)
	}

	if target.Currency != transferParams.Currency {
		t.Errorf("Curency %q does not match expected currency %q\n", target.Currency, transferParams.Currency)
	}

	if target.Created == 0 {
		t.Errorf("Created date is not set\n")
	}

	if target.Date == 0 {
		t.Errorf("Date is not set\n")
	}

	if target.SourceTx != transferParams.SourceTx {
		t.Errorf("SourceTx %q does not match expected SourceTx %q\n", target.SourceTx, transferParams.SourceTx)
	}

	if target.Type != StripeAccount {
		t.Errorf("Unexpected type %q\n", target.Type)
	}

	account.Del(acc.ID)
}

func TestTransferSourceType(t *testing.T) {
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

	_, err := charge.New(chargeParams)
	if err != nil {
		t.Error(err)
	}

	transferParams := &stripe.TransferParams{
		Amount:     100,
		Currency:   currency.USD,
		Dest:       "default_for_currency",
		SourceType: SourceCard,
	}

	target, err := New(transferParams)

	if err != nil {
		t.Error(err)
	}

	if target.Amount != transferParams.Amount {
		t.Errorf("Amount %v does not match expected amount %v\n", target.Amount, transferParams.Amount)
	}

	if target.Currency != transferParams.Currency {
		t.Errorf("Curency %q does not match expected currency %q\n", target.Currency, transferParams.Currency)
	}

	if target.Created == 0 {
		t.Errorf("Created date is not set\n")
	}

	if target.Date == 0 {
		t.Errorf("Date is not set\n")
	}

	if target.Type != Bank {
		t.Errorf("Unexpected type %q\n", target.Type)
	}
}

func TestTransferGet(t *testing.T) {
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
		Card: &stripe.CardParams{
			Name:   "Test Debit",
			Number: "4000056655665556",
			Month:  "10",
			Year:   "20",
		},
	}

	rec, _ := recipient.New(recipientParams)

	transferParams := &stripe.TransferParams{
		Amount:    100,
		Currency:  currency.USD,
		Recipient: rec.ID,
	}

	trans, _ := New(transferParams)

	target, err := Get(trans.ID, nil)

	if err != nil {
		t.Error(err)
	}

	if target.Card == nil {
		t.Errorf("Card is not set\n")
	}

	if target.Type != Card {
		t.Errorf("Unexpected type %q\n", target.Type)
	}

	recipient.Del(rec.ID)
}

func TestTransferUpdate(t *testing.T) {
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
		Type: recipient.Corp,
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
		Desc:      "Original",
	}

	trans, _ := New(transferParams)

	updated := &stripe.TransferParams{
		Desc: "Updated",
	}

	target, err := Update(trans.ID, updated)

	if err != nil {
		t.Error(err)
	}

	if target.Desc != updated.Desc {
		t.Errorf("Description %q does not match expected description %q\n", target.Desc, updated.Desc)
	}

	recipient.Del(rec.ID)
}

func TestTransferList(t *testing.T) {
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
		Card: &stripe.CardParams{
			Name:   "Test Debit",
			Number: "4000056655665556",
			Month:  "10",
			Year:   "20",
		},
	}

	rec, _ := recipient.New(recipientParams)

	transferParams := &stripe.TransferParams{
		Amount:    100,
		Currency:  currency.USD,
		Recipient: rec.ID,
	}

	for i := 0; i < 5; i++ {
		New(transferParams)
	}

	i := List(&stripe.TransferListParams{Recipient: rec.ID})
	for i.Next() {
		if i.Transfer() == nil {
			t.Error("No nil values expected")
		}

		if i.Meta() == nil {
			t.Error("No metadata returned")
		}
	}
	if err := i.Err(); err != nil {
		t.Error(err)
	}

	recipient.Del(rec.ID)
}
