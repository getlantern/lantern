package product

import (
	"fmt"
	"math/rand"
	"testing"
	"time"

	stripe "github.com/stripe/stripe-go"
	. "github.com/stripe/stripe-go/utils"
)

func init() {
	stripe.Key = GetTestKey()
	rand.Seed(time.Now().UTC().UnixNano())
}

func TestProduct(t *testing.T) {
	active := true
	shippable := true

	p, err := New(&stripe.ProductParams{
		Active:    &active,
		Name:      "test name",
		Desc:      "This is a description",
		Caption:   "This is a caption",
		Attrs:     []string{"attr1", "attr2"},
		URL:       "http://example.com",
		Shippable: &shippable,
		PackageDimensions: &stripe.PackageDimensions{
			Height: 2.234,
			Length: 5.10,
			Width:  6.50,
			Weight: 10,
		},
	})

	if err != nil {
		t.Fatalf("%+v", err)
	}

	if p.ID == "" {
		t.Errorf("ID is not set %v", p.ID)
	}

	if p.Created == 0 {
		t.Errorf("Created date is not set")
	}

	if p.Updated == 0 {
		t.Errorf("Updated is not set")
	}

	if p.Name != "test name" {
		t.Errorf("Name is invalid: %v", p.Name)
	}

	if p.Caption != "This is a caption" {
		t.Errorf("Caption is invalid: %v", p.Caption)
	}

	if !p.Shippable {
		t.Errorf("Product should be shippable, but is not")
	}

	if p.Desc != "This is a description" {
		t.Errorf("Description is invalid: %v", p.Desc)
	}

	if p.URL != "http://example.com" {
		t.Errorf("URL is invalid: %v", p.URL)
	}

	if p.PackageDimensions == nil ||
		p.PackageDimensions.Height != 2.23 ||
		p.PackageDimensions.Length != 5.10 ||
		p.PackageDimensions.Width != 6.50 ||
		p.PackageDimensions.Weight != 10 {
		t.Errorf("PackageDimensions is invalid: %v", p.PackageDimensions)
	}
}

func TestProductWithCustomID(t *testing.T) {
	randID := fmt.Sprintf("TEST-PRODUCT-%v", RandSeq(16))
	p, err := New(&stripe.ProductParams{
		ID:   randID,
		Name: "Test product name",
		Desc: "Test description",
	})

	if err != nil {
		t.Fatalf("%+v", err)
	}

	if p.ID != randID {
		t.Errorf("Expected ID to be %v, but got back %v", randID, p.ID)
	}
}

func TestProductWithoutDescription(t *testing.T) {
	name := RandSeq(16)
	p, err := New(&stripe.ProductParams{
		Name: name,
	})

	if err != nil {
		t.Fatalf("%+v", err)
	}

	if p.Name != name {
		t.Errorf("Expected name to be %v, but got back %v", name, p.Name)
	}
}
func TestProductUpdate(t *testing.T) {
	randID := fmt.Sprintf("TEST-PRODUCT-%v", RandSeq(16))
	p, err := New(&stripe.ProductParams{
		ID:   randID,
		Name: "Test product name",
		Desc: "Test description",
	})
	if err != nil {
		t.Fatalf("%+v", err)
	}
	p, err = Update(p.ID, &stripe.ProductParams{
		Desc: "new description",
	})
	if err != nil {
		t.Fatalf("%+v", err)
	}
	if p.Desc != "new description" {
		t.Errorf("Invalid description: %v", p.Desc)
	}
}

func TestProductList(t *testing.T) {
	const runs = 3
	randID := fmt.Sprintf("example.com/%s", RandSeq(16))
	for i := 0; i < runs; i++ {
		shippable := i == 0
		active := i == 1
		prodParams := &stripe.ProductParams{
			Name:      fmt.Sprintf("test_%v", i),
			Shippable: &shippable,
			Active:    &active,
			URL:       randID,
		}

		New(prodParams)
	}

	params := &stripe.ProductListParams{}
	params.Shippable = new(bool)
	*params.Shippable = true
	params.URL = randID

	i := List(params)
	for i.Next() {
		target := i.Product()

		if i.Meta() == nil {
			t.Error("No metadata returned")
		}

		if target.Name != "test_0" {
			t.Errorf("Filtered product %v is not the expected\n", target.Name)
		}
	}
	if err := i.Err(); err != nil {
		t.Error(err)
	}

	params.Shippable = nil
	params.Active = new(bool)
	*params.Active = true

	i = List(params)
	for i.Next() {
		target := i.Product()

		if i.Meta() == nil {
			t.Error("No metadata returned")
		}

		if target.Name != "test_1" {
			t.Errorf("Filtered product %v is not the expected\n", target.Name)
		}
	}
	if err := i.Err(); err != nil {
		t.Error(err)
	}
}

func TestProductDelete(t *testing.T) {
	randID := fmt.Sprintf("TEST-PRODUCT-%v", RandSeq(16))
	p, err := New(&stripe.ProductParams{
		ID:   randID,
		Name: "To Be Deleted",
	})
	if err != nil {
		t.Fatalf("%+v", err)
	}
	err = Delete(p.ID)
	if err != nil {
		t.Fatalf("%+v", err)
	}

	_, err = Get(p.ID)
	if err == nil {
		t.Error("Expected product to be deleted after calling `Delete`")
	}
}
