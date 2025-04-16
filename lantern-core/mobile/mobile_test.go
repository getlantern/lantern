package mobile

import (
	"context"
	"testing"

	"github.com/getlantern/radiance"
	"github.com/getlantern/radiance/client"
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
