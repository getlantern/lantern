package stripe

import "encoding/json"

type OrderReturn struct {
	ID       string      `json:"id"`
	Amount   int64       `json:"amount"`
	Created  int64       `json:"created"`
	Currency Currency    `json:"currency"`
	Items    []OrderItem `json:"items"`
	Live     bool        `json:"livemode"`
	Order    Order       `json:"order"`
	Refund   *Refund     `json:"refund"`
}

// OrderReturnList is a list of returns as retrieved from a list endpoint.
type OrderReturnList struct {
	ListMeta
	Values []*OrderReturn `json:"data"`
}

// OrderReturnListParams is the set of parameters that can be used when listing
// returns. For more details, see: https://stripe.com/docs/api#list_order_returns.
type OrderReturnListParams struct {
	ListParams
	Order string
}

// UnmarshalJSON handles deserialization of an OrderReturn.
// This custom unmarshaling is needed because the resulting
// property may be an id or the full struct if it was expanded.
func (ret *OrderReturn) UnmarshalJSON(data []byte) error {
	type orderReturn OrderReturn
	var rr orderReturn
	err := json.Unmarshal(data, &rr)
	if err == nil {
		*ret = OrderReturn(rr)
	} else {
		// the id is surrounded by "\" characters, so strip them
		ret.ID = string(data[1 : len(data)-1])
	}

	return nil
}
