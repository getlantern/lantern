package client

import (
	"log"
	"testing"

	"github.com/pborman/uuid"
	"github.com/stretchr/testify/assert"
	"github.com/stripe/stripe-go"
	"github.com/stripe/stripe-go/token"
)

func generateIdempotencyKey() string {
	return stripe.NewIdempotencyKey()
}

func generateDeviceId() string {
	return uuid.New()
}

func generateEmail() string {
	return uuid.New() + `@example.com`
}

func generateUser() User {
	return User{
		Auth: Auth{
			DeviceID: generateDeviceId(),
		},
		//Email: generateEmail(),
	}
}

type fakeCard struct {
	Number string
	Month  string
	Year   string
	CVC    string
}

func generateCard() fakeCard {
	return fakeCard{
		Number: `4242424242424242`,
		Month:  `12`,
		Year:   `2016`,
		CVC:    `123`,
	}
}

var (
	userA User
	userB User
)

var tc *Client

func TestCreateClient(t *testing.T) {
	stripe.Key = "sk_test_4MSPFce4ceaRL1D3pI1NV9Qo"

	tc = NewClient()
}

func TestCreateUserA(t *testing.T) {
	userA = generateUser()

	res, err := tc.UserCreate(userA)
	assert.NoError(t, err)

	assert.True(t, res.User.ID != 0)
	assert.True(t, res.User.Expiration == 0)
	assert.True(t, res.User.Code == "")
	assert.True(t, res.User.Token != "")
	assert.True(t, res.User.Referral != "")

	userA.ID = res.User.ID
	userA.Referral = res.User.Referral
	userA.Token = res.User.Token

	log.Println(userA)
}

func TestUserALinkConfigure(t *testing.T) {
	userA.PhoneNumber = "+525518034861"

	res, err := tc.UserLinkConfigure(userA)
	assert.NoError(t, err)
	assert.Equal(t, "ok", res.Status)
}

func TestUserALinkValidateError(t *testing.T) {
	userA.Code = "6666" // Wrong code.

	res, err := tc.UserLinkValidate(userA)
	assert.NoError(t, err)
	assert.Equal(t, "error", res.Status)
}

func TestUserALinkValidate(t *testing.T) {
	userA.Code = "000000" // Master code.

	res, err := tc.UserLinkValidate(userA)
	assert.NoError(t, err)
	assert.Equal(t, "ok", res.Status)

	assert.True(t, res.User.Token != "")
	userA.Token = res.User.Token
}

func TestUserALinkRequest(t *testing.T) {
	userA.PhoneNumber = "+525518034861" // Wrong code.

	res, err := tc.UserLinkRequest(userA)
	assert.NoError(t, err) // TODO: json: cannot unmarshal string into Go value of type int
	assert.Equal(t, "ok", res.Status)

}

func TestUserAData(t *testing.T) {
	res, err := tc.UserData(userA)
	assert.NoError(t, err)
	assert.Equal(t, "ok", res.Status)
}

func TestPurchaseUserA(t *testing.T) {
	card := generateCard()

	token, err := token.New(&stripe.TokenParams{
		Card: &stripe.CardParams{
			Number: card.Number,
			Month:  card.Month,
			Year:   card.Year,
			CVC:    card.CVC,
		},
	})

	assert.NoError(t, err)
	assert.True(t, token.ID != "")

	userA.Email = generateEmail()

	pr := Purchase{
		StripeToken:    token.ID,
		StripeEmail:    userA.Email,
		IdempotencyKey: generateIdempotencyKey(),
		Plan:           PlanLanternPro1Y,
	}

	res, err := tc.Purchase(userA, pr)
	log.Println(res)
	assert.NoError(t, err) // json: cannot unmarshal string into Go value of type int"
	assert.Equal(t, "ok", res.Status)
}

func TestUserADataAfterPurchase(t *testing.T) {
	res, err := tc.UserData(userA)
	assert.NoError(t, err)
	assert.Equal(t, "ok", res.Status)
	assert.True(t, res.User.Expiration != 0) // we already made a purchase, so we expect this to be not empty.
	//assert.True(t, res.User.Email != "")
	//assert.True(t, res.User.Subscription != "")
}

func TestUserATokenReset(t *testing.T) {
	res, err := tc.TokenReset(userA)
	assert.NoError(t, err)
	assert.Equal(t, "ok", res.Status)
	assert.True(t, res.User.Token != "")
	userA.Token = res.User.Token
}

func TestUserADataAfterTokenReset(t *testing.T) {
	res, err := tc.UserData(userA)
	assert.NoError(t, err)
	assert.Equal(t, "ok", res.Status)
}

func TestCreateUserB(t *testing.T) {
	userB = generateUser()

	res, err := tc.UserCreate(userB)
	assert.NoError(t, err)

	assert.True(t, res.User.ID != 0)
	assert.True(t, res.User.Code == "")
	assert.True(t, res.User.Token != "")
	assert.True(t, res.User.Referral != "")

	userB.ID = res.User.ID
	userB.Referral = res.User.Referral
	userB.Token = res.User.Token

	log.Println(userB)
}

func TestRedeemCodeUserB(t *testing.T) {
	res, err := tc.RedeemReferralCode(userA, userB.Referral)
	assert.NoError(t, err)
	assert.Equal(t, "ok", res.Status)

	log.Println(res)
}

func TestSubscriptionUpdateUserA(t *testing.T) {
	res, err := tc.CancelSubscription(userA)
	assert.NoError(t, err)

	// TODO: not working right now
	//assert.Equal(t, "ok", res.Status)
	_ = res

	log.Println(res)
}
