package coupon

import (
	"fmt"
	"testing"
	"time"

	stripe "github.com/stripe/stripe-go"
	"github.com/stripe/stripe-go/currency"
	. "github.com/stripe/stripe-go/utils"
)

func init() {
	stripe.Key = GetTestKey()
}

func TestCouponNew(t *testing.T) {
	couponParams := &stripe.CouponParams{
		Amount:         99,
		Currency:       currency.USD,
		Duration:       Repeating,
		DurationPeriod: 3,
		Redemptions:    1,
		RedeemBy:       time.Now().AddDate(0, 0, 30).Unix(),
	}

	target, err := New(couponParams)

	if err != nil {
		t.Error(err)
	}

	if target.Amount != couponParams.Amount {
		t.Errorf("Amount %v does not match expected amount %v\n", target.Amount, couponParams.Amount)
	}

	if target.Currency != couponParams.Currency {
		t.Errorf("Currency %q does not match expected currency %q\n", target.Currency, couponParams.Currency)
	}

	if target.Duration != couponParams.Duration {
		t.Errorf("Duration %q does not match expected duration %q\n", target.Duration, couponParams.Duration)
	}

	if target.DurationPeriod != couponParams.DurationPeriod {
		t.Errorf("Duration period %v does not match expected duration period %v\n", target.DurationPeriod, couponParams.DurationPeriod)
	}

	if target.Redemptions != couponParams.Redemptions {
		t.Errorf("Max redemptions %v does not match expected max redemptions %v\n", target.Redemptions, couponParams.Redemptions)
	}

	if target.RedeemBy != couponParams.RedeemBy {
		t.Errorf("Redeem by %v does not match expected redeem by %v\n", target.RedeemBy, couponParams.RedeemBy)
	}

	if !target.Valid {
		t.Errorf("Coupon is not valid, but was expecting it to be\n")
	}

	Del(target.ID)
}

func TestCouponGet(t *testing.T) {
	couponParams := &stripe.CouponParams{
		ID:       "test_coupon",
		Duration: Once,
		Percent:  50,
	}

	New(couponParams)
	target, err := Get(couponParams.ID, nil)

	if err != nil {
		t.Error(err)
	}

	if target.ID != couponParams.ID {
		t.Errorf("ID %q does not match expected id %q\n", target.ID, couponParams.ID)
	}

	if target.Percent != couponParams.Percent {
		t.Errorf("Percent %v does not match expected percent %v\n", target.Percent, couponParams.Percent)
	}

	Del(target.ID)
}

func TestCouponUpdate(t *testing.T) {
	couponParams := &stripe.CouponParams{
		ID:       "test_coupon",
		Duration: Once,
		Percent:  50,
	}

	New(couponParams)

	updateParams := &stripe.CouponParams{}
	updateParams.AddMeta("key", "value")
	target, err := Update(couponParams.ID, updateParams)

	if err != nil {
		t.Error(err)
	}

	if target.ID != couponParams.ID {
		t.Errorf("ID %q does not match expected id %q\n", target.ID, couponParams.ID)
	}

	if target.Meta["key"] != updateParams.Meta["key"] {
		t.Errorf("Meta %v does not match expected Meta %v\n", target.Meta, updateParams.Meta)
	}

	Del(target.ID)
}

func TestCouponList(t *testing.T) {
	for i := 0; i < 5; i++ {
		couponParams := &stripe.CouponParams{
			ID:       fmt.Sprintf("test_%v", i),
			Duration: Once,
			Percent:  50,
		}

		New(couponParams)
	}

	i := List(nil)
	for i.Next() {
		if i.Coupon() == nil {
			t.Error("No nil values expected")
		}

		if i.Meta() == nil {
			t.Error("No metadata returned")
		}
	}
	if err := i.Err(); err != nil {
		t.Error(err)
	}

	for i := 0; i < 5; i++ {
		Del(fmt.Sprintf("test_%v", i))
	}
}

func TestCouponDel(t *testing.T) {
	couponParams := &stripe.CouponParams{
		Duration: Once,
		Percent:  50,
	}

	target, err := New(couponParams)
	if err != nil {
		t.Error(err)
	}

	coupon, err := Del(target.ID)
	if !coupon.Deleted {
		t.Errorf("Coupon id %v expected to be marked as deleted on the returned resource\n", coupon.ID)
	}
}
