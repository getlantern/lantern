package orderitem

// OrderItemType represents one of the possible types that an order's OrderItem
// can have.
type ItemType string

const (
	SKU      ItemType = "sku"
	Tax      ItemType = "tax"
	Shipping ItemType = "shipping"
	Discount ItemType = "discount"
)
