package customer

import (
	"testing"

	stripe "github.com/stripe/stripe-go"
	"github.com/stripe/stripe-go/coupon"
	"github.com/stripe/stripe-go/discount"
	. "github.com/stripe/stripe-go/utils"
)

func init() {
	stripe.Key = GetTestKey()
}

func TestCustomerNew(t *testing.T) {
	customerParams := &stripe.CustomerParams{
		Balance:       -123,
		Desc:          "Test Customer",
		Email:         "a@b.com",
		BusinessVatID: "123456789",
	}
	customerParams.SetSource(&stripe.CardParams{
		Name:   "Test Card",
		Number: "378282246310005",
		Month:  "06",
		Year:   "20",
	})

	customerParams.AddMeta("key", "value")
	target, err := New(customerParams)

	if err != nil {
		t.Error(err)
	}

	if target.Balance != customerParams.Balance {
		t.Errorf("Balance %v does not match expected balance %v\n", target.Balance, customerParams.Balance)
	}

	if target.Desc != customerParams.Desc {
		t.Errorf("Description %q does not match expected description %q\n", target.Desc, customerParams.Desc)
	}

	if target.Email != customerParams.Email {
		t.Errorf("Email %q does not match expected email %q\n", target.Email, customerParams.Email)
	}

	if target.BusinessVatID != customerParams.BusinessVatID {
		t.Errorf("Business Vat Id %q does not match expected description %q\n", target.BusinessVatID, customerParams.BusinessVatID)
	}

	if target.Meta["id"] != customerParams.Meta["id"] {
		t.Errorf("Meta %v does not match expected Meta %v\n", target.Meta, customerParams.Meta)
	}

	if target.Sources == nil {
		t.Errorf("No sources recorded\n")
	}

	if target.Sources.Count != 1 {
		t.Errorf("Unexpected number of cards %v\n", target.Sources.Count)
	}

	if target.Sources.Values[0].Card.Name != customerParams.Source.Card.Name {
		t.Errorf("Card name %q does not match expected name %q\n", target.Sources.Values[0].Card.Name, customerParams.Source.Card.Name)
	}

	Del(target.ID)
}

func TestCustomerNewWithShipping(t *testing.T) {
	customerParams := &stripe.CustomerParams{
		Shipping: &stripe.CustomerShippingDetails{
			Name: "Shipping Name",
			Address: stripe.Address{
				Line1: "One Street",
			},
		},
	}

	target, err := New(customerParams)

	if err != nil {
		t.Error(err)
	}

	if target.Shipping.Name != customerParams.Shipping.Name {
		t.Errorf("Shipping name %q does not match expected name %v\n", target.Shipping.Name, customerParams.Shipping.Name)
	}

	if target.Shipping.Address.Line1 != customerParams.Shipping.Address.Line1 {
		t.Errorf("Shipping address line 1 %q does not match expected address line 1 %v\n", target.Shipping.Address.Line1, customerParams.Shipping.Address.Line1)
	}

	Del(target.ID)
}

func TestCustomerUpdateWithShipping(t *testing.T) {

	customerParams := &stripe.CustomerParams{
		Shipping: &stripe.CustomerShippingDetails{
			Name: "Shipping Name",
			Address: stripe.Address{
				Line1: "One Street",
				Line2: "Apt 1",
				City:  "Somewhere",
				State: "SW",
				Zip:   "10044",
			},
		},
	}

	target, err := New(customerParams)

	customerParams.Shipping.Name = "Updated Shipping"
	customerParams.Shipping.Address.Line1 = "Two Street"

	target, err = Update(target.ID, customerParams)

	if err != nil {
		t.Error(err)
	}

	if target.Shipping.Name != customerParams.Shipping.Name {
		t.Errorf("Shipping name %q does not match expected name %v\n", target.Shipping.Name, customerParams.Shipping.Name)
	}

	if target.Shipping.Address.Line1 != customerParams.Shipping.Address.Line1 {
		t.Errorf("Shipping address line 1 %q does not match expected address line 1 %v\n", target.Shipping.Address.Line1, customerParams.Shipping.Address.Line1)
	}
	if target.Shipping.Address.Line2 != customerParams.Shipping.Address.Line2 {
		t.Errorf("Shipping address line 2 %q does not match expected address line 2 %v\n", target.Shipping.Address.Line2, customerParams.Shipping.Address.Line2)
	}
	if target.Shipping.Address.City != customerParams.Shipping.Address.City {
		t.Errorf("Shipping address city %q does not match expected address city %v\n", target.Shipping.Address.City, customerParams.Shipping.Address.City)
	}
	if target.Shipping.Address.State != customerParams.Shipping.Address.State {
		t.Errorf("Shipping address state %q does not match expected address state %v\n", target.Shipping.Address.State, customerParams.Shipping.Address.State)
	}
	if target.Shipping.Address.Zip != customerParams.Shipping.Address.Zip {
		t.Errorf("Shipping address zip %q does not match expected address zip %v\n", target.Shipping.Address.Zip, customerParams.Shipping.Address.Zip)
	}

	Del(target.ID)
}

func TestCustomerGet(t *testing.T) {
	res, _ := New(nil)

	target, err := Get(res.ID, nil)

	if err != nil {
		t.Error(err)
	}

	if target.ID != res.ID {
		t.Errorf("Customer id %q does not match expected id %q\n", target.ID, res.ID)
	}

	Del(res.ID)
}

func TestCustomerDel(t *testing.T) {
	res, _ := New(nil)

	customerDel, err := Del(res.ID)

	if err != nil {
		t.Error(err)
	}

	if !customerDel.Deleted {
		t.Errorf("Customer id %q expected to be marked as deleted on the returned resource\n", res.ID)
	}

	target, err := Get(res.ID, nil)
	if err != nil {
		t.Error(err)
	}

	if !target.Deleted {
		t.Errorf("Customer id %q expected to be marked as deleted\n", target.ID)
	}
}

func TestCustomerUpdate(t *testing.T) {
	customerParams := &stripe.CustomerParams{
		Balance:       7,
		Desc:          "Original Desc",
		Email:         "first@b.com",
		BusinessVatID: "123456789",
	}
	customerParams.SetSource(&stripe.CardParams{
		Number: "378282246310005",
		Month:  "06",
		Year:   "20",
	})

	original, _ := New(customerParams)

	updated := &stripe.CustomerParams{
		Balance:       -10,
		Desc:          "Updated Desc",
		Email:         "desc@b.com",
		BusinessVatID: "5555555",
	}
	updated.SetSource(&stripe.CardParams{
		Number: "4242424242424242",
		Month:  "10",
		Year:   "20",
		CVC:    "123",
	})

	target, err := Update(original.ID, updated)

	if err != nil {
		t.Error(err)
	}

	if target.Balance != updated.Balance {
		t.Errorf("Balance %v does not match expected balance %v\n", target.Balance, updated.Balance)
	}

	if target.Desc != updated.Desc {
		t.Errorf("Description %q does not match expected description %q\n", target.Desc, updated.Desc)
	}

	if target.Email != updated.Email {
		t.Errorf("Email %q does not match expected email %q\n", target.Email, updated.Email)
	}

	if target.BusinessVatID != updated.BusinessVatID {
		t.Errorf("Business Vat Id %q does not match expected description %q\n", target.BusinessVatID, updated.BusinessVatID)
	}

	if target.Sources == nil {
		t.Errorf("No sources recorded\n")
	}

	Del(target.ID)
}

func TestCustomerDiscount(t *testing.T) {
	couponParams := &stripe.CouponParams{
		Duration: coupon.Forever,
		ID:       "customer_coupon",
		Percent:  99,
	}

	coupon.New(couponParams)

	customerParams := &stripe.CustomerParams{
		Coupon: "customer_coupon",
	}

	target, err := New(customerParams)

	if err != nil {
		t.Error(err)
	}

	if target.Discount == nil {
		t.Errorf("Discount not found, but one was expected\n")
	}

	if target.Discount.Coupon == nil {
		t.Errorf("Coupon not found, but one was expected\n")
	}

	if target.Discount.Coupon.ID != customerParams.Coupon {
		t.Errorf("Coupon id %q does not match expected id %q\n", target.Discount.Coupon.ID, customerParams.Coupon)
	}

	discountDel, err := discount.Del(target.ID)

	if err != nil {
		t.Error(err)
	}

	if !discountDel.Deleted {
		t.Errorf("Discount expected to be marked as deleted on the returned resource\n")
	}

	Del(target.ID)
	coupon.Del("customer_coupon")
}

func TestCustomerList(t *testing.T) {
	customers := make([]string, 5)

	for i := 0; i < 5; i++ {
		cust, _ := New(nil)
		customers[i] = cust.ID
	}

	i := List(nil)
	for i.Next() {
		if i.Customer() == nil {
			t.Error("No nil values expected")
		}

		if i.Meta() == nil {
			t.Error("No metadata returned")
		}
	}
	if err := i.Err(); err != nil {
		t.Error(err)
	}

	for _, v := range customers {
		Del(v)
	}
}
