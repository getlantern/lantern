package stripe

// Country is the list of supported countries
type Country string

// VerificationFieldsList lists the fields needed for an account verification.
// For more details see https://stripe.com/docs/api#country_spec_object-verification_fields.
type VerificationFieldsList struct {
	AdditionalFields []string `json:"additional"`
	MinimumFields    []string `json:"minimum"`
}

// CountrySpec is the resource representing the rules required for a Stripe account.
// For more details see https://stripe.com/docs/api/#country_specs.
type CountrySpec struct {
	ID                             string                                     `json:"id"`
	DefaultCurrency                Currency                                   `json:"default_currency"`
	SupportedBankAccountCurrencies map[Country][]Currency                     `json:"supported_bank_account_currencies"`
	SupportedPaymentCurrencies     []Currency                                 `json:"supported_payment_currencies"`
	SupportedPaymentMethods        []string                                   `json:"supported_payment_methods"`
	VerificationFields             map[LegalEntityType]VerificationFieldsList `json:"verification_fields"`
}

// CountrySpecList is a list of country specs as retrieved from a list endpoint.
type CountrySpecList struct {
	ListMeta
	Values []*CountrySpec `json:"data"`
}

// CountrySpecListParams are the parameters allowed during CountrySpec listing.
type CountrySpecListParams struct {
	ListParams
}
