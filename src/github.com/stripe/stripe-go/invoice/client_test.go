package invoice

import (
	"testing"
	"time"

	stripe "github.com/stripe/stripe-go"
	"github.com/stripe/stripe-go/currency"
	"github.com/stripe/stripe-go/customer"
	"github.com/stripe/stripe-go/invoiceitem"
	"github.com/stripe/stripe-go/plan"
	"github.com/stripe/stripe-go/sub"
	. "github.com/stripe/stripe-go/utils"
)

func init() {
	stripe.Key = GetTestKey()
}

// Invoices are somewhat painful to test since you need
// to first have some items, so test everything together to
// avoid unnecessary duplication
func TestAllInvoicesScenarios(t *testing.T) {
	customerParams := &stripe.CustomerParams{
		Source: &stripe.SourceParams{
			Card: &stripe.CardParams{
				Number: "378282246310005",
				Month:  "06",
				Year:   "20",
			},
		},
	}

	cust, _ := customer.New(customerParams)

	item := &stripe.InvoiceItemParams{
		Customer: cust.ID,
		Amount:   100,
		Currency: currency.USD,
		Desc:     "Test Item",
	}

	targetItem, err := invoiceitem.New(item)

	if err != nil {
		t.Error(err)
	}

	if targetItem.Customer.ID != item.Customer {
		t.Errorf("Item customer %q does not match expected customer %q\n", targetItem.Customer.ID, item.Customer)
	}

	if targetItem.Desc != item.Desc {
		t.Errorf("Item description %q does not match expected description %q\n", targetItem.Desc, item.Desc)
	}

	if targetItem.Amount != item.Amount {
		t.Errorf("Item amount %v does not match expected amount %v\n", targetItem.Amount, item.Amount)
	}

	if targetItem.Currency != item.Currency {
		t.Errorf("Item currency %q does not match expected currency %q\n", targetItem.Currency, item.Currency)
	}

	if targetItem.Date == 0 {
		t.Errorf("Item date is not set\n")
	}

	invoiceParams := &stripe.InvoiceParams{
		Customer:   cust.ID,
		Desc:       "Desc",
		Statement:  "Statement",
		TaxPercent: 20.0,
	}

	targetInvoice, err := New(invoiceParams)

	if err != nil {
		t.Error(err)
	}

	if targetInvoice.Customer.ID != invoiceParams.Customer {
		t.Errorf("Invoice customer %q does not match expected customer %q\n", targetInvoice.Customer.ID, invoiceParams.Customer)
	}

	if targetInvoice.TaxPercent != invoiceParams.TaxPercent {
		t.Errorf("Invoice tax percent %f does not match expected tax percent %f\n", targetInvoice.TaxPercent, invoiceParams.TaxPercent)
	}

	if targetInvoice.Tax != 20 {
		t.Errorf("Invoice tax  %v does not match expected tax 20\n", targetInvoice.Tax)
	}

	if targetInvoice.Amount != targetItem.Amount+targetInvoice.Tax {
		t.Errorf("Invoice amount %v does not match expected amount %v + tax %v\n", targetInvoice.Amount, targetItem.Amount, targetInvoice.Tax)
	}

	if targetInvoice.Currency != targetItem.Currency {
		t.Errorf("Invoice currency %q does not match expected currency %q\n", targetInvoice.Currency, targetItem.Currency)
	}

	if targetInvoice.Date == 0 {
		t.Errorf("Invoice date is not set\n")
	}

	if targetInvoice.Start == 0 {
		t.Errorf("Invoice start is not set\n")
	}

	if targetInvoice.End == 0 {
		t.Errorf("Invoice end is not set\n")
	}

	if targetInvoice.Total != targetInvoice.Amount || targetInvoice.Subtotal != targetInvoice.Amount-targetInvoice.Tax {
		t.Errorf("Invoice total %v and subtotal %v do not match expected amount %v\n", targetInvoice.Total, targetInvoice.Subtotal, targetInvoice.Amount)
	}

	if targetInvoice.Desc != invoiceParams.Desc {
		t.Errorf("Invoice description %q does not match expected description %q\n", targetInvoice.Desc, invoiceParams.Desc)
	}

	if targetInvoice.Statement != invoiceParams.Statement {
		t.Errorf("Invoice statement %q does not match expected statement %q\n", targetInvoice.Statement, invoiceParams.Statement)
	}

	if targetInvoice.Lines == nil {
		t.Errorf("Invoice lines not found\n")
	}

	if targetInvoice.Lines.Count != 1 {
		t.Errorf("Invoice lines count %v does not match expected value\n", targetInvoice.Lines.Count)
	}

	if targetInvoice.Lines.Values == nil {
		t.Errorf("Invoice lines values not found\n")
	}

	if targetInvoice.Lines.Values[0].Amount != targetItem.Amount {
		t.Errorf("Invoice line amount %v does not match expected amount %v\n", targetInvoice.Lines.Values[0].Amount, targetItem.Amount)
	}

	if targetInvoice.Lines.Values[0].Currency != targetItem.Currency {
		t.Errorf("Invoice line currency %q does not match expected currency %q\n", targetInvoice.Lines.Values[0].Currency, targetItem.Currency)
	}

	if targetInvoice.Lines.Values[0].Desc != targetItem.Desc {
		t.Errorf("Invoice line description %q does not match expected description %q\n", targetInvoice.Lines.Values[0].Desc, targetItem.Desc)
	}

	if targetInvoice.Lines.Values[0].Type != TypeInvoiceItem {
		t.Errorf("Invoice line type %q does not match expected type\n", targetInvoice.Lines.Values[0].Type)
	}

	if targetInvoice.Lines.Values[0].Period == nil {
		t.Errorf("Invoice line period not found\n")
	}

	if targetInvoice.Lines.Values[0].Period.Start == 0 {
		t.Errorf("Invoice line period start is not set\n")
	}

	if targetInvoice.Lines.Values[0].Period.End == 0 {
		t.Errorf("Invoice line period end is not set\n")
	}

	updatedItem := &stripe.InvoiceItemParams{
		Amount:       99,
		Desc:         "Updated Desc",
		Discountable: true,
	}

	targetItemUpdated, err := invoiceitem.Update(targetItem.ID, updatedItem)

	if err != nil {
		t.Error(err)
	}

	if targetItemUpdated.Desc != updatedItem.Desc {
		t.Errorf("Updated item description %q does not match expected description %q\n", targetItemUpdated.Desc, updatedItem.Desc)
	}

	if targetItemUpdated.Amount != updatedItem.Amount {
		t.Errorf("Updated item amount %v does not match expected amount %v\n", targetItemUpdated.Amount, updatedItem.Amount)
	}

	if !targetItemUpdated.Discountable {
		t.Errorf("Updated item is not discountable")
	}

	updatedInvoice := &stripe.InvoiceParams{
		Desc:      "Updated Desc",
		Statement: "Updated",
	}

	targetInvoiceUpdated, err := Update(targetInvoice.ID, updatedInvoice)

	if err != nil {
		t.Error(err)
	}

	if targetInvoiceUpdated.Desc != updatedInvoice.Desc {
		t.Errorf("Updated invoice description %q does not match expected description %q\n", targetInvoiceUpdated.Desc, updatedInvoice.Desc)
	}

	if targetInvoiceUpdated.Statement != updatedInvoice.Statement {
		t.Errorf("Updated invoice statement %q does not match expected statement %q\n", targetInvoiceUpdated.Statement, updatedInvoice.Statement)
	}

	_, err = invoiceitem.Get(targetItem.ID, nil)
	if err != nil {
		t.Error(err)
	}

	ii := invoiceitem.List(&stripe.InvoiceItemListParams{Customer: cust.ID})
	for ii.Next() {
		if ii.InvoiceItem() == nil {
			t.Error("No nil values expected")
		}

		if ii.Meta() == nil {
			t.Error("No metadata returned")
		}
	}
	if err := ii.Err(); err != nil {
		t.Error(err)
	}

	i := List(&stripe.InvoiceListParams{Customer: cust.ID})
	for i.Next() {
		if i.Invoice() == nil {
			t.Error("No nil values expected")
		}

		if i.Meta() == nil {
			t.Error("No metadata returned")
		}
	}
	if err := i.Err(); err != nil {
		t.Error(err)
	}

	il := ListLines(&stripe.InvoiceLineListParams{ID: targetInvoice.ID, Customer: cust.ID})
	for il.Next() {
		if il.InvoiceLine() == nil {
			t.Error("No nil values expected")
		}

		if il.Meta() == nil {
			t.Error("No metadata returned")
		}
	}
	if err := il.Err(); err != nil {
		t.Error(err)
	}

	iiDel, err := invoiceitem.Del(targetItem.ID)

	if err != nil {
		t.Error(err)
	}

	if !iiDel.Deleted {
		t.Errorf("Invoice Item id %q expected to be marked as deleted on the returned resource\n", iiDel.ID)
	}

	_, err = Get(targetInvoice.ID, nil)

	if err != nil {
		t.Error(err)
	}

	planParams := &stripe.PlanParams{
		ID:       "test",
		Name:     "Test Plan",
		Amount:   99,
		Currency: currency.USD,
		Interval: plan.Month,
	}

	_, err = plan.New(planParams)
	if err != nil {
		t.Error(err)
	}

	subParams := &stripe.SubParams{
		Customer:    cust.ID,
		Plan:        planParams.ID,
		Quantity:    10,
		TrialEndNow: true,
	}

	subscription, err := sub.New(subParams)
	if err != nil {
		t.Error(err)
	}

	nextParams := &stripe.InvoiceParams{
		Customer:         cust.ID,
		Sub:              subscription.ID,
		SubPlan:          planParams.ID,
		SubNoProrate:     false,
		SubProrationDate: time.Now().AddDate(0, 0, 12).Unix(),
		SubQuantity:      1,
		SubTrialEnd:      time.Now().AddDate(0, 0, 12).Unix(),
	}

	nextInvoice, err := GetNext(nextParams)
	if err != nil {
		t.Error(err)
	}

	if nextInvoice.Customer.ID != cust.ID {
		t.Errorf("Invoice customer %v does not match expected customer%v\n", nextInvoice.Customer.ID, cust.ID)
	}

	if nextInvoice.Sub != subscription.ID {
		t.Errorf("Invoice subscription %v does not match expected subscription%v\n", nextInvoice.Sub, subscription.ID)
	}

	_, err = plan.Del(planParams.ID)
	if err != nil {
		t.Error(err)
	}

	customer.Del(cust.ID)
}
