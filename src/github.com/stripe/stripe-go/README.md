# Go Stripe [![GoDoc](http://img.shields.io/badge/godoc-reference-blue.svg)](http://godoc.org/github.com/stripe/stripe-go) [![Build Status](https://travis-ci.org/stripe/stripe-go.svg?branch=master)](https://travis-ci.org/stripe/stripe-go)

## Summary

The official [Stripe][stripe] Go client library.

## Versioning

Each revision of the binding is tagged and the version is updated accordingly.

Given Go's lack of built-in versioning, it is highly recommended you use a
[package management tool][package-management] in order to ensure a newer
version of the binding does not affect backwards compatibility.

To see the list of past versions, run `git tag`. To manually get an older
version of the client, clone this repo, checkout the specific tag and build the
library:

```sh
git clone https://github.com/stripe/stripe-go.git
cd stripe-go
git checkout api_version_tag
make build
```

For more details on changes between versions, see the [binding
changelog](CHANGELOG) and [API changelog][api-changelog].

## Installation

```sh
go get github.com/stripe/stripe-go
```

## Documentation

For a comprehensive list of examples, check out the [API
documentation][api-docs].

For details on all the functionality in this library, see the [GoDoc][godoc]
documentation.

Below are a few simple examples:

### Customers

```go
params := &stripe.CustomerParams{
	Balance: -123,
	Desc:  "Stripe Developer",
	Email: "gostripe@stripe.com",
}
params.SetSource(&stripe.CardParams{
	Name:   "Go Stripe",
	Number: "378282246310005",
	Month:  "06",
	Year:   "15",
})

customer, err := customer.New(params)
```

### Charges

```go
params := &stripe.ChargeListParams{Customer: customer.ID}
params.Filters.AddFilter("include[]", "", "total_count")

// set this so you can easily retry your request in case of a timeout
params.Params.IdempotencyKey = stripe.NewIdempotencyKey()

i := charge.List(params)
for i.Next() {
	charge := i.Charge()
}

if err := i.Err(); err != nil {
	// handle
}
```

### Events

```go
i := event.List(nil)
for i.Next() {
	e := i.Event()

	// access event data via e.GetObjValue("resource_name_based_on_type", "resource_property_name")
	// alternatively you can access values via e.Data.Obj["resource_name_based_on_type"].(map[string]interface{})["resource_property_name"]

	// access previous attributes via e.GetPrevValue("resource_name_based_on_type", "resource_property_name")
	// alternatively you can access values via e.Data.Prev["resource_name_based_on_type"].(map[string]interface{})["resource_property_name"]
}
```

Alternatively, you can use the `even.Data.Raw` property to unmarshal to the
appropriate struct.

### Authentication with Connect

There are two ways of authenticating requests when performing actions on behalf
of a connected account, one that uses the `Stripe-Account` header containing an
account's ID, and one that uses the account's keys. Usually the former is the
recommended approach. [See the documentation for more information][connect].

To use the `Stripe-Account` approach, pass the `StripeAccount` field to a
`ListParams` or `Params` class. For example:

```go
// For a list request
listParams := &stripe.ChargeListParams{StripeAccount: merchantID}
```

```go
// For any other kind of request
params := &stripe.CustomerParams{StripeAccount: merchantID}
```

To use a key, pass it to `API`'s `Init` function:

```go

import (
	"github.com/stripe/stripe-go"
	"github.com/stripe/stripe-go/client"
)

stripe := &client.API{}
stripe.Init("access_token", nil)
```

### Google AppEngine

If you're running the client in a Google AppEngine environment, you'll need to
create a per-request Stripe client since the `http.DefaultClient` is not
available. Here's a sample handler:

```go
import (
	"fmt"
	"net/http"

	"google.golang.org/appengine"
	"google.golang.org/appengine/urlfetch"

	"github.com/stripe/stripe-go"
	"github.com/stripe/stripe-go/client"
)

func handler(w http.ResponseWriter, r *http.Request) {
	c := appengine.NewContext(r)
	httpClient := urlfetch.Client(c)

	sc := client.New("sk_live_key", stripe.NewBackends(httpClient))

	fmt.Fprintf(w, "Ready to make calls to the Stripe API")
}
```

## Usage

While some resources may contain more/less APIs, the following pattern is
applied throughout the library for a given `$resource$`:

### Without a Client

If you're only dealing with a single key, you can simply import the packages
required for the resources you're interacting with without the need to create a
client.

```go
import (
	"github.com/stripe/stripe-go"
	"github.com/stripe/stripe-go/$resource$"
)

// Setup
stripe.Key = "sk_key"

stripe.SetBackend("api", backend) // optional, useful for mocking

// Create
$resource$, err := $resource$.New(stripe.$Resource$Params)

// Get
$resource$, err := $resource$.Get(id, stripe.$Resource$Params)

// Update
$resource$, err := $resource$.Update(stripe.$Resource$Params)

// Delete
err := $resource$.Del(id)

// List
i := $resource$.List(stripe.$Resource$ListParams)
for i.Next() {
	$resource$ := i.$Resource$()
}

if err := i.Err(); err != nil {
	// handle
}
```

### With a Client

If you're dealing with multiple keys, it is recommended you use `client.API`.
This allows you to create as many clients as needed, each with their own
individual key.

```go
import (
	"github.com/stripe/stripe-go"
	"github.com/stripe/stripe-go/client"
)

// Setup
sc := &client.API{}
sc.Init("sk_key", nil) // the second parameter overrides the backends used if needed for mocking

// Create
$resource$, err := sc.$Resource$s.New(stripe.$Resource$Params)

// Get
$resource$, err := sc.$Resource$s.Get(id, stripe.$Resource$Params)

// Update
$resource$, err := sc.$Resource$s.Update(stripe.$Resource$Params)

// Delete
err := sc.$Resource$s.Del(id)

// List
i := sc.$Resource$s.List(stripe.$Resource$ListParams)
for i.Next() {
	resource := i.$Resource$()
}

if err := i.Err(); err != nil {
	// handle
}
```

## Development

Pull requests from the community are welcome. If you submit one, please keep
the following guidelines in mind:

1. Code must be `go fmt` compliant.
2. All types, structs and funcs should be documented.
3. Ensure that `make test` succeeds.

## Test

For running additional tests, follow the steps below:

Set the `STRIPE_KEY` environment variable to match your test private key, then
run `make test`:

```sh
STRIPE_KEY=YOUR_API_KEY make test
```

Or to run tests for a particular subpackage:

```sh
STRIPE_KEY=YOUR_API_KEY go test ./invoice
```

Or to run a particular test (it's worth noting however that Go will report a
success even if the referenced test doesn't exist):

```sh
STRIPE_KEY=YOUR_API_KEY go test -run "TestAllInvoicesScenarios" ./invoice
```

For any requests, bug or comments, please [open an issue][issues] or [submit a
pull request][pulls].

[api-docs]: https://stripe.com/docs/api/go
[api-changelog]: https://stripe.com/docs/upgrades
[connect]: https://stripe.com/docs/connect/authentication
[godoc]: http://godoc.org/github.com/stripe/stripe-go
[issues]: https://github.com/stripe/stripe-go/issues/new
[package-management]: https://code.google.com/p/go-wiki/wiki/PackageManagementTools
[pulls]: https://github.com/stripe/stripe-go/pulls
[stripe]: https://stripe.com
