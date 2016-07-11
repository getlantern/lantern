package bindings

import (
	"errors"
	"github.com/getlantern/pro-server-client/go-client"
)

// Status values.
const (
	STATUS_OK           = "ok"
	PLAN_LANTERN_PRO_1Y = string(client.PlanLanternPro1Y)
)

var proClient *client.Client

func init() {
	proClient = client.NewClient()
}

// Code represents a User code.
type Code struct {
	Code string
}

// Purchase represents data from Stripe.
type Purchase struct {
	StripeToken    string
	IdempotencyKey string
	StripeEmail    string
	Plan           string
}

// User represents an user.
type User struct {
	ID            int
	Email         string
	Expiration    int64
	AutoconfToken string
	Code          string
	Referral      string
	DeviceID      string
	Token         string
	PhoneNumber   string
}

func toClientPurchase(p *Purchase) client.Purchase {
	return client.Purchase{
		StripeToken:    p.StripeToken,
		IdempotencyKey: p.IdempotencyKey,
		StripeEmail:    p.StripeEmail,
		Plan:           client.Plan(p.Plan),
	}
}

func toClientUser(u *User) client.User {
	return client.User{
		Auth: client.Auth{
			ID:       u.ID,
			DeviceID: u.DeviceID,
			Token:    u.Token,
		},
		PhoneNumber:   u.PhoneNumber,
		Email:         u.Email,
		Expiration:    u.Expiration,
		AutoconfToken: u.AutoconfToken,
		Code:          u.Code,
		Referral:      u.Referral,
	}
}

func fromClientUser(v client.User) *User {
	return &User{
		ID:            v.Auth.ID,
		Email:         v.Email,
		Expiration:    v.Expiration,
		AutoconfToken: v.AutoconfToken,
		PhoneNumber:   v.PhoneNumber,
		Code:          v.Code,
		Referral:      v.Referral,
		DeviceID:      v.DeviceID,
		Token:         v.Token,
	}
}

// UserCreate wraps POST /user-create
func UserCreate(u *User) (*User, error) {
	v, err := proClient.UserCreate(toClientUser(u))
	if err != nil {
		return nil, err
	}
	if v.Status == STATUS_OK {
		c := fromClientUser(v.User)
		u.ID = c.ID
		u.Referral = c.Referral
		u.Token = v.Token
		return u, nil
	}
	return nil, errors.New(v.Error)
}

// UserLinkConfigure requests an authentication code.
func UserLinkConfigure(u *User) (*User, error) {
	v, err := proClient.UserLinkConfigure(toClientUser(u))
	if err != nil {
		return nil, err
	}
	if v.Status == STATUS_OK {
		return fromClientUser(v.User), nil
	}
	return nil, errors.New(v.Error)
}

// UserLinkValidate validates the authentication code.
func UserLinkValidate(u *User) (*User, error) {
	v, err := proClient.UserLinkValidate(toClientUser(u))
	if err != nil {
		return nil, err
	}
	if v.Status == STATUS_OK {
		r := fromClientUser(v.User)
		u.Token = r.Token
		return u, nil
	}
	return nil, errors.New(v.Error)
}

// UserLinkRequest performs device linking or user recovery.
func UserLinkRequest(u *User) (*User, error) {
	v, err := proClient.UserLinkRequest(toClientUser(u))
	if err != nil {
		return nil, err
	}
	if v.Status == STATUS_OK {
		return fromClientUser(v.User), nil
	}
	return nil, errors.New(v.Error)
}

// PurchasePlan performs a purchase.
func PurchasePlan(u *User, p *Purchase) (*User, error) {
	v, err := proClient.Purchase(toClientUser(u), toClientPurchase(p))
	if err != nil {
		return nil, err
	}
	if v.Status == STATUS_OK {
		return fromClientUser(v.User), nil
	}
	return nil, errors.New(v.Error)
}

// CancelSubscription cancels the current user's subscription.
func CancelSubscription(u *User) error {
	v, err := proClient.CancelSubscription(toClientUser(u))
	if err != nil {
		return nil
	}
	if v.Status == STATUS_OK {
		return nil
	}
	return errors.New(v.Error)
}

// SubscriptionUpdate updates the current user's plan.
func SubscriptionUpdate(u *User, planID string) (*User, error) {
	v, err := proClient.SubscriptionUpdate(toClientUser(u), planID)
	if err != nil {
		return nil, err
	}
	if v.Status == STATUS_OK {
		return fromClientUser(v.User), nil
	}
	return nil, errors.New(v.Error)
}

// RedeemReferralCode validates and redeems a referral code.
func RedeemReferralCode(u *User, referralCode string) error {
	v, err := proClient.RedeemReferralCode(toClientUser(u), referralCode)
	if err != nil {
		return nil
	}
	if v.Status == STATUS_OK {
		return nil
	}
	return errors.New(v.Error)
}

// UserData returns information about the user
func UserData(u *User) (*User, error) {
	v, err := proClient.UserData(toClientUser(u))
	if err != nil {
		return nil, err
	}
	if v.Status == STATUS_OK {
		return fromClientUser(v.User), nil
	}
	return nil, errors.New(v.Error)
}

// TokenReset
func TokenReset(u *User) (*User, error) {
	v, err := proClient.TokenReset(toClientUser(u))
	if err != nil {
		return nil, err
	}
	if v.Status == STATUS_OK {
		u.Token = v.Token
		return u, nil
	}
	return nil, errors.New(v.Error)
}
