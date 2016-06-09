package sku

import (
	"fmt"
	"strconv"

	stripe "github.com/stripe/stripe-go"
)

// Client is used to invoke /skus APIs.
type Client struct {
	B   stripe.Backend
	Key string
}

// New POSTs a new SKU.
// For more details see https://stripe.com/docs/api#create_sku.
func New(params *stripe.SKUParams) (*stripe.SKU, error) {
	return getC().New(params)
}

// New POSTs a new SKU.
// For more details see https://stripe.com/docs/api#create_sku.
func (c Client) New(params *stripe.SKUParams) (*stripe.SKU, error) {
	var body *stripe.RequestValues
	var commonParams *stripe.Params

	if params != nil {
		body = &stripe.RequestValues{}

		// Required fields
		body.Add("price", strconv.FormatInt(params.Price, 10))
		body.Add("currency", params.Currency)
		body.Add("product", params.Product)

		// Optional fields
		if params.ID != "" {
			body.Add("id", params.ID)
		}

		if params.Active != nil {
			body.Add("active", strconv.FormatBool(*(params.Active)))
		}

		if len(params.Image) > 0 {
			body.Add("image", params.Image)
		}

		if len(params.Desc) > 0 {
			body.Add("description", params.Desc)
		}

		if len(params.Attrs) > 0 {
			for k, v := range params.Attrs {
				body.Add(fmt.Sprintf("attributes[%v]", k), v)
			}
		}

		inventory := params.Inventory

		if len(inventory.Type) > 0 {
			body.Add("inventory[type]", inventory.Type)
			switch inventory.Type {
			case "finite":
				body.Add("inventory[quantity]", strconv.FormatInt(inventory.Quantity, 10))
			case "bucket":
				body.Add("inventory[value]", inventory.Value)
			}
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

	p := &stripe.SKU{}
	err := c.B.Call("POST", "/skus", c.Key, body, commonParams, p)

	return p, err
}

// Update updates a SKU's properties.
// For more details see https://stripe.com/docs/api#update_sku.
func Update(id string, params *stripe.SKUParams) (*stripe.SKU, error) {
	return getC().Update(id, params)
}

// Update updates a SKU's properties.
// For more details see https://stripe.com/docs/api#update_sku.
func (c Client) Update(id string, params *stripe.SKUParams) (*stripe.SKU, error) {
	var body *stripe.RequestValues
	var commonParams *stripe.Params

	if params != nil {
		body = &stripe.RequestValues{}

		// Required fields
		if params.Price > 0 {
			body.Add("price", strconv.FormatInt(params.Price, 10))
		}

		if len(params.Currency) > 0 {
			body.Add("currency", params.Currency)
		}

		// Optional fields
		if params.Active != nil {
			body.Add("active", strconv.FormatBool(*(params.Active)))
		}

		if len(params.Desc) > 0 {
			body.Add("description", params.Desc)
		}

		if len(params.Image) > 0 {
			body.Add("image", params.Image)
		}

		inventory := params.Inventory

		if len(inventory.Type) > 0 {
			body.Add("inventory[type]", inventory.Type)
			switch inventory.Type {
			case "finite":
				body.Add("inventory[quantity]", strconv.FormatInt(inventory.Quantity, 10))
			case "bucket":
				body.Add("inventory[value]", inventory.Value)
			}
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

	p := &stripe.SKU{}
	err := c.B.Call("POST", "/skus/"+id, c.Key, body, commonParams, p)

	return p, err
}

// Get returns the details of an sku
// For more details see https://stripe.com/docs/api#retrieve_sku.
func Get(id string, params *stripe.SKUParams) (*stripe.SKU, error) {
	return getC().Get(id, params)
}

func (c Client) Get(id string, params *stripe.SKUParams) (*stripe.SKU, error) {
	sku := &stripe.SKU{}
	var body *stripe.RequestValues
	var commonParams *stripe.Params

	if params != nil {
		commonParams = &params.Params
		body = &stripe.RequestValues{}
		params.AppendTo(body)
	}
	err := c.B.Call("GET", "/skus/"+id, c.Key, body, commonParams, sku)

	return sku, err
}

// List returns a list of skus.
// For more details see https://stripe.com/docs/api#list_skus
func List(params *stripe.SKUListParams) *Iter {
	return getC().List(params)
}

func (c Client) List(params *stripe.SKUListParams) *Iter {
	var body *stripe.RequestValues
	var lp *stripe.ListParams
	var p *stripe.Params

	if params != nil {
		body = &stripe.RequestValues{}

		if params.Active != nil {
			params.Filters.AddFilter(
				"active", "", strconv.FormatBool(*params.Active),
			)
		}

		if params.Product != "" {
			params.Filters.AddFilter("product", "", params.Product)
			for attrName, value := range params.Attributes {
				params.Filters.AddFilter("attributes", attrName, value)
			}
		}

		for _, id := range params.IDs {
			params.Filters.AddFilter("ids[]", "", id)
		}

		if params.InStock != nil {
			params.Filters.AddFilter(
				"in_stock", "", strconv.FormatBool(*params.InStock),
			)
		}

		params.AppendTo(body)
		lp = &params.ListParams
		p = params.ToParams()
	}

	return &Iter{stripe.GetIter(lp, body, func(b *stripe.RequestValues) ([]interface{}, stripe.ListMeta, error) {
		list := &stripe.SKUList{}
		err := c.B.Call("GET", "/skus", c.Key, b, p, list)

		ret := make([]interface{}, len(list.Values))
		for i, v := range list.Values {
			ret[i] = v
		}

		return ret, list.ListMeta, err
	})}
}

// Iter is an iterator for lists of SKUs.
// The embedded Iter carries methods with it;
// see its documentation for details.
type Iter struct {
	*stripe.Iter
}

// SKU returns the most recent SKU
// visited by a call to Next.
func (i *Iter) SKU() *stripe.SKU {
	return i.Current().(*stripe.SKU)
}

// Delete destroys a SKU.
// For more details see https://stripe.com/docs/api#delete_sku.
func Delete(id string) error {
	return getC().Delete(id)
}

// Delete destroys a SKU.
// For more details see https://stripe.com/docs/api#delete_sku.
func (c Client) Delete(id string) error {
	return c.B.Call("DELETE", "/skus/"+id, c.Key, nil, nil, nil)
}

func getC() Client {
	return Client{stripe.GetBackend(stripe.APIBackend), stripe.Key}
}
