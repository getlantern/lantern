package paymentsource

import (
	"testing"

	stripe "github.com/stripe/stripe-go"
	"github.com/stripe/stripe-go/bankaccount"
	"github.com/stripe/stripe-go/card"
	"github.com/stripe/stripe-go/customer"
	"github.com/stripe/stripe-go/token"
	. "github.com/stripe/stripe-go/utils"
)

func init() {
	stripe.Key = GetTestKey()
}

func TestSourceCardNew(t *testing.T) {
	customerParams := &stripe.CustomerParams{}
	cust, err := customer.New(customerParams)

	if err != nil {
		t.Error(err)
	}

	sourceParams := &stripe.CustomerSourceParams{
		Customer: cust.ID,
	}
	sourceParams.SetSource(&stripe.CardParams{
		Number: "4242424242424242",
		Month:  "10",
		Year:   "20",
		CVC:    "1234",
	})

	source, err := New(sourceParams)

	if err != nil {
		t.Error(err)
	}

	target := source.Card

	if target.LastFour != "4242" {
		t.Errorf("Unexpected last four %q for card number %v\n", target.LastFour, sourceParams.Source.Card.Number)
	}

	if target.CVCCheck != card.Pass {
		t.Errorf("CVC check %q does not match expected status\n", target.ZipCheck)
	}

	targetCust, err := customer.Get(cust.ID, nil)

	if err != nil {
		t.Error(err)
	}

	if targetCust.Sources.Count != 1 {
		t.Errorf("Unexpected number of sources %v\n", targetCust.Sources.Count)
	}

	customer.Del(cust.ID)
}

func TestSourceBankAccountNew(t *testing.T) {
	baTok, err := token.New(&stripe.TokenParams{
		Bank: &stripe.BankAccountParams{
			Country:           "US",
			Currency:          "usd",
			Routing:           "110000000",
			Account:           "000123456789",
			AccountHolderName: "Jane Austen",
			AccountHolderType: "individual",
		},
	})

	if baTok.Bank.AccountHolderName != "Jane Austen" {
		t.Errorf("Bank account token name %q was not Jane Austen as expected.", baTok.Bank.AccountHolderName)
	}

	if err != nil {
		t.Error(err)
	}

	customerParams := &stripe.CustomerParams{}
	customer, err := customer.New(customerParams)
	if err != nil {
		t.Error(err)
	}

	source, err := New(&stripe.CustomerSourceParams{
		Customer: customer.ID,
		Source: &stripe.SourceParams{
			Token: baTok.ID,
		},
	})

	if source.BankAccount.AccountHolderName != "Jane Austen" {
		t.Errorf("Bank account name %q was not Jane Austen as expected.", source.BankAccount.Name)
	}
}

func TestSourceCardGet(t *testing.T) {
	customerParams := &stripe.CustomerParams{
		Email: "SomethingIdentifiable@gmail.om",
	}
	customerParams.SetSource(&stripe.CardParams{
		Number: "4242424242424242",
		Month:  "06",
		Year:   "20",
	})
	cust, err := customer.New(customerParams)

	if err != nil {
		t.Error(err)
	}

	source, err := Get(cust.DefaultSource.ID, &stripe.CustomerSourceParams{Customer: cust.ID})

	if err != nil {
		t.Error(err)
	}

	target := source.Card

	if target.LastFour != "4242" {
		t.Errorf("Unexpected last four %q for card number %v\n", target.LastFour, customerParams.Source.Card.Number)
	}

	if target.Brand != card.Visa {
		t.Errorf("Card brand %q does not match expected value\n", target.Brand)
	}

	customer.Del(cust.ID)
}

func TestSourceBankAccountGet(t *testing.T) {
	baTok, err := token.New(&stripe.TokenParams{
		Bank: &stripe.BankAccountParams{
			Country:           "US",
			Currency:          "usd",
			Routing:           "110000000",
			Account:           "000123456789",
			AccountHolderName: "Jane Austen",
			AccountHolderType: "individual",
		},
	})

	if baTok.Bank.AccountHolderName != "Jane Austen" {
		t.Errorf("Bank account token name %q was not Jane Austen as expected.", baTok.Bank.AccountHolderName)
	}

	if err != nil {
		t.Error(err)
	}

	customerParams := &stripe.CustomerParams{}
	customer, err := customer.New(customerParams)
	if err != nil {
		t.Error(err)
	}

	src, err := New(&stripe.CustomerSourceParams{
		Customer: customer.ID,
		Source: &stripe.SourceParams{
			Token: baTok.ID,
		},
	})

	source, err := Get(src.ID, &stripe.CustomerSourceParams{Customer: customer.ID})

	if source.BankAccount.AccountHolderName != "Jane Austen" {
		t.Errorf("Bank account name %q was not Jane Austen as expected.", source.BankAccount.Name)
	}
}

func TestSourceCardDel(t *testing.T) {
	customerParams := &stripe.CustomerParams{}
	customerParams.SetSource(&stripe.CardParams{
		Number: "378282246310005",
		Month:  "06",
		Year:   "20",
	})

	cust, _ := customer.New(customerParams)

	sourceDel, err := Del(cust.DefaultSource.ID, &stripe.CustomerSourceParams{Customer: cust.ID})
	if err != nil {
		t.Error(err)
	}

	if !sourceDel.Deleted {
		t.Errorf("Source id %q expected to be marked as deleted on the returned resource\n", sourceDel.ID)
	}

	customer.Del(cust.ID)
}

func TestSourceBankAccountDel(t *testing.T) {
	baTok, err := token.New(&stripe.TokenParams{
		Bank: &stripe.BankAccountParams{
			Country:           "US",
			Currency:          "usd",
			Routing:           "110000000",
			Account:           "000123456789",
			AccountHolderName: "Jane Austen",
			AccountHolderType: "individual",
		},
	})

	if baTok.Bank.AccountHolderName != "Jane Austen" {
		t.Errorf("Bank account name %q was not Jane Austen as expected.", baTok.Bank.AccountHolderName)
	}

	if err != nil {
		t.Error(err)
	}

	customerParams := &stripe.CustomerParams{}
	customer, err := customer.New(customerParams)
	if err != nil {
		t.Error(err)
	}

	source, err := New(&stripe.CustomerSourceParams{
		Customer: customer.ID,
		Source: &stripe.SourceParams{
			Token: baTok.ID,
		},
	})

	sourceDel, err := Del(source.ID, &stripe.CustomerSourceParams{Customer: customer.ID})

	if !sourceDel.Deleted {
		t.Errorf("Source id %q expected to be marked as deleted on the returned resource\n", sourceDel.ID)
	}
}

func TestSourceCardUpdate(t *testing.T) {
	customerParams := &stripe.CustomerParams{}
	customerParams.SetSource(&stripe.CardParams{
		Number: "378282246310005",
		Month:  "06",
		Year:   "20",
		Name:   "Original Name",
	})

	cust, err := customer.New(customerParams)

	if err != nil {
		t.Error(err)
	}

	sourceParams := &stripe.CustomerSourceParams{
		Customer: cust.ID,
	}
	sourceParams.SetSource(&stripe.CardParams{
		Name: "Updated Name",
	})

	source, err := Update(cust.DefaultSource.ID, sourceParams)

	if err != nil {
		t.Error(err)
		return
	}

	target := source.Card

	if target.Name != sourceParams.Source.Card.Name {
		t.Errorf("Card name %q does not match expected name %q\n", target.Name, sourceParams.Source.Card.Name)
	}

	customer.Del(cust.ID)
}

func TestSourceBankAccountVerify(t *testing.T) {
	baTok, err := token.New(&stripe.TokenParams{
		Bank: &stripe.BankAccountParams{
			Country:           "US",
			Currency:          "usd",
			Routing:           "110000000",
			Account:           "000123456789",
			AccountHolderName: "Jane Austen",
			AccountHolderType: "individual",
		},
	})

	if baTok.Bank.AccountHolderName != "Jane Austen" {
		t.Errorf("Bank account name %q was not Jane Austen as expected.", baTok.Bank.AccountHolderName)
	}

	if err != nil {
		t.Error(err)
	}

	customerParams := &stripe.CustomerParams{}
	cust, err := customer.New(customerParams)
	if err != nil {
		t.Error(err)
	}

	source, err := New(&stripe.CustomerSourceParams{
		Customer: cust.ID,
		Source: &stripe.SourceParams{
			Token: baTok.ID,
		},
	})

	amounts := [2]uint8{32, 45}

	verifyParams := &stripe.SourceVerifyParams{
		Customer: cust.ID,
		Amounts:  amounts,
	}

	sourceVerified, err := Verify(source.ID, verifyParams)

	if err != nil {
		t.Error(err)
		return
	}

	target := sourceVerified.BankAccount

	if target.Status != bankaccount.VerifiedAccount {
		t.Errorf("Status (%q) does not match expected (%q) ", target.Status, bankaccount.VerifiedAccount)
	}

	customer.Del(cust.ID)
}

func TestSourceList(t *testing.T) {
	customerParams := &stripe.CustomerParams{}
	customerParams.SetSource(&stripe.CardParams{
		Number: "378282246310005",
		Month:  "06",
		Year:   "20",
	})

	cust, _ := customer.New(customerParams)

	sourceParams := &stripe.CustomerSourceParams{
		Customer: cust.ID,
	}
	sourceParams.SetSource(&stripe.CardParams{
		Number: "4242424242424242",
		Month:  "10",
		Year:   "20",
	})

	New(sourceParams)

	i := List(&stripe.SourceListParams{Customer: cust.ID})
	for i.Next() {
		paymentSource := i.PaymentSource()

		if paymentSource == nil {
			t.Error("No nil values expected")
		}

		if paymentSource.Card == nil {
			t.Error("No nil values expected")
		}

		if i.Meta() == nil {
			t.Error("No metadata returned")
		}
	}
	if err := i.Err(); err != nil {
		t.Error(err)
	}

	customer.Del(cust.ID)
}
