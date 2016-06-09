package stripe

// PlanInterval is the list of allowed values for a plan's interval.
// Allowed values are "day", "week", "month", "year".
type PlanInterval string

// PlanParams is the set of parameters that can be used when creating or updating a plan.
// For more details see https://stripe.com/docs/api#create_plan and https://stripe.com/docs/api#update_plan.
type PlanParams struct {
	Params
	ID, Name                   string
	Currency                   Currency
	Amount                     uint64
	Interval                   PlanInterval
	IntervalCount, TrialPeriod uint64
	Statement                  string
}

// PlanListParams is the set of parameters that can be used when listing plans.
// For more details see https://stripe.com/docs/api#list_plans.
type PlanListParams struct {
	ListParams
}

// Plan is the resource representing a Stripe plan.
// For more details see https://stripe.com/docs/api#plans.
type Plan struct {
	ID            string            `json:"id"`
	Live          bool              `json:"livemode"`
	Amount        uint64            `json:"amount"`
	Created       int64             `json:"created"`
	Currency      Currency          `json:"currency"`
	Interval      PlanInterval      `json:"interval"`
	IntervalCount uint64            `json:"interval_count"`
	Name          string            `json:"name"`
	Meta          map[string]string `json:"metadata"`
	TrialPeriod   uint64            `json:"trial_period_days"`
	Statement     string            `json:"statement_descriptor"`
	Deleted       bool              `json:"deleted"`
}

// PlanList is a list of plans as returned from a list endpoint.
type PlanList struct {
	ListMeta
	Values []*Plan `json:"data"`
}
