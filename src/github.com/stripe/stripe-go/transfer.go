package stripe

import "encoding/json"

// TransferStatus is the list of allowed values for the transfer's status.
// Allowed values are "paid", "pending", "in_transit",  "failed", "canceled".
type TransferStatus string

// TransferType is the list of allowed values for the transfer's type.
// Allowed values are "bank_account", "card", "stripe_account".
type TransferType string

// TransferSourceType is the list of allowed values for the transfer's source_type field.
// Allowed values are "alipay_account", bank_account", "bitcoin_receiver", "card".
type TransferSourceType string

// TransferFailCode is the list of allowed values for the transfer's failure code.
// Allowed values are "insufficient_funds", "account_closed", "no_account",
// "invalid_account_number", "debit_not_authorized", "bank_ownership_changed",
// "account_frozen", "could_not_process", "bank_account_restricted", "invalid_currency".
type TransferFailCode string

// TransferParams is the set of parameters that can be used when creating or updating a transfer.
// For more details see https://stripe.com/docs/api#create_transfer and https://stripe.com/docs/api#update_transfer.
type TransferParams struct {
	Params
	Amount                                                 int64
	Fee                                                    uint64
	Currency                                               Currency
	Recipient, Desc, Statement, Bank, Card, SourceTx, Dest string
	SourceType                                             TransferSourceType
}

// TransferListParams is the set of parameters that can be used when listing transfers.
// For more details see https://stripe.com/docs/api#list_transfers.
type TransferListParams struct {
	ListParams
	Created, Date int64
	Recipient     string
	Status        TransferStatus
}

// Transfer is the resource representing a Stripe transfer.
// For more details see https://stripe.com/docs/api#transfers.
type Transfer struct {
	ID             string             `json:"id"`
	Live           bool               `json:"livemode"`
	Amount         int64              `json:"amount"`
	AmountReversed int64              `json:"amount_reversed"`
	Currency       Currency           `json:"currency"`
	Created        int64              `json:"created"`
	Date           int64              `json:"date"`
	Desc           string             `json:"description"`
	FailCode       TransferFailCode   `json:"failure_code"`
	FailMsg        string             `json:"failure_message"`
	Status         TransferStatus     `json:"status"`
	Type           TransferType       `json:"type"`
	Tx             *Transaction       `json:"balance_transaction"`
	Meta           map[string]string  `json:"metadata"`
	Bank           *BankAccount       `json:"bank_account"`
	Card           *Card              `json:"card"`
	Recipient      *Recipient         `json:"recipient"`
	Statement      string             `json:"statement_descriptor"`
	Reversals      *ReversalList      `json:"reversals"`
	Reversed       bool               `json:"reversed"`
	SourceTx       *Transaction       `json:"source_transaction"`
	SourceType     TransferSourceType `json:"source_type"`
}

// TransferList is a list of transfers as retrieved from a list endpoint.
type TransferList struct {
	ListMeta
	Values []*Transfer `json:"data"`
}

// UnmarshalJSON handles deserialization of a Transfer.
// This custom unmarshaling is needed because the resulting
// property may be an id or the full struct if it was expanded.
func (t *Transfer) UnmarshalJSON(data []byte) error {
	type transfer Transfer
	var tb transfer
	err := json.Unmarshal(data, &tb)
	if err == nil {
		*t = Transfer(tb)
	} else {
		// the id is surrounded by "\" characters, so strip them
		t.ID = string(data[1 : len(data)-1])
	}

	return nil
}
