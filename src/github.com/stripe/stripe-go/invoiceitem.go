package stripe

import "encoding/json"

// InvoiceItemParams is the set of parameters that can be used when creating or updating an invoice item.
// For more details see https://stripe.com/docs/api#create_invoiceitem and https://stripe.com/docs/api#update_invoiceitem.
type InvoiceItemParams struct {
	Params
	Customer           string
	Amount             int64
	Currency           Currency
	Invoice, Desc, Sub string
	Discountable       bool
}

// InvoiceItemListParams is the set of parameters that can be used when listing invoice items.
// For more details see https://stripe.com/docs/api#list_invoiceitems.
type InvoiceItemListParams struct {
	ListParams
	Created  int64
	Customer string
}

// InvoiceItem is the resource represneting a Stripe invoice item.
// For more details see https://stripe.com/docs/api#invoiceitems.
type InvoiceItem struct {
	ID           string            `json:"id"`
	Live         bool              `json:"livemode"`
	Amount       int64             `json:"amount"`
	Currency     Currency          `json:"currency"`
	Customer     *Customer         `json:"customer"`
	Date         int64             `json:"date"`
	Proration    bool              `json:"proration"`
	Desc         string            `json:"description"`
	Invoice      *Invoice          `json:"invoice"`
	Meta         map[string]string `json:"metadata"`
	Sub          string            `json:"subscription"`
	Discountable bool              `json:"discountable"`
	Deleted      bool              `json:"deleted"`
}

// InvoiceItemList is a list of invoice items as retrieved from a list endpoint.
type InvoiceItemList struct {
	ListMeta
	Values []*InvoiceItem `json:"data"`
}

// UnmarshalJSON handles deserialization of an InvoiceItem.
// This custom unmarshaling is needed because the resulting
// property may be an id or the full struct if it was expanded.
func (i *InvoiceItem) UnmarshalJSON(data []byte) error {
	type invoiceitem InvoiceItem
	var ii invoiceitem
	err := json.Unmarshal(data, &ii)
	if err == nil {
		*i = InvoiceItem(ii)
	} else {
		// the id is surrounded by "\" characters, so strip them
		i.ID = string(data[1 : len(data)-1])
	}

	return nil
}
