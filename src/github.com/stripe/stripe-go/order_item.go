package stripe

import "github.com/stripe/stripe-go/orderitem"

type OrderItemParams struct {
	Amount      int64
	Currency    Currency
	Description string
	Parent      string
	Quantity    *int64
	Type        orderitem.ItemType
}

type OrderItem struct {
	Amount      int64              `json:"amount"`
	Currency    Currency           `json:"currency"`
	Description string             `json:"description"`
	Parent      string             `json:"parent"`
	Quantity    int64              `json:"quantity"`
	Type        orderitem.ItemType `json:"type"`
}
