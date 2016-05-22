package lantern

import (
	"github.com/getlantern/flashlight/proxied"
	"github.com/getlantern/pro-server-client/go-client"
	"github.com/stripe/stripe-go"
)

type Session interface {
	UserId() int
	Code() string
	VerifyCode() string
	DeviceId() string
	Locale() string
	Referral() string
	PhoneNumber() string
	Token() string
	Plan() string
	StripeToken() string
	StripeEmail() string
	SetToken(string)
	SetUserId(int)
	SetCode(string)
}

type proRequest struct {
	proClient *client.Client
	user      client.User
	session   Session
}

type proFunc func(*proRequest) (*client.UserResponse, error)

func newRequest(shouldProxy bool, session Session) (*proRequest, error) {
	httpClient, err := proxied.GetHTTPClient(shouldProxy)
	if err != nil {
		log.Errorf("Could not create HTTP client: %v", err)
		return nil, err
	}

	req := &proRequest{
		proClient: client.NewClient(httpClient),
		user: client.User{
			Auth: client.Auth{
				DeviceID: session.DeviceId(),
				ID:       session.UserId(),
				Token:    session.Token(),
			},
		},
	}

	return req, nil
}

func newuser(r *proRequest) (*client.UserResponse, error) {
	res, err := r.proClient.UserCreate(r.user, r.session.Locale())
	if err != nil {
		log.Errorf("Could not create new Pro user: %v", err)
	} else {
		log.Debugf("Created new user with referral %s token %s id %d", res.User.Referral, res.User.Auth.Token, res.User.Auth.ID)
	}
	return res, err
}

func purchase(r *proRequest) (*client.UserResponse, error) {
	purchase := client.Purchase{
		IdempotencyKey: stripe.NewIdempotencyKey(),
		StripeToken:    r.session.StripeToken(),
		StripeEmail:    r.session.StripeEmail(),
	}

	if r.session.Plan() == "year" {
		purchase.Plan = client.PlanLanternPro1Y
	} else {
		purchase.Plan = client.PlanLanternPro1Y
	}
	return r.proClient.Purchase(r.user, purchase)
}

func number(r *proRequest) (*client.UserResponse, error) {
	r.user.PhoneNumber = r.session.PhoneNumber()
	log.Debugf("Phone number is %v", r.user.PhoneNumber)
	res, err := r.proClient.UserLinkConfigure(r.user)
	if err != nil || res.Status == "error" {
		res, err := r.proClient.UserLinkRequest(r.user)
		if err != nil {
			log.Errorf("Could not verify device: %v", err)
		}
		return res, err
	}
	return res, err
}

func code(r *proRequest) (*client.UserResponse, error) {
	r.user.Code = r.session.VerifyCode()
	return r.proClient.UserLinkValidate(r.user)
}

func referral(r *proRequest) (*client.UserResponse, error) {
	return r.proClient.RedeemReferralCode(r.user, r.session.Referral())
}

func cancel(r *proRequest) (*client.UserResponse, error) {
	return r.proClient.CancelSubscription(r.user)
}

func ProRequest(shouldProxy bool, command string, session Session) bool {

	req, err := newRequest(shouldProxy, session)
	if err != nil {
		return false
	}
	req.session = session

	log.Debugf("Received a %s pro request", command)

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

	if command == "newuser" {
		session.SetUserId(res.User.Auth.ID)
		session.SetToken(res.User.Auth.Token)
		session.SetCode(res.User.Referral)
	}

	return true
}
