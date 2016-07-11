// Package countryspec provides the /country_specs APIs
package countryspec

import (
	stripe "github.com/stripe/stripe-go"
)

// Client is used to invoke /country_specs and countryspec-related APIs.
type Client struct {
	B   stripe.Backend
	Key string
}

// Get returns a CountrySpec for a given country code
// For more details see https://stripe.com/docs/api/ruby#retrieve_country_spec
func Get(country string) (*stripe.CountrySpec, error) {
	return getC().Get(country)
}

func (c Client) Get(country string) (*stripe.CountrySpec, error) {
	countrySpec := &stripe.CountrySpec{}
	err := c.B.Call("GET", "/country_specs/"+country, c.Key, nil, nil, countrySpec)

	return countrySpec, err
}

// List lists available CountrySpecs.
func List(params *stripe.CountrySpecListParams) *Iter {
	return getC().List(params)
}

func (c Client) List(params *stripe.CountrySpecListParams) *Iter {
	var body *stripe.RequestValues
	var lp *stripe.ListParams
	var p *stripe.Params

	if params != nil {
		body = &stripe.RequestValues{}

		params.AppendTo(body)
		lp = &params.ListParams
		p = params.ToParams()
	}

	return &Iter{stripe.GetIter(lp, body, func(b *stripe.RequestValues) ([]interface{}, stripe.ListMeta, error) {
		list := &stripe.CountrySpecList{}
		err := c.B.Call("GET", "/country_specs", c.Key, b, p, list)

		ret := make([]interface{}, len(list.Values))
		for i, v := range list.Values {
			ret[i] = v
		}

		return ret, list.ListMeta, err
	})}
}

// Iter is an iterator for lists of CountrySpecs.
// The embedded Iter carries methods with it;
// see its documentation for details.
type Iter struct {
	*stripe.Iter
}

// CountrySpec returns the most recent CountrySpec
// visited by a call to Next.
func (i *Iter) CountrySpec() *stripe.CountrySpec {
	return i.Current().(*stripe.CountrySpec)
}

func getC() Client {
	return Client{stripe.GetBackend(stripe.APIBackend), stripe.Key}
}
