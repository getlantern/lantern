package bankaccount

import (
	"testing"

	stripe "github.com/stripe/stripe-go"
	"github.com/stripe/stripe-go/customer"
	"github.com/stripe/stripe-go/token"
	. "github.com/stripe/stripe-go/utils"
)

func init() {
	stripe.Key = GetTestKey()
}

func TestBankAccountDel(t *testing.T) {
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
	if err != nil {
		t.Error(err)
	}

	customerParams := &stripe.CustomerParams{}
	customerParams.SetSource(baTok.ID)
	cust, _ := customer.New(customerParams)
	if err != nil {
		t.Error(err)
	}

	baDel, err := Del(cust.DefaultSource.ID, &stripe.BankAccountParams{Customer: cust.ID})
	if err != nil {
		t.Error(err)
	}

	if !baDel.Deleted {
		t.Errorf("Bank account id %q expected to be marked as deleted on the returned resource\n", baDel.ID)
	}

	customer.Del(cust.ID)
}
