package stripe

import "encoding/json"

// ReversalParams is the set of parameters that can be used when reversing a transfer.
type ReversalParams struct {
	Params
	Transfer string
	Amount   uint64
	Fee      bool
}

// ReversalListParams is the set of parameters that can be used when listing reversals.
type ReversalListParams struct {
	ListParams
	Transfer string
}

// Reversal represents a transfer reversal.
type Reversal struct {
	ID       string            `json:"id"`
	Amount   uint64            `json:"amount"`
	Created  int64             `json:"created"`
	Currency Currency          `json:"currency"`
	Transfer string            `json:"transfer"`
	Meta     map[string]string `json:"metadata"`
	Tx       *Transaction      `json:"balance_transaction"`
}

// ReversalList is a list of object for reversals.
type ReversalList struct {
	ListMeta
	Values []*Reversal `json:"data"`
}

// UnmarshalJSON handles deserialization of a Reversal.
// This custom unmarshaling is needed because the resulting
// property may be an id or the full struct if it was expanded.
func (r *Reversal) UnmarshalJSON(data []byte) error {
	type reversal Reversal
	var rr reversal
	err := json.Unmarshal(data, &rr)
	if err == nil {
		*r = Reversal(rr)
	} else {
		// the id is surrounded by "\" characters, so strip them
		r.ID = string(data[1 : len(data)-1])
	}

	return nil
}
