package stripe

import (
	"encoding/json"

	"fmt"
)

// CardBrand is the list of allowed values for the card's brand.
// Allowed values are "Unknown", "Visa", "American Express", "MasterCard", "Discover"
// "JCB", "Diners Club".
type CardBrand string

// Verification is the list of allowed verification responses.
// Allowed values are "pass", "fail", "unchecked", "unavailabe".
type Verification string

// CardFunding is the list of allowed values for the card's funding.
// Allowed values are "credit", "debit", "prepaid", "unknown".
type CardFunding string

// CardParams is the set of parameters that can be used when creating or updating a card.
// For more details see https://stripe.com/docs/api#create_card and https://stripe.com/docs/api#update_card.
type CardParams struct {
	Params
	Token                                         string
	Default                                       bool
	Account, Customer, Recipient                  string
	Name, Number, Month, Year, CVC, Currency      string
	Address1, Address2, City, State, Zip, Country string
}

// CardListParams is the set of parameters that can be used when listing cards.
// For more details see https://stripe.com/docs/api#list_cards.
type CardListParams struct {
	ListParams
	Account, Customer, Recipient string
}

// Card is the resource representing a Stripe credit/debit card.
// For more details see https://stripe.com/docs/api#cards.
type Card struct {
	ID            string            `json:"id"`
	Month         uint8             `json:"exp_month"`
	Year          uint16            `json:"exp_year"`
	Fingerprint   string            `json:"fingerprint"`
	Funding       CardFunding       `json:"funding"`
	LastFour      string            `json:"last4"`
	Brand         CardBrand         `json:"brand"`
	Currency      Currency          `json:"currency"`
	Default       bool              `json:"default_for_currency"`
	City          string            `json:"address_city"`
	Country       string            `json:"address_country"`
	Address1      string            `json:"address_line1"`
	Address1Check Verification      `json:"address_line1_check"`
	Address2      string            `json:"address_line2"`
	State         string            `json:"address_state"`
	Zip           string            `json:"address_zip"`
	ZipCheck      Verification      `json:"address_zip_check"`
	CardCountry   string            `json:"country"`
	Customer      *Customer         `json:"customer"`
	CVCCheck      Verification      `json:"cvc_check"`
	Meta          map[string]string `json:"metadata"`
	Name          string            `json:"name"`
	Recipient     *Recipient        `json:"recipient"`
	DynLastFour   string            `json:"dynamic_last4"`
	Deleted       bool              `json:"deleted"`

	// Description is a succinct summary of the card's information.
	//
	// Please note that this field is for internal use only and is not returned
	// as part of standard API requests.
	Description string `json:"description"`

	// IIN is the card's "Issuer Identification Number".
	//
	// Please note that this field is for internal use only and is not returned
	// as part of standard API requests.
	IIN string `json:"iin"`

	// Issuer is a bank or financial institution that provides the card.
	//
	// Please note that this field is for internal use only and is not returned
	// as part of standard API requests.
	Issuer string `json:"issuer"`
}

// CardList is a list object for cards.
type CardList struct {
	ListMeta
	Values []*Card `json:"data"`
}

// AppendDetails adds the card's details to the query string values.
// When creating a new card, the parameters are passed as a dictionary, but
// on updates they are simply the parameter name.
func (c *CardParams) AppendDetails(values *RequestValues, creating bool) {
	if creating {
		if len(c.Token) > 0 && len(c.Account) > 0 {
			values.Add("external_account", c.Token)
		} else if len(c.Token) > 0 {
			values.Add("card", c.Token)
		} else {
			values.Add("card[object]", "card")
			values.Add("card[number]", c.Number)

			if len(c.CVC) > 0 {
				values.Add("card[cvc]", c.CVC)
			}

			if len(c.Currency) > 0 {
				values.Add("card[currency]", c.Currency)
			}
		}
	}

	if len(c.Month) > 0 {
		if creating {
			values.Add("card[exp_month]", c.Month)
		} else {
			values.Add("exp_month", c.Month)
		}
	}

	if len(c.Year) > 0 {
		if creating {
			values.Add("card[exp_year]", c.Year)
		} else {
			values.Add("exp_year", c.Year)
		}
	}

	if len(c.Name) > 0 {
		if creating {
			values.Add("card[name]", c.Name)
		} else {
			values.Add("name", c.Name)
		}
	}

	if len(c.Address1) > 0 {
		if creating {
			values.Add("card[address_line1]", c.Address1)
		} else {
			values.Add("address_line1", c.Address1)
		}
	}

	if len(c.Address2) > 0 {
		if creating {
			values.Add("card[address_line2]", c.Address2)
		} else {
			values.Add("address_line2", c.Address2)
		}
	}

	if len(c.City) > 0 {
		if creating {
			values.Add("card[address_city]", c.City)
		} else {
			values.Add("address_city", c.City)
		}
	}

	if len(c.State) > 0 {
		if creating {
			values.Add("card[address_state]", c.State)
		} else {
			values.Add("address_state", c.State)
		}
	}

	if len(c.Zip) > 0 {
		if creating {
			values.Add("card[address_zip]", c.Zip)
		} else {
			values.Add("address_zip", c.Zip)
		}
	}

	if len(c.Country) > 0 {
		if creating {
			values.Add("card[address_country]", c.Country)
		} else {
			values.Add("address_country", c.Country)
		}
	}
}

// Display human readable representation of a Card.
func (c *Card) Display() string {
	return fmt.Sprintf("%s ending in %s", c.Brand, c.LastFour)
}

// UnmarshalJSON handles deserialization of a Card.
// This custom unmarshaling is needed because the resulting
// property may be an id or the full struct if it was expanded.
func (c *Card) UnmarshalJSON(data []byte) error {
	type card Card
	var cc card
	err := json.Unmarshal(data, &cc)
	if err == nil {
		*c = Card(cc)
	} else {
		// the id is surrounded by "\" characters, so strip them
		c.ID = string(data[1 : len(data)-1])
	}

	return nil
}
