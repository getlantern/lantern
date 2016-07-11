package countryspec

import (
	"testing"

	stripe "github.com/stripe/stripe-go"
	. "github.com/stripe/stripe-go/utils"
)

func init() {
	stripe.Key = GetTestKey()
}

func TestCountrySpecGet(t *testing.T) {
	country := "US"
	target, err := Get(country)

	if err != nil {
		t.Error(err)
	}

	if target.ID != country {
		t.Errorf("ID %v does not match expected ID %v\n", target.ID, country)
	}

	if target.DefaultCurrency != "usd" {
		t.Errorf("DefaultCurrency %v does not match expected value %v\n", target.DefaultCurrency, "usd")
	}

	if len(target.SupportedBankAccountCurrencies) == 0 {
		t.Errorf("Empty list of supported bank account currencies: %v", target.SupportedBankAccountCurrencies)
	}

	if len(target.SupportedBankAccountCurrencies["usd"]) == 0 {
		t.Errorf("Empty list of countries for the USD currency: %v", target.SupportedBankAccountCurrencies["usd"])
	}

	if len(target.SupportedPaymentCurrencies) == 0 {
		t.Errorf("Empty list of supported payment currencies: %v", target.SupportedPaymentCurrencies)
	}

	if len(target.SupportedPaymentMethods) == 0 {
		t.Errorf("Empty list of supported payment methods: %v", target.SupportedPaymentMethods)
	}

	if len(target.VerificationFields) == 0 {
		t.Errorf("Empty list of verification fields: %v", target.VerificationFields)
	}

	if len(target.VerificationFields[stripe.Individual].MinimumFields) == 0 {
		t.Errorf("Empty list of minimum verification fields for an individual in the US: %v", target.VerificationFields[stripe.Individual].MinimumFields)
	}
}

func TestCountrySpecList(t *testing.T) {
	params := &stripe.CountrySpecListParams{}
	params.Filters.AddFilter("limit", "", "5")
	params.Single = true

	i := List(params)
	for i.Next() {
		if i.CountrySpec() == nil {
			t.Error("No nil values expected")
		}
	}
	if err := i.Err(); err != nil {
		t.Error(err)
	}
}
