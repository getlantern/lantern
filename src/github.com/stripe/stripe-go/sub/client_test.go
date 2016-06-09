package sub

import (
	"testing"
	"time"

	stripe "github.com/stripe/stripe-go"
	"github.com/stripe/stripe-go/coupon"
	"github.com/stripe/stripe-go/currency"
	"github.com/stripe/stripe-go/customer"
	"github.com/stripe/stripe-go/discount"
	"github.com/stripe/stripe-go/plan"
	. "github.com/stripe/stripe-go/utils"
)

func init() {
	stripe.Key = GetTestKey()
}

func TestSubscriptionNew(t *testing.T) {
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

	planParams := &stripe.PlanParams{
		ID:       "test",
		Name:     "Test Plan",
		Amount:   99,
		Currency: currency.USD,
		Interval: plan.Month,
	}

	plan.New(planParams)

	subParams := &stripe.SubParams{
		Customer:           cust.ID,
		Plan:               "test",
		Quantity:           10,
		TaxPercent:         20.0,
		BillingCycleAnchor: time.Now().AddDate(0, 0, 12).Unix(),
	}

	target, err := New(subParams)

	if err != nil {
		t.Error(err)
	}

	if target.Plan.ID != subParams.Plan {
		t.Errorf("Plan %v does not match expected plan %v\n", target.Plan, subParams.Plan)
	}

	if target.Quantity != subParams.Quantity {
		t.Errorf("Quantity %v does not match expected quantity %v\n", target.Quantity, subParams.Quantity)
	}

	if target.TaxPercent != subParams.TaxPercent {
		t.Errorf("TaxPercent %f does not match expected TaxPercent %f\n", target.TaxPercent, subParams.TaxPercent)
	}

	if target.PeriodEnd != subParams.BillingCycleAnchor {
		t.Errorf("PeriodEnd %v does not match expected BillingCycleAnchor %v\n", target.PeriodEnd, subParams.BillingCycleAnchor)
	}

	customer.Del(cust.ID)
	plan.Del("test")
}

func TestSubscriptionZeroQuantity(t *testing.T) {
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

	planParams := &stripe.PlanParams{
		ID:       "test",
		Name:     "Test Plan",
		Amount:   99,
		Currency: currency.USD,
		Interval: plan.Month,
	}

	plan.New(planParams)

	subParams := &stripe.SubParams{
		Customer:       cust.ID,
		Plan:           "test",
		QuantityZero:   true,
		TaxPercentZero: true,
	}

	target, err := New(subParams)

	if err != nil {
		t.Error(err)
	}

	if target.Plan.ID != subParams.Plan {
		t.Errorf("Plan %v does not match expected plan %v\n", target.Plan, subParams.Plan)
	}

	if target.Quantity != 0 {
		t.Errorf("Quantity %v does not match expected quantity %v\n", target.Quantity, 0)
	}

	if target.TaxPercent != 0 {
		t.Errorf("Tax percent %v does not match expected tax percent %v\n", target.TaxPercent, 0)
	}

	customer.Del(cust.ID)
	plan.Del("test")
}

func TestSubscriptionGet(t *testing.T) {
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

	planParams := &stripe.PlanParams{
		ID:       "test",
		Name:     "Test Plan",
		Amount:   99,
		Currency: currency.USD,
		Interval: plan.Month,
	}

	plan.New(planParams)

	subParams := &stripe.SubParams{
		Customer: cust.ID,
		Plan:     "test",
		Quantity: 10,
	}

	subscription, _ := New(subParams)
	target, err := Get(subscription.ID, nil)

	if err != nil {
		t.Error(err)
	}

	if target.ID != subscription.ID {
		t.Errorf("Subscription id %q does not match expected id %q\n", target.ID, subscription.ID)
	}

	target, err = Get(subscription.ID, &stripe.SubParams{Customer: cust.ID})

	if err != nil {
		t.Error(err)
	}

	if target.ID != subscription.ID {
		t.Errorf("Subscription id %q does not match expected id %q\n", target.ID, subscription.ID)
	}

	customer.Del(cust.ID)
	plan.Del("test")
}

func TestSubscriptionCancel(t *testing.T) {
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

	planParams := &stripe.PlanParams{
		ID:       "test",
		Name:     "Test Plan",
		Amount:   99,
		Currency: currency.USD,
		Interval: plan.Month,
	}

	plan.New(planParams)

	subParams := &stripe.SubParams{
		Customer: cust.ID,
		Plan:     "test",
		Quantity: 10,
	}

	subscription, _ := New(subParams)
	s, err := Cancel(subscription.ID, nil)

	if err != nil {
		t.Error(err)
	}

	if s.Canceled == 0 {
		t.Errorf("Subscription.Canceled %v expected to be non 0\n", s.Canceled)
	}

	subscription, _ = New(subParams)
	s, err = Cancel(subscription.ID, &stripe.SubParams{Customer: cust.ID})

	if err != nil {
		t.Error(err)
	}

	if s.Canceled == 0 {
		t.Errorf("Subscription.Canceled %v expected to be non 0\n", s.Canceled)
	}

	customer.Del(cust.ID)
	plan.Del("test")
}

func TestSubscriptionUpdate(t *testing.T) {
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

	planParams := &stripe.PlanParams{
		ID:       "test",
		Name:     "Test Plan",
		Amount:   99,
		Currency: currency.USD,
		Interval: plan.Month,
	}

	plan.New(planParams)

	subParams := &stripe.SubParams{
		Customer:    cust.ID,
		Plan:        "test",
		Quantity:    10,
		TrialEndNow: true,
	}

	subscription, _ := New(subParams)
	updatedSub := &stripe.SubParams{
		NoProrate:  true,
		Quantity:   13,
		TaxPercent: 20.0,
	}

	target, err := Update(subscription.ID, updatedSub)

	if err != nil {
		t.Error(err)
	}

	if target.Quantity != updatedSub.Quantity {
		t.Errorf("Quantity %v does not match expected quantity %v\n", target.Quantity, updatedSub.Quantity)
	}

	if target.TaxPercent != updatedSub.TaxPercent {
		t.Errorf("TaxPercent %f does not match expected tax_percent %f\n", target.TaxPercent, updatedSub.TaxPercent)
	}

	customer.Del(cust.ID)
	plan.Del("test")
}

func TestSubscriptionDiscount(t *testing.T) {
	couponParams := &stripe.CouponParams{
		Duration: coupon.Forever,
		ID:       "sub_coupon",
		Percent:  99,
	}

	coupon.New(couponParams)

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

	planParams := &stripe.PlanParams{
		ID:       "test",
		Name:     "Test Plan",
		Amount:   99,
		Currency: currency.USD,
		Interval: plan.Month,
	}

	plan.New(planParams)

	subParams := &stripe.SubParams{
		Customer: cust.ID,
		Plan:     "test",
		Quantity: 10,
		Coupon:   "sub_coupon",
	}

	target, err := New(subParams)

	if err != nil {
		t.Error(err)
	}

	if target.Discount == nil {
		t.Errorf("Discount not found, but one was expected\n")
	}

	if target.Discount.Coupon == nil {
		t.Errorf("Coupon not found, but one was expected\n")
	}

	if target.Discount.Coupon.ID != subParams.Coupon {
		t.Errorf("Coupon id %q does not match expected id %q\n", target.Discount.Coupon.ID, subParams.Coupon)
	}

	_, err = discount.DelSub(target.ID)

	if err != nil {
		t.Error(err)
	}

	target, err = Get(target.ID, nil)

	if err != nil {
		t.Error(err)
	}

	if target.Discount != nil {
		t.Errorf("A discount %v was found, but was expected to have been deleted\n", target.Discount)
	}

	customer.Del(cust.ID)
	plan.Del("test")
	coupon.Del("sub_coupon")
}

func TestSubscriptionList(t *testing.T) {
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

	planParams := &stripe.PlanParams{
		ID:       "test",
		Name:     "Test Plan",
		Amount:   99,
		Currency: currency.USD,
		Interval: plan.Month,
	}

	plan.New(planParams)

	subParams := &stripe.SubParams{
		Customer: cust.ID,
		Plan:     "test",
		Quantity: 10,
	}

	for i := 0; i < 5; i++ {
		New(subParams)
	}

	params := &stripe.SubListParams{Customer: cust.ID, Plan: "test"}
	params.Filters.AddFilter("limit", "", "3")
	i := List(params)

	for i.Next() {
		if i.Sub() == nil {
			t.Error("No nil values expected")
		}

		if i.Meta() == nil {
			t.Error("No metadata returned")
		}

		if i.Sub().Customer.ID != cust.ID {
			t.Errorf("Expected customer %v not %v", cust.ID, i.Sub().Customer.ID)
		}

		if i.Sub().Plan.ID != "test" {
			t.Errorf("Expected plan test not %v", i.Sub().Plan.ID)
		}
	}

	if err := i.Err(); err != nil {
		t.Error(err)
	}

	i = List(nil)
	for i.Next() {
		if i.Sub() == nil {
			t.Error("No nil values expected")
		}

		if i.Meta() == nil {
			t.Error("No metadata returned")
		}
	}
	if err := i.Err(); err != nil {
		t.Error(err)
	}

	customer.Del(cust.ID)
	plan.Del("test")
}
