package stripe

// Discount is the resource representing a Stripe discount.
// For more details see https://stripe.com/docs/api#discounts.
type Discount struct {
	Coupon   *Coupon `json:"coupon"`
	Customer string  `json:"customer"`
	Start    int64   `json:"start"`
	End      int64   `json:"end"`
	Sub      string  `json:"subscription"`
	Deleted  bool    `json:"deleted"`
}
