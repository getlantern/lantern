package stripe

import (
	"encoding/json"
)

// OrderStatus represents the statuses of an order object.
type OrderStatus string

const (
	StatusCreated   OrderStatus = "created"
	StatusPaid      OrderStatus = "paid"
	StatusCanceled  OrderStatus = "canceled"
	StatusFulfilled OrderStatus = "fulfilled"
	StatusReturned  OrderStatus = "returned"
)

type OrderParams struct {
	Params
	Currency Currency
	Customer string
	Email    string
	Items    []*OrderItemParams
	Shipping *ShippingParams
}

type ShippingParams struct {
	Name    string
	Address *AddressParams
	Phone   string
}

type AddressParams struct {
	Line1      string
	Line2      string
	City       string
	State      string
	PostalCode string
	Country    string
}

type OrderUpdateParams struct {
	Params
	Coupon                 string
	SelectedShippingMethod string
	Status                 OrderStatus
}

// OrderReturnParams is the set of parameters that can be used when returning
// orders. For more details, see: https://stripe.com/docs/api#return_order.
type OrderReturnParams struct {
	Params
	Items []*OrderItemParams
}

type Shipping struct {
	Name    string  `json:"name"`
	Address Address `json:"address"`
	Phone   string  `json:"phone"`
}

type ShippingMethod struct {
	ID               string            `json:"id"`
	Amount           int64             `json:"amount"`
	Currency         Currency          `json:"currency"`
	Description      string            `json:"description"`
	DeliveryEstimate *DeliveryEstimate `json:"delivery_estimate"`
}

type EstimateType string

const (
	Exact EstimateType = "exact"
	Range EstimateType = "range"
)

type DeliveryEstimate struct {
	Type EstimateType `json:"type"`
	// If Type == Range
	Earliest string `json:"earliest"`
	Latest   string `json:"latest"`
	// If Type == Exact
	Date string `json:"date"`
}

type Order struct {
	ID                     string            `json:"id"`
	Amount                 int64             `json:"amount"`
	Application            string            `json:"application"`
	ApplicationFee         int64             `json:"application_fee"`
	Charge                 Charge            `json:"charge"`
	Created                int64             `json:"created"`
	Currency               Currency          `json:"currency"`
	Customer               Customer          `json:"customer"`
	Email                  string            `json:"email"`
	Items                  []OrderItem       `json:"items"`
	Meta                   map[string]string `json:"metadata"`
	SelectedShippingMethod *string           `json:"selected_shipping_method"`
	Shipping               Shipping          `json:"shipping"`
	ShippingMethods        []ShippingMethod  `json:"shipping_methods"`
	Status                 OrderStatus       `json:"status"`
	Updated                int64             `json:"updated"`
}

// OrderList is a list of orders as retrieved from a list endpoint.
type OrderList struct {
	ListMeta
	Values []*Order `json:"data"`
}

// OrderListParams is the set of parameters that can be used when
// listing orders. For more details, see:
// https://stripe.com/docs/api#list_orders.
type OrderListParams struct {
	ListParams
	IDs    []string
	Status OrderStatus
}

// OrderPayParams is the set of parameters that can be used when
// paying orders. For more details, see:
// https://stripe.com/docs/api#pay_order.
type OrderPayParams struct {
	Params
	Source         *SourceParams
	Customer       string
	ApplicationFee int64
	Email          string
}

// SetSource adds valid sources to a OrderParams object,
// returning an error for unsupported sources.
func (op *OrderPayParams) SetSource(sp interface{}) error {
	source, err := SourceParamsFor(sp)
	op.Source = source
	return err
}

// UnmarshalJSON handles deserialization of an Order.
// This custom unmarshaling is needed because the resulting
// property may be an id or the full struct if it was expanded.
func (o *Order) UnmarshalJSON(data []byte) error {
	type order Order
	var oo order
	err := json.Unmarshal(data, &oo)
	if err == nil {
		*o = Order(oo)
		{
		}
	} else {
		// the id is surrounded by "\" characters, so strip them
		o.ID = string(data[1 : len(data)-1])
	}

	return nil
}
