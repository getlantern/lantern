package product

import (
	"fmt"
	"strconv"

	stripe "github.com/stripe/stripe-go"
)

// Client is used to invoke /products APIs.
type Client struct {
	B   stripe.Backend
	Key string
}

// New POSTs a new product.
// For more details see https://stripe.com/docs/api#create_product.
func New(params *stripe.ProductParams) (*stripe.Product, error) {
	return getC().New(params)
}

// New POSTs a new product.
// For more details see https://stripe.com/docs/api#create_product.
func (c Client) New(params *stripe.ProductParams) (*stripe.Product, error) {
	var body *stripe.RequestValues
	var commonParams *stripe.Params

	if params != nil {
		body = &stripe.RequestValues{}

		// Required fields
		body.Add("name", params.Name)

		// Optional fields
		if len(params.Desc) > 0 {
			body.Add("description", params.Desc)
		}

		if params.ID != "" {
			body.Add("id", params.ID)
		}

		if params.Active != nil {
			body.Add("active", strconv.FormatBool(*(params.Active)))
		}

		if params.Caption != "" {
			body.Add("caption", params.Caption)
		}

		if len(params.Attrs) > 0 {
			for _, v := range params.Attrs {
				body.Add("attributes[]", v)
			}
		}

		if len(params.Images) > 0 {
			for _, v := range params.Images {
				body.Add("images[]", v)
			}
		}

		if len(params.URL) > 0 {
			body.Add("url", params.URL)
		}

		if params.Shippable != nil {
			body.Add("shippable", strconv.FormatBool(*(params.Shippable)))
		}

		if params.PackageDimensions != nil {
			body.Add("package_dimensions[height]",
				fmt.Sprintf("%.2f", params.PackageDimensions.Height))
			body.Add("package_dimensions[length]",
				fmt.Sprintf("%.2f", params.PackageDimensions.Length))
			body.Add("package_dimensions[width]",
				fmt.Sprintf("%.2f", params.PackageDimensions.Width))
			body.Add("package_dimensions[weight]",
				fmt.Sprintf("%.2f", params.PackageDimensions.Weight))
		}

		params.AppendTo(body)
	}

	p := &stripe.Product{}
	err := c.B.Call("POST", "/products", c.Key, body, commonParams, p)

	return p, err
}

// Update updates a product's properties.
// For more details see https://stripe.com/docs/api#update_product.
func Update(id string, params *stripe.ProductParams) (*stripe.Product, error) {
	return getC().Update(id, params)
}

// Update updates a product's properties.
// For more details see https://stripe.com/docs/api#update_product.
func (c Client) Update(id string, params *stripe.ProductParams) (*stripe.Product, error) {
	var body *stripe.RequestValues
	var commonParams *stripe.Params

	if params != nil {
		body = &stripe.RequestValues{}

		if len(params.Name) > 0 {
			body.Add("name", params.Name)
		}

		if len(params.Desc) > 0 {
			body.Add("description", params.Desc)
		}

		if params.Active != nil {
			body.Add("active", strconv.FormatBool(*(params.Active)))
		}

		if len(params.Images) > 0 {
			for _, v := range params.Images {
				body.Add("images[]", v)
			}
		}

		if len(params.URL) > 0 {
			body.Add("url", params.URL)
		}

		params.AppendTo(body)
	}

	p := &stripe.Product{}
	err := c.B.Call("POST", "/products/"+id, c.Key, body, commonParams, p)

	return p, err
}

// Get returns the details of an product
// For more details see https://stripe.com/docs/api#retrieve_product.
func Get(id string) (*stripe.Product, error) {
	return getC().Get(id)
}

func (c Client) Get(id string) (*stripe.Product, error) {
	product := &stripe.Product{}
	err := c.B.Call("GET", "/products/"+id, c.Key, nil, nil, product)

	return product, err
}

// List returns a list of products.
// For more details see https://stripe.com/docs/api#list_products
func List(params *stripe.ProductListParams) *Iter {
	return getC().List(params)
}

func (c Client) List(params *stripe.ProductListParams) *Iter {
	var body *stripe.RequestValues
	var lp *stripe.ListParams
	var p *stripe.Params

	if params != nil {
		body = &stripe.RequestValues{}

		if params.Active != nil {
			params.Filters.AddFilter("active", "", strconv.FormatBool(*params.Active))
		}

		if len(params.IDs) > 0 {
			for _, id := range params.IDs {
				params.Filters.AddFilter("ids[]", "", id)
			}
		}

		if params.Shippable != nil {
			params.Filters.AddFilter("shippable", "", strconv.FormatBool(*params.Shippable))
		}

		if params.URL != "" {
			params.Filters.AddFilter("url", "", params.URL)
		}

		params.AppendTo(body)
		lp = &params.ListParams
		p = params.ToParams()
	}

	return &Iter{stripe.GetIter(lp, body, func(b *stripe.RequestValues) ([]interface{}, stripe.ListMeta, error) {
		list := &stripe.ProductList{}
		err := c.B.Call("GET", "/products", c.Key, b, p, list)

		ret := make([]interface{}, len(list.Values))
		for i, v := range list.Values {
			ret[i] = v
		}

		return ret, list.ListMeta, err
	})}
}

// Iter is an iterator for lists of Products.
// The embedded Iter carries methods with it;
// see its documentation for details.
type Iter struct {
	*stripe.Iter
}

// Product returns the most recent Product
// visited by a call to Next.
func (i *Iter) Product() *stripe.Product {
	return i.Current().(*stripe.Product)
}

// Delete deletes a product
// For more details see https://stripe.com/docs/api#delete_product.
func Delete(id string) error {
	return getC().Delete(id)
}

// Delete deletes a product.
// For more details see https://stripe.com/docs/api#delete_product.
func (c Client) Delete(id string) error {
	return c.B.Call("DELETE", "/products/"+id, c.Key, nil, nil, nil)
}

func getC() Client {
	return Client{stripe.GetBackend(stripe.APIBackend), stripe.Key}
}
