package lantern

import (
	"github.com/getlantern/flashlight/proxied"
	"github.com/getlantern/pro-server-client/go-client"
	"github.com/stripe/stripe-go"
)

const (
	defaultCurrencyCode = `usd`
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
	Currency() string
	AddPlan(string, string, bool, int, int)
}

type proRequest struct {
	proClient *client.Client
	user      client.User
	session   Session
}

type proFunc func(*proRequest) (*client.Response, error)

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

func newuser(r *proRequest) (*client.Response, error) {
	r.proClient.SetLocale(r.session.Locale())
	res, err := r.proClient.UserCreate(r.user)
	if err != nil {
		log.Errorf("Could not create new Pro user: %v", err)
	} else {
		log.Debugf("Created new user with referral %s token %s id %d", res.User.Referral, res.User.Auth.Token, res.User.Auth.ID)
	}
	return res, err
}

func purchase(r *proRequest) (*client.Response, error) {
	purchase := client.Purchase{
		IdempotencyKey: stripe.NewIdempotencyKey(),
		StripeToken:    r.session.StripeToken(),
		StripeEmail:    r.session.StripeEmail(),
		Plan:           r.session.Plan(),
	}

	return r.proClient.Purchase(r.user, purchase)
}

func number(r *proRequest) (*client.Response, error) {
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

func code(r *proRequest) (*client.Response, error) {
	r.user.Code = r.session.VerifyCode()
	return r.proClient.UserLinkValidate(r.user)
}

func referral(r *proRequest) (*client.Response, error) {
	return r.proClient.RedeemReferralCode(r.user, r.session.Referral())
}

func cancel(r *proRequest) (*client.Response, error) {
	return r.proClient.CancelSubscription(r.user)
}

func plans(r *proRequest) (*client.Response, error) {
	return r.proClient.Plans(r.user)
}

// addPlans gets the latest plan prices from the Pro server and
// updates the 'Get Lantern Pro' screen w/ them.
func addPlans(plans []client.Plan, session Session) {
	for _, plan := range plans {

		currency := session.Currency()
		price, exists := plan.Price[currency]
		if !exists {
			// if we somehow have an invalid cucrency
			// and its not found in our map, default to 'usd'
			price, _ = plan.Price[defaultCurrencyCode]
		}
		session.AddPlan(plan.Id, plan.Description, plan.BestValue, plan.Duration.Years, price)
	}

}

func ProRequest(shouldProxy bool, command string, session Session) bool {

	req, err := newRequest(shouldProxy, session)
	if err != nil {
		log.Errorf("Error creating new request: %v", err)
		return false
	}
	req.session = session

	req.proClient.SetLocale(session.Locale())

	log.Debugf("Received a %s pro request", command)

	commands := map[string]proFunc{
		"newuser":  newuser,
		"purchase": purchase,
		"plans":    plans,
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

	if command == "plans" {
		addPlans(res.Plans, session)
	} else if command == "newuser" {
		session.SetUserId(res.User.Auth.ID)
		session.SetToken(res.User.Auth.Token)
		session.SetCode(res.User.Referral)
	}

	return true
}
