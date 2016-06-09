package stripe

import (
	"encoding/json"
	"fmt"
)

// BitcoinReceiverListParams is the set of parameters that can be used when listing BitcoinReceivers.
// For more details see https://stripe.com/docs/api/#list_bitcoin_receivers.
type BitcoinReceiverListParams struct {
	ListParams
	NotFilled, NotActive, Uncaptured bool
}

// BitcoinReceiverParams is the set of parameters that can be used when creating a BitcoinReceiver.
// For more details see https://stripe.com/docs/api/#create_bitcoin_receiver.
type BitcoinReceiverParams struct {
	Params
	Amount      uint64
	Currency    Currency
	Desc, Email string
}

// BitcoinReceiverUpdateParams is the set of parameters that can be used when
// updating a BitcoinReceiver. For more details see
// https://stripe.com/docs/api/#update_bitcoin_receiver.
type BitcoinReceiverUpdateParams struct {
	Params
	Desc, Email, RefundAddr string
}

// BitcoinReceiver is the resource representing a Stripe bitcoin receiver.
// For more details see https://stripe.com/docs/api/#bitcoin_receivers
type BitcoinReceiver struct {
	ID                    string                  `json:"id"`
	Created               int64                   `json:"created"`
	Currency              Currency                `json:"currency"`
	Amount                uint64                  `json:"amount"`
	AmountReceived        uint64                  `json:"amount_received"`
	BitcoinAmount         uint64                  `json:"bitcoin_amount"`
	BitcoinAmountReceived uint64                  `json:"bitcoin_amount_received"`
	Filled                bool                    `json:"filled"`
	Active                bool                    `json:"active"`
	RejectTransactions    bool                    `json:"reject_transactions"`
	Desc                  string                  `json:"description"`
	InboundAddress        string                  `json:"inbound_address"`
	RefundAddress         string                  `json:"refund_address"`
	BitcoinUri            string                  `json:"bitcoin_uri"`
	Meta                  map[string]string       `json:"metadata"`
	Email                 string                  `json:"email"`
	Payment               string                  `json:"payment"`
	Customer              string                  `json:"customer"`
	Transactions          *BitcoinTransactionList `json:"transactions"`
}

// BitcoinReceiverList is a list of bitcoin receivers as retrieved from a list endpoint.
type BitcoinReceiverList struct {
	ListMeta
	Values []*BitcoinReceiver `json:"data"`
}

// Display human readable representation of a BitcoinReceiver.
func (br *BitcoinReceiver) Display() string {
	var filled string
	if br.Filled {
		filled = "Filled"
	} else if br.BitcoinAmountReceived > 0 {
		filled = "Partially filled"
	} else {
		filled = "Unfilled"
	}
	return fmt.Sprintf("%s bitcoin receiver (%d/%d %s)", filled, br.AmountReceived, br.Amount, br.Currency)
}

// UnmarshalJSON handles deserialization of a BitcoinReceiver.
// This custom unmarshaling is needed because the resulting
// property may be an id or the full struct if it was expanded.
func (br *BitcoinReceiver) UnmarshalJSON(data []byte) error {
	type bitcoinReceiver BitcoinReceiver
	var r bitcoinReceiver
	err := json.Unmarshal(data, &r)
	if err == nil {
		*br = BitcoinReceiver(r)
	} else {
		// the id is surrounded by "\" characters, so strip them
		br.ID = string(data[1 : len(data)-1])
	}

	return nil
}
