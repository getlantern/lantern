package orderreturn

import (
	"fmt"
	"math/rand"
	"testing"
	"time"

	"github.com/stripe/stripe-go"
	"github.com/stripe/stripe-go/currency"
	"github.com/stripe/stripe-go/order"
	"github.com/stripe/stripe-go/product"
	"github.com/stripe/stripe-go/sku"
	. "github.com/stripe/stripe-go/utils"
)

func init() {
	stripe.Key = GetTestKey()
	rand.Seed(time.Now().UTC().UnixNano())
}

func CreateTestProductAndSku(t *testing.T) *stripe.SKU {
	active := true

	p, err := product.New(&stripe.ProductParams{
		Active:    &active,
		Name:      "test name",
		Desc:      "This is a description",
		Caption:   "This is a caption",
		Attrs:     []string{"attr1", "attr2"},
		URL:       "http://example.com",
		Shippable: &active,
	})

	if err != nil {
		t.Fatalf("%+v", err)
	}

	randID := fmt.Sprintf("TEST-SKU-%v", RandSeq(16))
	sku, err := sku.New(&stripe.SKUParams{
		ID:        randID,
		Active:    &active,
		Attrs:     map[string]string{"attr1": "val1", "attr2": "val2"},
		Price:     499,
		Currency:  "usd",
		Inventory: stripe.Inventory{Type: "bucket", Value: "limited"},
		Product:   p.ID,
		Image:     "http://example.com/foo.png",
	})

	if err != nil {
		t.Fatalf("%+v", err)
	}

	return sku
}

func TestOrderReturnList(t *testing.T) {
	sku := CreateTestProductAndSku(t)
	o, err := order.New(&stripe.OrderParams{
		Currency: currency.USD,
		Items: []*stripe.OrderItemParams{
			{
				Type:   "sku",
				Parent: sku.ID,
			},
		},
		Shipping: &stripe.ShippingParams{
			Name: "Jenny Rosen",
			Address: &stripe.AddressParams{
				Line1:      "1234 Main Street",
				City:       "Anytown",
				Country:    "US",
				PostalCode: "123456",
			},
			Phone: "6504244242",
		},
		Email: "jenny@ros.en",
	})
	if err != nil {
		t.Fatalf("%+v", err)
	}

	params := &stripe.OrderPayParams{}
	params.SetSource(&stripe.CardParams{
		Name:     "Stripe Tester",
		Number:   "4242424242424242",
		Month:    "06",
		Year:     "20",
		Address1: "1234 Main Street",
		Address2: "Apt 1",
		City:     "Anytown",
		State:    "CA",
	})

	_, err = order.Pay(o.ID, params)
	if err != nil {
		t.Fatalf("%+v", err)
	}

	var returnQuantity int64 = 1
	ret, err := order.Return(o.ID, &stripe.OrderReturnParams{
		Items: []*stripe.OrderItemParams{
			{
				Type:     "sku",
				Parent:   sku.ID,
				Quantity: &returnQuantity,
			},
		},
	})
	if err != nil {
		t.Fatalf("%+v", err)
	}
	if ret.Order.ID != o.ID {
		t.Fatalf("Got unexpected order ID: %s", ret.Order.ID)
	}

	fullRet, err := order.Return(o.ID, &stripe.OrderReturnParams{})
	if err != nil {
		t.Fatalf("%+v", err)
	}

	if fullRet.Order.ID != o.ID {
		t.Fatalf("Got unexpected order ID: %s", ret.Order.ID)
	}

	i := List(&stripe.OrderReturnListParams{Order: o.ID})
	count := 0
	for i.Next() {
		target := i.OrderReturn()

		if target.Order.ID != o.ID {
			t.Errorf(
				"Return list should only include order=%s, got %s\n",
				o.ID,
				target.Order.ID,
			)
		}
		count++

	}
	if count != 2 {
		t.Errorf("Expected to get 1 object, got %v", count)
	}
	if err := i.Err(); err != nil {
		t.Error(err)
	}
}
