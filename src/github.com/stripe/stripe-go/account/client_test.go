package account

import (
	"testing"

	stripe "github.com/stripe/stripe-go"
	"github.com/stripe/stripe-go/bankaccount"
	"github.com/stripe/stripe-go/card"
	"github.com/stripe/stripe-go/currency"
	"github.com/stripe/stripe-go/token"
	. "github.com/stripe/stripe-go/utils"
)

func init() {
	stripe.Key = GetTestKey()
}

func TestAccountNew(t *testing.T) {
	params := &stripe.AccountParams{
		Managed:              true,
		Country:              "CA",
		BusinessUrl:          "www.stripe.com",
		BusinessName:         "Stripe",
		BusinessPrimaryColor: "#ffffff",
		SupportEmail:         "foo@bar.com",
		SupportUrl:           "www.stripe.com",
		SupportPhone:         "4151234567",
		LegalEntity: &stripe.LegalEntity{
			Type:         stripe.Individual,
			BusinessName: "Stripe Go",
			DOB: stripe.DOB{
				Day:   1,
				Month: 2,
				Year:  1990,
			},
		},
		TOSAcceptance: &stripe.TOSAcceptanceParams{
			IP:        "127.0.0.1",
			Date:      1437578361,
			UserAgent: "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_10_4) AppleWebKit/600.7.12 (KHTML, like Gecko) Version/8.0.7 Safari/600.7.12",
		},
	}

	_, err := New(params)
	if err != nil {
		t.Error(err)
	}
}

func TestAccountLegalEntity(t *testing.T) {
	params := &stripe.AccountParams{
		Managed: true,
		Country: "US",
		LegalEntity: &stripe.LegalEntity{
			Type:          stripe.Company,
			BusinessTaxID: "111111",
			SSN:           "1111",
			PersonalID:    "111111111",
			DOB: stripe.DOB{
				Day:   1,
				Month: 2,
				Year:  1990,
			},
		},
	}

	target, err := New(params)
	if err != nil {
		t.Error(err)
	}

	if !target.LegalEntity.BusinessTaxIDProvided {
		t.Errorf("Account is missing BusinessTaxIDProvided even though we submitted the value.\n")
	}

	if !target.LegalEntity.SSNProvided {
		t.Errorf("Account is missing SSNProvided even though we submitted the value.\n")
	}

	if !target.LegalEntity.PersonalIDProvided {
		t.Errorf("Account is missing PersonalIDProvided even though we submitted the value.\n")
	}
}

func TestAccountDelete(t *testing.T) {
	params := &stripe.AccountParams{
		Managed:              true,
		Country:              "CA",
		BusinessUrl:          "www.stripe.com",
		BusinessName:         "Stripe",
		BusinessPrimaryColor: "#ffffff",
		SupportEmail:         "foo@bar.com",
		SupportUrl:           "www.stripe.com",
		SupportPhone:         "4151234567",
		LegalEntity: &stripe.LegalEntity{
			Type:         stripe.Individual,
			BusinessName: "Stripe Go",
			DOB: stripe.DOB{
				Day:   1,
				Month: 2,
				Year:  1990,
			},
		},
	}

	acct, err := New(params)
	if err != nil {
		t.Error(err)
	}

	acctDel, err := Del(acct.ID)
	if err != nil {
		t.Error(err)
	}

	if !acctDel.Deleted {
		t.Errorf("Account id %q expected to be marked as deleted on the returned resource\n", acctDel.ID)
	}
}

func TestAccountReject(t *testing.T) {
	params := &stripe.AccountParams{
		Managed:              true,
		Country:              "CA",
		BusinessUrl:          "www.stripe.com",
		BusinessName:         "Stripe",
		BusinessPrimaryColor: "#ffffff",
		SupportEmail:         "foo@bar.com",
		SupportUrl:           "www.stripe.com",
		SupportPhone:         "4151234567",
		LegalEntity: &stripe.LegalEntity{
			Type:         stripe.Individual,
			BusinessName: "Stripe Go",
			DOB: stripe.DOB{
				Day:   1,
				Month: 2,
				Year:  1990,
			},
		},
	}

	acct, err := New(params)
	if err != nil {
		t.Error(err)
	}

	rejectedAcct, err := Reject(acct.ID, &stripe.AccountRejectParams{Reason: "fraud"})
	if err != nil {
		t.Error(err)
	}

	if rejectedAcct.Verification.DisabledReason != "rejected.fraud" {
		t.Error("Account DisabledReason did not change to rejected.fraud.")
	}
}

func TestAccountGetByID(t *testing.T) {
	params := &stripe.AccountParams{
		Managed: true,
		Country: "CA",
	}

	acct, _ := New(params)

	_, err := GetByID(acct.ID, nil)
	if err != nil {
		t.Error(err)
	}
}

func TestAccountUpdate(t *testing.T) {
	params := &stripe.AccountParams{
		Managed: true,
		Country: "CA",
	}

	acct, _ := New(params)

	params = &stripe.AccountParams{
		Statement: "Stripe Go",
	}

	_, err := Update(acct.ID, params)
	if err != nil {
		t.Error(err)
	}
}

func TestAccountUpdateWithBankAccount(t *testing.T) {
	params := &stripe.AccountParams{
		Managed: true,
		Country: "CA",
	}

	acct, _ := New(params)

	params = &stripe.AccountParams{
		ExternalAccount: &stripe.AccountExternalAccountParams{
			Country:  "US",
			Currency: "usd",
			Routing:  "110000000",
			Account:  "000123456789",
		},
	}

	_, err := Update(acct.ID, params)
	if err != nil {
		t.Error(err)
	}
}

func TestAccountAddExternalAccountsDefault(t *testing.T) {
	params := &stripe.AccountParams{
		Managed: true,
		Country: "CA",
		ExternalAccount: &stripe.AccountExternalAccountParams{
			Country:  "US",
			Currency: "usd",
			Routing:  "110000000",
			Account:  "000123456789",
		},
	}

	acct, _ := New(params)

	ba, err := bankaccount.New(&stripe.BankAccountParams{
		AccountID: acct.ID,
		Country:   "US",
		Currency:  "usd",
		Routing:   "110000000",
		Account:   "000111111116",
		Default:   true,
	})

	if err != nil {
		t.Error(err)
	}

	if ba.Default == false {
		t.Error("The new external account should be the default but isn't.")
	}

	baTok, err := token.New(&stripe.TokenParams{
		Bank: &stripe.BankAccountParams{
			Country:  "US",
			Currency: "usd",
			Routing:  "110000000",
			Account:  "000333333335",
		},
	})
	if err != nil {
		t.Error(err)
	}

	ba2, err := bankaccount.New(&stripe.BankAccountParams{
		AccountID: acct.ID,
		Token:     baTok.ID,
		Default:   true,
	})

	if err != nil {
		t.Error(err)
	}

	if ba2.Default == false {
		t.Error("The third external account should be the default but isn't.")
	}
}

func TestAccountUpdateWithToken(t *testing.T) {
	params := &stripe.AccountParams{
		Managed: true,
		Country: "CA",
	}

	acct, _ := New(params)

	tokenParams := &stripe.TokenParams{
		Bank: &stripe.BankAccountParams{
			Country: "US",
			Routing: "110000000",
			Account: "000123456789",
		},
	}

	tok, _ := token.New(tokenParams)

	params = &stripe.AccountParams{
		ExternalAccount: &stripe.AccountExternalAccountParams{
			Token: tok.ID,
		},
	}

	_, err := Update(acct.ID, params)
	if err != nil {
		t.Error(err)
	}
}

func TestAccountUpdateWithCardToken(t *testing.T) {
	params := &stripe.AccountParams{
		Managed: true,
		Country: "US",
	}

	acct, _ := New(params)

	tokenParams := &stripe.TokenParams{
		Card: &stripe.CardParams{
			Number:   "4000056655665556",
			Month:    "06",
			Year:     "20",
			Currency: "usd",
		},
	}

	tok, _ := token.New(tokenParams)

	cardParams := &stripe.CardParams{
		Account: acct.ID,
		Token:   tok.ID,
	}

	c, err := card.New(cardParams)

	if err != nil {
		t.Error(err)
	}

	if c.Currency != currency.USD {
		t.Errorf("Currency %v does not match expected value %v\n", c.Currency, currency.USD)
	}
}

func TestAccountGet(t *testing.T) {
	target, err := Get()

	if err != nil {
		t.Error(err)
	}

	if len(target.ID) == 0 {
		t.Errorf("Account is missing id\n")
	}

	if len(target.Country) == 0 {
		t.Errorf("Account is missing country\n")
	}

	if len(target.DefaultCurrency) == 0 {
		t.Errorf("Account is missing default currency\n")
	}

	if len(target.Name) == 0 {
		t.Errorf("Account is missing name\n")
	}

	if len(target.Email) == 0 {
		t.Errorf("Account is missing email\n")
	}

	if len(target.Timezone) == 0 {
		t.Errorf("Account is missing timezone\n")
	}

	if len(target.Statement) == 0 {
		t.Errorf("Account is missing Statement\n")
	}

	if len(target.BusinessName) == 0 {
		t.Errorf("Account is missing business name\n")
	}

	if len(target.BusinessPrimaryColor) == 0 {
		t.Errorf("Account is missing business primary color\n")
	}

	if len(target.BusinessUrl) == 0 {
		t.Errorf("Account is missing business URL\n")
	}

	if len(target.SupportPhone) == 0 {
		t.Errorf("Account is missing support phone\n")
	}

	if len(target.SupportEmail) == 0 {
		t.Errorf("Account is missing support email\n")
	}

	if len(target.SupportUrl) == 0 {
		t.Errorf("Account is missing support URL\n")
	}

	if len(target.DefaultCurrency) == 0 {
		t.Errorf("Account is missing default currency\n")
	}

	if len(target.Name) == 0 {
		t.Errorf("Account is missing name\n")
	}

	if len(target.Email) == 0 {
		t.Errorf("Account is missing email\n")
	}

	if len(target.Timezone) == 0 {
		t.Errorf("Account is missing timezone\n")
	}
}
