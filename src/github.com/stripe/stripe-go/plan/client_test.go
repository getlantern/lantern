package plan

import (
	"fmt"
	"testing"

	stripe "github.com/stripe/stripe-go"
	"github.com/stripe/stripe-go/currency"
	. "github.com/stripe/stripe-go/utils"
)

func init() {
	stripe.Key = GetTestKey()
}

func TestPlanNew(t *testing.T) {
	planParams := &stripe.PlanParams{
		ID:            "test_plan",
		Name:          "Test Plan",
		Amount:        99,
		Currency:      currency.USD,
		Interval:      Month,
		IntervalCount: 3,
		TrialPeriod:   30,
		Statement:     "Test Plan",
	}

	target, err := New(planParams)

	if err != nil {
		t.Error(err)
	}

	if target.ID != planParams.ID {
		t.Errorf("ID %q does not match expected id %q\n", target.ID, planParams.ID)
	}

	if target.Name != planParams.Name {
		t.Errorf("Name %q does not match expected name %q\n", target.Name, planParams.Name)
	}

	if target.Amount != planParams.Amount {
		t.Errorf("Amount %v does not match expected amount %v\n", target.Amount, planParams.Amount)
	}

	if target.Currency != planParams.Currency {
		t.Errorf("Currency %q does not match expected currency %q\n", target.Currency, planParams.Currency)
	}

	if target.Interval != planParams.Interval {
		t.Errorf("Interval %q does not match expected interval %q\n", target.Interval, planParams.Interval)
	}

	if target.IntervalCount != planParams.IntervalCount {
		t.Errorf("Interval count %v does not match expected interval count %v\n", target.IntervalCount, planParams.IntervalCount)
	}

	if target.TrialPeriod != planParams.TrialPeriod {
		t.Errorf("Trial period %v does not match expected trial period %v\n", target.TrialPeriod, planParams.TrialPeriod)
	}

	if target.Statement != planParams.Statement {
		t.Errorf("Statement %q does not match expected statement %q\n", target.Statement, planParams.Statement)
	}

	Del(planParams.ID)
}

func TestPlanGet(t *testing.T) {
	planParams := &stripe.PlanParams{
		ID:       "test_plan",
		Name:     "Test Plan",
		Amount:   99,
		Currency: currency.USD,
		Interval: Month,
	}

	New(planParams)
	target, err := Get(planParams.ID, nil)

	if err != nil {
		t.Error(err)
	}

	if target.ID != planParams.ID {
		t.Errorf("Plan id %q does not match expected id %q\n", target.ID, planParams.ID)
	}

	Del(planParams.ID)
}

func TestPlanUpdate(t *testing.T) {
	planParams := &stripe.PlanParams{
		ID:            "test_plan",
		Name:          "Original Name",
		Amount:        99,
		Currency:      currency.USD,
		Interval:      Month,
		IntervalCount: 3,
		TrialPeriod:   30,
		Statement:     "Original Plan",
	}

	New(planParams)

	updatedPlan := &stripe.PlanParams{
		Name:      "Updated Name",
		Statement: "Updated Plan",
	}

	target, err := Update(planParams.ID, updatedPlan)

	if err != nil {
		t.Error(err)
	}

	if target.Name != updatedPlan.Name {
		t.Errorf("Name %q does not match expected name %q\n", target.Name, updatedPlan.Name)
	}

	if target.Statement != updatedPlan.Statement {
		t.Errorf("Statement %q does not match expected statement %q\n", target.Statement, updatedPlan.Statement)
	}

	Del(planParams.ID)
}

func TestPlanDel(t *testing.T) {
	planParams := &stripe.PlanParams{
		ID:       "test_plan",
		Name:     "Test Plan",
		Amount:   99,
		Currency: currency.USD,
		Interval: Month,
	}

	New(planParams)

	planDel, err := Del(planParams.ID)
	if err != nil {
		t.Error(err)
	}

	if !planDel.Deleted {
		t.Errorf("Plan id %q expected to be marked as deleted on the returned resource\n", planDel.ID)
	}
}

func TestPlanList(t *testing.T) {
	const runs = 3
	for i := 0; i < runs; i++ {
		planParams := &stripe.PlanParams{
			ID:       fmt.Sprintf("test_%v", i),
			Name:     fmt.Sprintf("test_%v", i),
			Amount:   99,
			Currency: currency.USD,
			Interval: Month,
		}

		New(planParams)
	}

	params := &stripe.PlanListParams{}
	params.Filters.AddFilter("limit", "", "1")

	plansChecked := 0
	i := List(params)
	for i.Next() && plansChecked < runs {
		target := i.Plan()

		if i.Meta() == nil {
			t.Error("No metadata returned")
		}

		if target.Amount != 99 {
			t.Errorf("Amount %v does not match expected value\n", target.Amount)
		}

		plansChecked += 1
	}
	if err := i.Err(); err != nil {
		t.Error(err)
	}

	for i := 0; i < runs; i++ {
		Del(fmt.Sprintf("test_%v", i))
	}
}
