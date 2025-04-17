package mobile

import (
	"context"
	"testing"

	"github.com/getlantern/radiance"
	"github.com/getlantern/radiance/client"
	"github.com/getlantern/radiance/user/protos"
	"github.com/zeebo/assert"
)

// func TestSetupRadiance(t *testing.T) {
// 	rr, err := radiance.NewRadiance("", nil)
// 	assert.Nil(t, err)
// 	assert.NotNil(t, rr)
// 	err1 := rr.StartVPN()
// 	assert.Nil(t, err1)
// }

//	func TestStartVPN(t *testing.T) {
//		rr, err := radiance.NewRadiance("", nil)
//		assert.Nil(t, err)
//		assert.NotNil(t, rr)
//		err1 := rr.StartVPN()
//		assert.Nil(t, err1)
//	}
func TestCreateUser(t *testing.T) {
	rr, err := radiance.NewRadiance(client.Options{
		DeviceID: "c8484d35d019ae02",
	})
	assert.Nil(t, err)
	assert.NotNil(t, rr)
	user, err := rr.Pro().UserCreate(context.Background())
	assert.Nil(t, err)
	assert.NotNil(t, user)
}
func TestSubscripationRedire(t *testing.T) {
	rr, err := radiance.NewRadiance(client.Options{
		DeviceID: "c8484d35d019ae02",
	})
	assert.Nil(t, err)
	assert.NotNil(t, rr)
	user, err := rr.Pro().SubscriptionPaymentRedirect(context.Background(), nil)
	assert.Nil(t, err)
	assert.NotNil(t, user)
	log.Debugf("user: %v", user.Redirect)
}

func TestSubscripation(t *testing.T) {
	rr, err := radiance.NewRadiance(client.Options{
		DeviceID: "c8484d35d019ae02",
	})
	body := &protos.SubscriptionRequest{
		Email:   "test@getlantern.org",
		Name:    "Test User",
		PriceId: "price_1RCg464XJ6zbDKY5T6kqbMC6",
	}
	assert.Nil(t, err)
	assert.NotNil(t, rr)
	user, err := rr.Pro().StripeSubscription(context.Background(), body)
	log.Debugf("user: %v", user)
	assert.Nil(t, err)
	assert.NotNil(t, user)
}
