package client

import (
	"bytes"
	"encoding/json"
	"errors"
	"io/ioutil"
	"log"
	"math"
	"net/http"
	"net/url"
	"strings"
	"time"
)

var (
	defaultTimeout = time.Second * 30
	maxRetries     = 12
	retryBaseTime  = time.Millisecond * 100
)

const defaultLocale = "en_US"

const (
	endpointPrefix = `https://api.getiantem.org`
)

const (
	XLanternDeviceID = "X-Lantern-Device-Id"
	XLanternUserID   = "X-Lantern-User-Id"
	XLanternProToken = "X-Lantern-Pro-Token"
)

var (
	ErrAPIUnavailable = errors.New("API unavailable.")
)

type Client struct {
	httpClient *http.Client
	locale     string
}

func (c *Client) get(endpoint string, header http.Header, params url.Values) ([]byte, error) {
	if params == nil {
		params = url.Values{}
	}

	params.Set("timeout", "10")
	params.Set("locale", c.locale)

	encodedParams := params.Encode()

	if encodedParams != "" {
		encodedParams = "?" + encodedParams
	}

	req, err := http.NewRequest("GET", endpointPrefix+endpoint+encodedParams, nil)
	if err != nil {
		return nil, err
	}
	if req.Header == nil {
		req.Header = http.Header{}
	}
	for k := range header {
		req.Header[k] = header[k]
	}
	return c.do(req)
}

func (c *Client) do(req *http.Request) ([]byte, error) {
	var buf []byte
	if req.Body != nil {
		var err error
		buf, err = ioutil.ReadAll(req.Body)
		if err != nil {
			return nil, err
		}
	}

	for i := 0; i < maxRetries; i++ {
		client := c.httpClient
		log.Printf("%s %s %v", req.Method, req.URL, req.Header)
		if len(buf) > 0 {
			req.Body = ioutil.NopCloser(bytes.NewBuffer(buf))
		}

		res, err := client.Do(req)
		if err == nil {
			defer res.Body.Close()
			switch res.StatusCode {
			case 200:
				body, err := ioutil.ReadAll(res.Body)
				log.Printf("body: %s\n", string(body))
				return body, err
			case 202:
				// Accepted: Immediately retry idempotent operation
				log.Printf("Received 202, retrying idempotent operation immediately.")
				continue
			default:
				body, err := ioutil.ReadAll(res.Body)
				if err == nil {
					log.Printf("Expecting 200, got: %d, body: %v", res.StatusCode, string(body))
				} else {
					log.Printf("Expecting 200, got: %d, could not get body: %v", res.StatusCode, err)
				}
			}
		} else {
			log.Printf("Do: %v, res: %v", err, res)
		}

		retryTime := time.Duration(math.Pow(2, float64(i))) * retryBaseTime
		log.Printf("timed out, waiting %v to retry.", retryTime)
		time.Sleep(retryTime)
	}
	return nil, ErrAPIUnavailable
}

func (c *Client) post(endpoint string, header http.Header, post url.Values) ([]byte, error) {
	if post == nil {
		post = url.Values{}
	}
	post.Set("locale", c.locale)

	req, err := http.NewRequest("POST", endpointPrefix+endpoint, strings.NewReader(post.Encode()))
	if err != nil {
		return nil, err
	}
	if req.Header == nil {
		req.Header = http.Header{}
	}
	req.Header.Set("Content-Type", "application/x-www-form-urlencoded")
	for k := range header {
		req.Header[k] = header[k]
	}
	return c.do(req)
}

func NewClient(httpClient *http.Client) *Client {
	if httpClient == nil {
		httpClient = &http.Client{
			Timeout: defaultTimeout,
		}
	}
	return &Client{locale: defaultLocale, httpClient: httpClient}
}

func (c *Client) SetLocale(locale string) {
	c.locale = locale
}

// UserCreate creates an user without asking for any payment.
func (c *Client) UserCreate(user User) (res *UserResponse, err error) {
	var payload []byte
	payload, err = c.post(`/user-create`, http.Header{
		XLanternDeviceID: {user.Auth.DeviceID},
	}, nil)
	if err != nil {
		return nil, err
	}
	err = json.Unmarshal(payload, &res)
	return
}

// UserLinkConfigure allows the client to initiate the configuration of a
// verified method of authenticating a user.
func (c *Client) UserLinkConfigure(user User) (res *UserResponse, err error) {
	var payload []byte
	payload, err = c.post(`/user-link-configure`, user.headers(),
		url.Values{
			"telephone": {user.PhoneNumber},
		},
	)
	if err != nil {
		return nil, err
	}
	err = json.Unmarshal(payload, &res)
	return
}

// CancelSubscription cancels the subscription.
func (c *Client) CancelSubscription(user User) (*UserResponse, error) {
	return c.SubscriptionUpdate(user, "cancel")
}

// SubscriptionUpdate changes the next billable term to the requested
// subscription Id. It is used also to cancel a subscription, by providing the
// subscription Id cancel.
func (c *Client) SubscriptionUpdate(user User, subscriptionId string) (res *UserResponse, err error) {
	var payload []byte
	payload, err = c.post(`/subscription-update`, user.headers(),
		url.Values{
			"plan": {subscriptionId},
		},
	)
	if err != nil {
		return nil, err
	}
	err = json.Unmarshal(payload, &res)
	return
}

// RedeemReferralCode redeems a referral code.
func (c *Client) RedeemReferralCode(user User, referralCode string) (res *UserResponse, err error) {
	var payload []byte
	payload, err = c.post(`/referral-attach`, user.headers(),
		url.Values{
			"code": {referralCode},
		},
	)
	if err != nil {
		return nil, err
	}
	err = json.Unmarshal(payload, &res)
	return
}

// UserLinkValidate allows the client to initiate the configuration of a
// verified method of authenticating a user.
func (c *Client) UserLinkValidate(user User) (res *UserResponse, err error) {
	var payload []byte
	payload, err = c.post(`/user-link-validate`, user.headers(),
		url.Values{
			"code": {user.Code},
		},
	)
	if err != nil {
		return nil, err
	}
	err = json.Unmarshal(payload, &res)
	return
}

// UserLinkRequest Perform device linking or user recovery.
func (c *Client) UserLinkRequest(user User) (res *UserResponse, err error) {
	var payload []byte
	payload, err = c.post(`/user-link-request`, user.headers(),
		url.Values{
			"telephone": {user.PhoneNumber},
		},
	)
	if err != nil {
		return nil, err
	}
	err = json.Unmarshal(payload, &res)
	return
}

// UserData Returns all user data, including payments, referrals and all
// available fields.
func (c *Client) UserData(user User) (res *UserResponse, err error) {
	var payload []byte
	payload, err = c.get(`/user-data`, user.headers(), nil)
	if err != nil {
		return nil, err
	}
	err = json.Unmarshal(payload, &res)
	return
}

// Purchase single endpoint used for performing purchases.
func (c *Client) Purchase(user User, purchase Purchase) (res *UserResponse, err error) {
	var payload []byte
	payload, err = c.post(`/purchase`, user.headers(),
		url.Values{
			"stripeEmail":    {purchase.StripeEmail},
			"idempotencyKey": {purchase.IdempotencyKey},
			"stripeToken":    {purchase.StripeToken},
			"plan":           {purchase.Plan},
		},
	)
	if err != nil {
		return nil, err
	}
	err = json.Unmarshal(payload, &res)
	return
}

// TokenReset Request a token change. This will generate a new one and send it
// to the requesting device.
func (c *Client) TokenReset(user User) (res *UserResponse, err error) {
	var payload []byte
	payload, err = c.post(`/token-reset`, user.headers(), nil)
	if err != nil {
		return nil, err
	}
	err = json.Unmarshal(payload, &res)
	return
}

// ChargeByID Request payment details by id.
func (c *Client) ChargeByID(user User, chargeID string) (res *UserResponse, err error) {
	var payload []byte
	payload, err = c.get(`/charge-by-id`, user.headers(),
		url.Values{
			"changeId": {chargeID},
		},
	)
	if err != nil {
		return nil, err
	}
	err = json.Unmarshal(payload, &res)
	return
}
