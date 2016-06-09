package recipient

import (
	"testing"

	stripe "github.com/stripe/stripe-go"
	"github.com/stripe/stripe-go/currency"
	"github.com/stripe/stripe-go/token"
	. "github.com/stripe/stripe-go/utils"
)

func init() {
	stripe.Key = GetTestKey()
}

func TestRecipientNew(t *testing.T) {
	recipientParams := &stripe.RecipientParams{
		Name:  "Recipient Name",
		Type:  Individual,
		TaxID: "000000000",
		Email: "a@b.com",
		Desc:  "Recipient Desc",
		Bank: &stripe.BankAccountParams{
			Country: "US",
			Routing: "110000000",
			Account: "000123456789",
		},
		Card: &stripe.CardParams{
			Name:   "Test Debit",
			Number: "4000056655665556",
			Month:  "10",
			Year:   "20",
		},
	}

	target, err := New(recipientParams)

	if err != nil {
		t.Error(err)
	}

	if target.Name != recipientParams.Name {
		t.Errorf("Name %q does not match expected name %q\n", target.Name, recipientParams.Name)
	}

	if target.Type != recipientParams.Type {
		t.Errorf("Type %q does not match expected type %q\n", target.Type, recipientParams.Type)
	}

	if target.Email != recipientParams.Email {
		t.Errorf("Email %q does not match expected email %q\n", target.Email, recipientParams.Email)
	}

	if target.Desc != recipientParams.Desc {
		t.Errorf("Description %q does not match expected description %q\n", target.Desc, recipientParams.Desc)
	}

	if target.Created == 0 {
		t.Errorf("Created date is not set\n")
	}

	if target.Bank == nil {
		t.Errorf("Bank account is not set\n")
	}

	if target.Bank.Country != recipientParams.Bank.Country {
		t.Errorf("Bank country %q does not match expected country %q\n", target.Bank.Country, recipientParams.Bank.Country)
	}

	if target.Bank.Currency != currency.USD {
		t.Errorf("Bank currency %q does not match expected value\n", target.Bank.Currency)
	}

	if target.Bank.LastFour != "6789" {
		t.Errorf("Bank last four %q does not match expected value\n", target.Bank.LastFour)
	}

	if len(target.Bank.Name) == 0 {
		t.Errorf("Bank name is not set\n")
	}

	if target.Cards == nil || target.Cards.Count != 1 {
		t.Errorf("Recipient cards not set\n")
	}

	if len(target.DefaultCard.ID) == 0 {
		t.Errorf("Recipient default card is not set\n")
	}

	Del(target.ID)
}

func TestRecipientNewToken(t *testing.T) {

	tokenParams := &stripe.TokenParams{
		Bank: &stripe.BankAccountParams{
			Country: "US",
			Routing: "110000000",
			Account: "000123456789",
		},
	}

	tok, _ := token.New(tokenParams)

	recipientParams := &stripe.RecipientParams{
		Name:  "Recipient Name",
		Type:  Individual,
		TaxID: "000000000",
		Email: "a@b.com",
		Desc:  "Recipient Desc",
		Bank: &stripe.BankAccountParams{
			Token: tok.ID,
		},
		Card: &stripe.CardParams{
			Name:   "Test Debit",
			Number: "4000056655665556",
			Month:  "10",
			Year:   "20",
		},
	}

	target, err := New(recipientParams)

	if err != nil {
		t.Error(err)
	}

	if target.Name != recipientParams.Name {
		t.Errorf("Name %q does not match expected name %q\n", target.Name, recipientParams.Name)
	}

	if target.Type != recipientParams.Type {
		t.Errorf("Type %q does not match expected type %q\n", target.Type, recipientParams.Type)
	}

	if target.Email != recipientParams.Email {
		t.Errorf("Email %q does not match expected email %q\n", target.Email, recipientParams.Email)
	}

	if target.Desc != recipientParams.Desc {
		t.Errorf("Description %q does not match expected description %q\n", target.Desc, recipientParams.Desc)
	}

	if target.Created == 0 {
		t.Errorf("Created date is not set\n")
	}

	if target.Bank == nil {
		t.Errorf("Bank account is not set\n")
	}

	if target.Bank.Country != tokenParams.Bank.Country {
		t.Errorf("Bank country %q does not match expected country %q\n", target.Bank.Country, tokenParams.Bank.Country)
	}

	if target.Bank.Currency != currency.USD {
		t.Errorf("Bank currency %q does not match expected value\n", target.Bank.Currency)
	}

	if target.Bank.LastFour != "6789" {
		t.Errorf("Bank last four %q does not match expected value\n", target.Bank.LastFour)
	}

	if len(target.Bank.Name) == 0 {
		t.Errorf("Bank name is not set\n")
	}

	if target.Cards == nil || target.Cards.Count != 1 {
		t.Errorf("Recipient cards not set\n")
	}

	if len(target.DefaultCard.ID) == 0 {
		t.Errorf("Recipient default card is not set\n")
	}

	Del(target.ID)
}

func TestRecipientGet(t *testing.T) {
	recipientParams := &stripe.RecipientParams{
		Name: "Recipient Name",
		Type: Individual,
	}

	rec, _ := New(recipientParams)

	target, err := Get(rec.ID, nil)

	if err != nil {
		t.Error(err)
	}

	if len(target.ID) == 0 {
		t.Errorf("Recipient not found\n")
	}

	Del(target.ID)
}

func TestRecipientUpdate(t *testing.T) {
	recipientParams := &stripe.RecipientParams{
		Name:  "Original Name",
		Type:  Individual,
		Email: "original@b.com",
		Desc:  "Original Desc",
	}

	original, _ := New(recipientParams)

	updated := &stripe.RecipientParams{
		Name:  "Updated Name",
		Email: "updated@b.com",
		Desc:  "Updated Desc",
	}

	target, err := Update(original.ID, updated)

	if err != nil {
		t.Error(err)
	}

	if target.Name != updated.Name {
		t.Errorf("Name %q does not match expected name %q\n", target.Name, updated.Name)
	}

	if target.Email != updated.Email {
		t.Errorf("Email %q does not match expected email %q\n", target.Email, updated.Email)
	}

	if target.Desc != updated.Desc {
		t.Errorf("Description %q does not match expected description %q\n", target.Desc, updated.Desc)
	}

	Del(target.ID)
}

func TestRecipientUpdateBankAccount(t *testing.T) {
	tokenParams := &stripe.TokenParams{
		Bank: &stripe.BankAccountParams{
			Country: "US",
			Routing: "110000000",
			Account: "000123456789",
		},
	}

	tok, _ := token.New(tokenParams)

	recipientParams := &stripe.RecipientParams{
		Name:  "Original Name",
		Type:  Individual,
		Email: "original@b.com",
		Desc:  "Original Desc",
	}

	original, _ := New(recipientParams)

	updateParamsToken := &stripe.RecipientParams{
		Bank: &stripe.BankAccountParams{
			Token: tok.ID,
		},
	}

	target, err := Update(original.ID, updateParamsToken)

	if err != nil {
		t.Error(err)
	}

	if target.Bank == nil {
		t.Errorf("Bank account is not set\n")
	}

	if target.Bank.Country != tokenParams.Bank.Country {
		t.Errorf("Bank country %q does not match expected country %q\n", target.Bank.Country, tokenParams.Bank.Country)
	}

	if target.Bank.Currency != currency.USD {
		t.Errorf("Bank currency %q does not match expected value\n", target.Bank.Currency)
	}

	if target.Bank.LastFour != "6789" {
		t.Errorf("Bank last four %q does not match expected value\n", target.Bank.LastFour)
	}

	if len(target.Bank.Name) == 0 {
		t.Errorf("Bank name is not set\n")
	}

	updateParamsBankAccount := &stripe.RecipientParams{
		Bank: &stripe.BankAccountParams{
			Country: "US",
			Routing: "110000000",
			Account: "000333333335",
		},
	}

	target2, err := Update(original.ID, updateParamsBankAccount)

	if err != nil {
		t.Error(err)
	}

	if target2.Bank == nil {
		t.Errorf("Bank account is not set\n")
	}

	if target2.Bank.Country != tokenParams.Bank.Country {
		t.Errorf("Bank country %q does not match expected country %q\n", target2.Bank.Country, tokenParams.Bank.Country)
	}

	if target2.Bank.Currency != currency.USD {
		t.Errorf("Bank currency %q does not match expected value\n", target2.Bank.Currency)
	}

	if target2.Bank.LastFour != "3335" {
		t.Errorf("Bank last four %q does not match expected value\n", target2.Bank.LastFour)
	}

	if len(target2.Bank.Name) == 0 {
		t.Errorf("Bank name is not set\n")
	}

	Del(target2.ID)
}

func TestRecipientDel(t *testing.T) {
	recipientParams := &stripe.RecipientParams{
		Name: "Recipient Name",
		Type: Individual,
	}

	rec, err := New(recipientParams)

	if err != nil {
		t.Error(err)
	}

	recDel, err := Del(rec.ID)

	if err != nil {
		t.Error(err)
	}

	if !recDel.Deleted {
		t.Errorf("Recipient id %q expected to be marked as deleted on the returned resource\n", recDel.ID)
	}
}

func TestRecipientList(t *testing.T) {
	recipientParams := &stripe.RecipientParams{
		Name: "Recipient Name",
		Type: Individual,
	}

	recipients := make([]string, 5)

	for i := 0; i < 5; i++ {
		rec, _ := New(recipientParams)
		recipients[i] = rec.ID
	}

	i := List(nil)
	for i.Next() {
		if i.Recipient() == nil {
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
