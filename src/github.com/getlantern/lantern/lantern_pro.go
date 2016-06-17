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
	Email() string
	SetToken(string)
	SetUserId(int)
	UserData(string, int64, string)
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
		StripeEmail:    r.session.Email(),
		Plan:           r.session.Plan(),
		Currency:       r.session.Currency(),
	}

	return r.proClient.Purchase(r.user, purchase)
}

func number(r *proRequest) (*client.Response, error) {
	r.user.Email = r.session.Email()
	res, err := r.proClient.UserLinkConfigure(r.user)
	if err != nil || res.Status != "ok" {
		return r.proClient.UserLinkRequest(r.user)
	}
	return res, err
}

func signin(r *proRequest) (*client.Response, error) {
	r.user.Email = r.session.Email()
	return r.proClient.UserLinkRequest(r.user)
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

func userdata(r *proRequest) (*client.Response, error) {
	return r.proClient.UserData(r.user)
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
		"signin":   signin,
		"code":     code,
		"userdata": userdata,
		"referral": referral,
		"cancel":   cancel,
	}

	res, err := commands[command](req)
	if err != nil || res.Status != "ok" {
		log.Errorf("Error making request to Pro server: %v", err)
		return false
	}

	if command == "plans" {
		for _, plan := range res.Plans {

			currency := session.Currency()
			price, exists := plan.Price[currency]
			if !exists {
				price, _ = plan.Price[defaultCurrencyCode]
			}

			log.Debugf("Calling add plan with %s desc: %s best value %t price %d",
				plan.Id, plan.Description, plan.BestValue, price)
			session.AddPlan(plan.Id, plan.Description, plan.BestValue, plan.Duration.Years, price)
		}

	} else if command == "signin" {
		session.SetUserId(res.User.Auth.ID)
	} else if command == "newuser" {
		session.SetUserId(res.User.Auth.ID)
		session.SetToken(res.User.Auth.Token)
		session.SetCode(res.User.Referral)
	} else if command == "code" {
		res, err = commands["userdata"](req)
		if err != nil || res.Status != "ok" {
			log.Errorf("Error making request to Pro server: %v", err)
			return false
		}
		session.UserData(res.User.UserStatus, res.User.Expiration, res.User.Subscription)
	}

	return true
}
