package stripe

import (
	"encoding/json"
	"testing"
)

func TestAccountUnmarshal(t *testing.T) {
	accountData := map[string]interface{}{
		"id": "acct_1234",
		"external_accounts": map[string]interface{}{
			"object":   "list",
			"has_more": true,
			"data": []map[string]interface{}{
				{
					"object": "bank_account",
					"id":     "ba_1234",
				},
				{
					"object": "card",
					"id":     "card_1234",
				},
			},
		},
	}

	bytes, err := json.Marshal(&accountData)
	if err != nil {
		t.Error(err)
	}

	var account Account
	err = json.Unmarshal(bytes, &account)
	if err != nil {
		t.Error(err)
	}

	if account.ID != "acct_1234" {
		t.Errorf("Problem deserializing account, got ID %v", account.ID)
	}

	if !account.ExternalAccounts.More {
		t.Errorf("Problem deserializing account, wrong value for list More")
	}

	if len(account.ExternalAccounts.Values) != 2 {
		t.Errorf("Problem deserializing account, got wrong number of external accounts")
	}

	bankAccount := account.ExternalAccounts.Values[0]
	if bankAccount == nil {
		t.Errorf("Problem deserializing account, didn't get a bank account")
	}
	if "ba_1234" != bankAccount.ID {
		t.Errorf("Problem deserializing account, got bank account ID %v", bankAccount.ID)
	}

	card := account.ExternalAccounts.Values[1]
	if card == nil {
		t.Errorf("Problem deserializing account, didn't get a card")
	}

	if "card_1234" != card.ID {
		t.Errorf("Problem deserializing account, got card ID %v", card.ID)
	}
}
