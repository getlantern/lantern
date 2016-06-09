package stripe

import (
	"encoding/json"
)

// DisputeReason is the list of allowed values for a discount's reason.
// Allowed values are "duplicate", "fraudulent", "subscription_canceled",
// "product_unacceptable", "product_not_received", "unrecognized",
// "credit_not_processed", "general".
type DisputeReason string

// DisputeStatus is the list of allowed values for a discount's status.
// Allowed values are "won", "lost", "needs_response", "under_review",
// "warning_needs_response", "warning_under_review", "charge_refunded",
// "warning_closed".
type DisputeStatus string

// DisputeParams is the set of parameters that can be used when updating a dispute.
// For more details see https://stripe.com/docs/api#update_dispute.
type DisputeParams struct {
	Params
	Evidence *DisputeEvidenceParams
}

// DisputeEvidenceParams is the set of parameters that can be used when submitting
// evidence for disputes.
type DisputeEvidenceParams struct {
	ProductDesc, CustomerName, CustomerEmail, CustomerIP, CustomerSig, BillingAddress, Receipt string
	ShippingAddress, ShippingDate, ShippingTracking, ShippingDoc                               string
	RefundPolicy, RefundPolicyDisclosure, RefundRefusalReason                                  string
	CancellationPolicy, CancellationPolicyDisclsoure, CancellationRebuttal                     string
	ActivityLog                                                                                string
	ServiceDate, ServiceDoc                                                                    string
	DuplicateCharge, DuplicateChargeReason, DuplicateChargeDoc                                 string
	CustomerComm, UncategorizedText, UncategorizedFile                                         string
}

// DisputeListParams is the set of parameters that can be used when listing disputes.
// For more details see https://stripe.com/docs/api#list_disputes.
type DisputeListParams struct {
	ListParams
	Created int64
}

// Dispute is the resource representing a Stripe dispute.
// For more details see https://stripe.com/docs/api#disputes.
type Dispute struct {
	ID              string            `json:"id"`
	Live            bool              `json:"livemode"`
	Amount          uint64            `json:"amount"`
	Currency        Currency          `json:"currency"`
	Charge          string            `json:"charge"`
	Created         int64             `json:"created"`
	Refundable      bool              `json:"is_charge_refundable"`
	Reason          DisputeReason     `json:"reason"`
	Status          DisputeStatus     `json:"status"`
	Transactions    []*Transaction    `json:"balance_transactions"`
	Evidence        *DisputeEvidence  `json:"evidence"`
	EvidenceDetails *EvidenceDetails  `json:"evidence_details"`
	Meta            map[string]string `json:"metadata"`
}

// DisputeList is a list of disputes as retrieved from a list endpoint.
type DisputeList struct {
	ListMeta
	Values []*Dispute `json:"data"`
}

// EvidenceDetails is the structure representing more details about
// the dispute.
type EvidenceDetails struct {
	DueDate int64 `json:"due_by"`
	Count   int   `json:"submission_count"`
}

// DisputeEvidence is the structure that contains various details about
// the evidence submitted for the dispute.
// Almost all fields are strings since there structures (i.e. address)
// do not typically get parsed by anyone and are thus presented as-received.
type DisputeEvidence struct {
	ProductDesc                  string `json:"product_description"`
	CustomerName                 string `json:"customer_name"`
	CustomerEmail                string `json:"customer_email_address"`
	CustomerIP                   string `json:"customer_purchase_ip"`
	CustomerSig                  *File  `json:"customer_signature"`
	BillingAddress               string `json:"billing_address"`
	Receipt                      *File  `json:"receipt"`
	ShippingAddress              string `json:"shipping_address"`
	ShippingDate                 string `json:"shipping_date"`
	ShippingTracking             string `json:"shipping_tracking_number"`
	ShippingDoc                  *File  `json:"shipping_documentation"`
	RefundPolicy                 *File  `json:"refund_policy"`
	RefundPolicyDisclosure       string `json:"refund_policy_disclosure"`
	RefundRefusalReason          string `json:"refund_refusal_explanation"`
	CancellationPolicy           *File  `json:"cancellation_policy"`
	CancellationPolicyDisclosure string `json:"cancellation_policy_disclosure"`
	CancellationRebuttal         string `json:"cancellation_rebuttal"`
	ActivityLog                  string `json:"access_activity_log"`
	ServiceDate                  string `json:"service_date"`
	ServiceDoc                   *File  `json:"service_documentation"`
	DuplicateCharge              string `json:"duplicate_charge_id"`
	DuplicateChargeReason        string `json:"duplicate_charge_explanation"`
	DuplicateChargeDoc           *File  `json:"duplicate_charge_documentation"`
	CustomerComm                 *File  `json:"customer_communication"`
	UncategorizedText            string `json:"uncategorized_text"`
	UncategorizedFile            *File  `json:"uncategorized_file"`
}

// File represents a link to downloadable content.
type File struct {
	ID      string `json:"id"`
	Created int64  `json:"created"`
	Size    int    `json:"size"`
	Purpose string `json:"purpose"`
	URL     string `json:"url"`
	Mime    string `json:"mime_type"`
}

// AppendDetails adds the dispute evidence details to the query string values.
func (e *DisputeEvidenceParams) AppendDetails(values *RequestValues) {
	if len(e.ProductDesc) > 0 {
		values.Add("evidence[product_description]", e.ProductDesc)
	}

	if len(e.CustomerName) > 0 {
		values.Add("evidence[customer_name]", e.CustomerName)
	}

	if len(e.CustomerEmail) > 0 {
		values.Add("evidence[customer_email_address]", e.CustomerEmail)
	}

	if len(e.CustomerIP) > 0 {
		values.Add("evidence[customer_purchase_ip]", e.CustomerIP)
	}

	if len(e.CustomerSig) > 0 {
		values.Add("evidence[customer_signature]", e.CustomerSig)
	}

	if len(e.BillingAddress) > 0 {
		values.Add("evidence[billing_address]", e.BillingAddress)
	}

	if len(e.Receipt) > 0 {
		values.Add("evidence[receipt]", e.Receipt)
	}

	if len(e.ShippingAddress) > 0 {
		values.Add("evidence[shipping_address]", e.ShippingAddress)
	}

	if len(e.ShippingDate) > 0 {
		values.Add("evidence[shipping_date]", e.ShippingDate)
	}

	if len(e.ShippingTracking) > 0 {
		values.Add("evidence[shipping_tracking_number]", e.ShippingTracking)
	}

	if len(e.ShippingDoc) > 0 {
		values.Add("evidence[shipping_documentation]", e.ShippingDoc)
	}

	if len(e.RefundPolicy) > 0 {
		values.Add("evidence[refund_policy]", e.RefundPolicy)
	}

	if len(e.RefundPolicyDisclosure) > 0 {
		values.Add("evidence[refund_policy_disclosure]", e.RefundPolicyDisclosure)
	}

	if len(e.RefundRefusalReason) > 0 {
		values.Add("evidence[refund_refusal_explanation]", e.RefundRefusalReason)
	}

	if len(e.CancellationPolicy) > 0 {
		values.Add("evidence[cancellation_policy]", e.CancellationPolicy)
	}

	if len(e.CancellationPolicyDisclsoure) > 0 {
		values.Add("evidence[cancellation_policy_disclosure]", e.CancellationPolicyDisclsoure)
	}

	if len(e.CancellationRebuttal) > 0 {
		values.Add("evidence[cancellation_rebuttal]", e.CancellationRebuttal)
	}

	if len(e.ActivityLog) > 0 {
		values.Add("evidence[access_activity_log]", e.ActivityLog)
	}

	if len(e.ServiceDate) > 0 {
		values.Add("evidence[service_date]", e.ServiceDate)
	}

	if len(e.ServiceDoc) > 0 {
		values.Add("evidence[service_documentation]", e.ServiceDoc)
	}

	if len(e.DuplicateCharge) > 0 {
		values.Add("evidence[duplicate_charge_id]", e.DuplicateCharge)
	}

	if len(e.DuplicateChargeReason) > 0 {
		values.Add("evidence[duplicate_charge_explanation]", e.DuplicateChargeReason)
	}

	if len(e.DuplicateChargeDoc) > 0 {
		values.Add("evidence[duplicate_charge_documentation]", e.DuplicateChargeDoc)
	}

	if len(e.CustomerComm) > 0 {
		values.Add("evidence[customer_communication]", e.CustomerComm)
	}

	if len(e.UncategorizedText) > 0 {
		values.Add("evidence[uncategorized_text]", e.UncategorizedText)
	}

	if len(e.UncategorizedFile) > 0 {
		values.Add("evidence[uncategorized_file]", e.UncategorizedFile)
	}
}

// UnmarshalJSON handles deserialization of a File.
// This custom unmarshaling is needed because the resulting
// property may be an id or the full struct if it was expanded.
func (f *File) UnmarshalJSON(data []byte) error {
	type file File
	var ff file
	err := json.Unmarshal(data, &ff)
	if err == nil {
		*f = File(ff)
	} else {
		// the id is surrounded by "\" characters, so strip them
		f.ID = string(data[1 : len(data)-1])
	}

	return nil
}
