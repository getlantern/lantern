package bindings

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
		DeviceID: generateDeviceId(),
		// Email:    generateEmail(),
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
)

func TestCreateClient(t *testing.T) {
	stripe.Key = "sk_test_4MSPFce4ceaRL1D3pI1NV9Qo"
}

func TestCreateUserA(t *testing.T) {
	userA = generateUser()

	_, err := UserCreate(&userA)
	assert.NoError(t, err)

	assert.True(t, userA.ID != 0)
	assert.True(t, userA.Referral != "")
	assert.True(t, userA.Code == "")

	log.Println(userA)
}

func TestVerifyPhoneStep1UserA(t *testing.T) {
	userA.PhoneNumber = "+525518034861"

	res, err := UserLinkConfigure(&userA)
	assert.NoError(t, err)

	log.Println(userA)
	log.Println(res)
}

func TestVerifyPhoneStep2UserA(t *testing.T) {
	// This would be the code the user received.
	userA.Code = "666"

	res, err := UserLinkValidate(&userA)
	assert.Error(t, err) // Which is obviously wrong.

	log.Println(userA)
	log.Println(res)
}

func TestVerifyPhoneStep2UserAMasterCode(t *testing.T) {
	// This is a master code.
	userA.Code = "000000"

	res, err := UserLinkValidate(&userA)
	assert.NoError(t, err)

	log.Println(userA)
	log.Println(res)
}

func TestPurchaseWithUserA(t *testing.T) {
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
		Plan:           PLAN_LANTERN_PRO_1Y,
	}

	res, err := PurchasePlan(&userA, &pr)
	log.Println(res)
	assert.NoError(t, err)

	log.Printf("token: %v", token)
	log.Printf("userA: %v", userA)
}

func TestGetUserAData(t *testing.T) {
	_, err := UserData(&userA)
	assert.NoError(t, err)
}

func TestGetUserATokenReset(t *testing.T) {
	_, err := TokenReset(&userA)
	assert.NoError(t, err)
}

func TestGetUserADataAfterTokenReset(t *testing.T) {
	_, err := UserData(&userA)
	assert.NoError(t, err)
}
