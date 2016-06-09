package bitcoinreceiver

import (
	"testing"

	stripe "github.com/stripe/stripe-go"
	"github.com/stripe/stripe-go/currency"
	. "github.com/stripe/stripe-go/utils"
)

func init() {
	stripe.Key = GetTestKey()
}

func TestBitcoinReceiverNew(t *testing.T) {
	bitcoinReceiverParams := &stripe.BitcoinReceiverParams{
		Amount:   1000,
		Currency: currency.USD,
		Email:    "a@b.com",
		Desc:     "some details",
	}

	target, err := New(bitcoinReceiverParams)

	if err != nil {
		t.Error(err)
	}

	if target.Amount != bitcoinReceiverParams.Amount {
		t.Errorf("Amount %v does not match expected amount %v\n", target.Amount, bitcoinReceiverParams.Amount)
	}

	if target.Currency != bitcoinReceiverParams.Currency {
		t.Errorf("Currency %q does not match expected currency %q\n", target.Currency, bitcoinReceiverParams.Currency)
	}

	if target.Desc != bitcoinReceiverParams.Desc {
		t.Errorf("Desc %q does not match expected description %v\n", target.Desc, bitcoinReceiverParams.Desc)
	}

	if target.Email != bitcoinReceiverParams.Email {
		t.Errorf("Email %q does not match expected email %v\n", target.Email, bitcoinReceiverParams.Email)
	}
}

func TestBitcoinReceiverGet(t *testing.T) {
	bitcoinReceiverParams := &stripe.BitcoinReceiverParams{
		Amount:   1000,
		Currency: currency.USD,
		Email:    "a@b.com",
		Desc:     "some details",
	}

	res, _ := New(bitcoinReceiverParams)

	target, err := Get(res.ID, nil)

	if err != nil {
		t.Error(err)
	}

	if target.ID != res.ID {
		t.Errorf("BitcoinReceiver id %q does not match expected id %q\n", target.ID, res.ID)
	}
}

func TestBitcoinReceiverTransactionsGet(t *testing.T) {
	bitcoinReceiverParams := &stripe.BitcoinReceiverParams{
		Amount:   1000,
		Currency: currency.USD,
		Email:    "do+fill_now@stripe.com",
		Desc:     "some details",
	}

	res, _ := New(bitcoinReceiverParams)

	target, err := Get(res.ID, nil)

	if err != nil {
		t.Error(err)
	}

	if target.ID != res.ID {
		t.Errorf("BitcoinReceiver id %q does not match expected id %q\n", target.ID, res.ID)
	}

	if target.Transactions == nil {
		t.Errorf("Expected BitcoinReceiver to have a BitcoinTransactionList")
	}

	if len(target.Transactions.Values) != 1 {
		t.Errorf("Bitcoin receiver should have 1 transaction")
	}
}

func TestBitcoinReceiverUpdate(t *testing.T) {
	bitcoinReceiverParams := &stripe.BitcoinReceiverParams{
		Amount:   1000,
		Currency: currency.USD,
		Email:    "do+fill_now@stripe.com",
		Desc:     "some details",
	}

	receiver, err := New(bitcoinReceiverParams)

	if err != nil {
		t.Error(err)
	}

	updateParams := &stripe.BitcoinReceiverUpdateParams{
		Desc: "some other details",
	}

	target, err := Update(receiver.ID, updateParams)

	if err != nil {
		t.Error(err)
	}

	if target.Desc != updateParams.Desc {
		t.Errorf("Description %q does not match expected name %q\n", target.Desc, updateParams.Desc)
	}
}

func TestBitcoinReceiverList(t *testing.T) {
	params := &stripe.BitcoinReceiverListParams{}
	params.Filters.AddFilter("limit", "", "5")
	params.Single = true

	i := List(params)
	for i.Next() {
		if i.BitcoinReceiver() == nil {
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
