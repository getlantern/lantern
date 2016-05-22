package lantern

import (
	"github.com/getlantern/flashlight/proxied"
	"github.com/getlantern/pro-server-client/go-client"
	"github.com/stripe/stripe-go"
)

type ProUser interface {
	UserId() int
	Code() string
	VerifyCode() string
	DeviceId() string
	Locale() string
	Email() string
	Referral() string
	PhoneNumber() string
	Token() string
	Plan() string
	StripeToken() string
	StripeEmail() string
	Set(string, string, int)
}

type proRequest struct {
	proClient *client.Client
	user      client.User
	proUser   ProUser
}

type proFunc func(*proRequest) (*client.UserResponse, error)

func newRequest(shouldProxy bool, proUser ProUser) (*proRequest, error) {
	httpClient, err := proxied.GetHTTPClient(shouldProxy)
	if err != nil {
		log.Errorf("Could not create HTTP client: %v", err)
		return nil, err
	}

	req := &proRequest{
		proClient: client.NewClient(httpClient),
		user: client.User{
			Auth: client.Auth{
				DeviceID: proUser.DeviceId(),
				ID:       proUser.UserId(),
				Token:    proUser.Token(),
			},
		},
		proUser: proUser,
	}

	return req, nil
}

func newuser(r *proRequest) (*client.UserResponse, error) {
	res, err := r.proClient.UserCreate(r.user, r.proUser.Locale())
	if err != nil {
		log.Errorf("Could not create new Pro user: %v", err)
	} else {
		log.Debugf("Created new user with referral %s token %s id %s", res.User.Referral, res.User.Auth.Token, res.User.Auth.ID)
		r.proUser.Set(res.User.Referral, res.User.Auth.Token, res.User.Auth.ID)
	}
	return res, err
}

func purchase(r *proRequest) (*client.UserResponse, error) {
	purchase := client.Purchase{
		IdempotencyKey: stripe.NewIdempotencyKey(),
		StripeToken:    r.proUser.StripeToken(),
		StripeEmail:    r.proUser.StripeEmail(),
	}

	if r.proUser.Plan() == "year" {
		purchase.Plan = client.PlanLanternPro1Y
	} else {
		purchase.Plan = client.PlanLanternPro1Y
	}
	return r.proClient.Purchase(r.user, purchase)
}

func number(r *proRequest) (*client.UserResponse, error) {
	r.user.PhoneNumber = r.proUser.PhoneNumber()
	res, err := r.proClient.UserLinkConfigure(r.user)
	if err != nil || res.Status == "error" {
		res, err = r.proClient.UserLinkRequest(r.user)
		if err != nil {
			log.Errorf("Could not verify device: %v", err)
		}
	}
	return res, err
}

func code(r *proRequest) (*client.UserResponse, error) {
	r.user.Code = r.proUser.VerifyCode()
	return r.proClient.UserLinkValidate(r.user)
}

func referral(r *proRequest) (*client.UserResponse, error) {
	return r.proClient.RedeemReferralCode(r.user, r.proUser.Referral())
}

func cancel(r *proRequest) (*client.UserResponse, error) {
	return r.proClient.CancelSubscription(r.user)
}

func ProRequest(shouldProxy bool, command string, user ProUser) bool {

	req, err := newRequest(shouldProxy, user)
	if err != nil {
		return false
	}

	commands := map[string]proFunc{
		"newuser":  newuser,
		"purchase": purchase,
		"number":   number,
		"code":     code,
		"referral": referral,
		"cancel":   cancel,
	}

	res, err := commands[command](req)
	if err != nil || res.Status != "ok" {
		log.Errorf("Error making request to Pro server: %v", err)
		return false
	}

	return true
}
