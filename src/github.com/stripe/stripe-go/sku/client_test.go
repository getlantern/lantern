package sku

import (
	"fmt"
	"math/rand"
	"testing"
	"time"

	stripe "github.com/stripe/stripe-go"
	"github.com/stripe/stripe-go/product"
	. "github.com/stripe/stripe-go/utils"
)

func init() {
	stripe.Key = GetTestKey()
	rand.Seed(time.Now().UTC().UnixNano())
}

func TestSKUUpdateInventory(t *testing.T) {
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
	sku, err := New(&stripe.SKUParams{
		ID:        randID,
		Active:    &active,
		Attrs:     map[string]string{"attr1": "val1", "attr2": "val2"},
		Price:     499,
		Currency:  "usd",
		Inventory: stripe.Inventory{Type: "bucket", Value: "limited"},
		Product:   p.ID,
		Image:     "http://example.com/foo.png",
	})

	updatedSKU, err := Update(sku.ID, &stripe.SKUParams{
		Inventory: stripe.Inventory{Type: "bucket", Value: "in_stock"},
	})
	if err != nil {
		t.Fatalf("%+v", err)
	}

	if updatedSKU.Inventory.Value != "in_stock" {
		t.Errorf("unable to update inventory for SKU")
	}
}

func TestSKUCreate(t *testing.T) {
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
	sku, err := New(&stripe.SKUParams{
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

	if sku.ID == "" {
		t.Errorf("ID is not set %v", sku.ID)
	}

	if sku.Created == 0 {
		t.Errorf("Created date is not set")
	}

	if sku.Updated == 0 {
		t.Errorf("Updated is not set")
	}

	if len(sku.Attrs) != 2 {
		t.Errorf("Invalid attributes: %v", sku.Attrs)
	}

	if sku.Attrs["attr1"] != "val1" {
		t.Errorf("Invalid attributes: %v", sku.Attrs)
	}

	if sku.Attrs["attr2"] != "val2" {
		t.Errorf("Invalid attributes: %v", sku.Attrs)
	}

	if sku.Inventory.Type != "bucket" {
		t.Errorf("Invalid inventory type: %v", sku.Inventory.Type)
	}

	if sku.Inventory.Value != "limited" {
		t.Errorf("Invalid inventory type: %v", sku.Inventory.Value)
	}

	if sku.Image != "http://example.com/foo.png" {
		t.Errorf("invalid image: %v", sku.Image)
	}

	if sku.PackageDimensions != nil {
		t.Errorf("package dimensions expected nil: %v", sku.PackageDimensions)
	}
}

func TestSKUDelete(t *testing.T) {
	active := true

	p, err := product.New(&stripe.ProductParams{
		Active:    &active,
		Name:      "To be deleted",
		Attrs:     []string{},
		Shippable: &active,
	})
	if err != nil {
		t.Fatalf("%+v", err)
	}

	randID := fmt.Sprintf("TEST-SKU-%v", RandSeq(16))
	sku, err := New(&stripe.SKUParams{
		ID:        randID,
		Active:    &active,
		Price:     499,
		Currency:  "usd",
		Inventory: stripe.Inventory{Type: "infinite"},
		Product:   p.ID,
	})

	err = Delete(sku.ID)
	if err != nil {
		t.Fatalf("%+v", err)
	}

	_, err = Get(sku.ID, nil)
	if err == nil {
		t.Errorf("SKU should be deleted after call to `Delete`")
	}
}
