package mobile

import (
	"context"
	"os"
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
	opta := client.Options{
		DeviceID: "c8484d35d019ae02",
		Locale:   "en-us",
		DataDir:  os.TempDir(),
		LogDir:   os.TempDir(),
	}

	rr, err := radiance.NewRadiance(opta)
	api, err := radiance.NewAPIHandler(opta)
	assert.Nil(t, err)
	assert.NotNil(t, rr)
	user, err := api.ProServer.UserCreate(context.Background())
	assert.Nil(t, err)
	assert.NotNil(t, user)
}

// func TestSubscriptionRedirect(t *testing.T) {
// 	rr, err := radiance.NewRadiance(client.Options{
// 		DeviceID: "c8484d35d019ae02",
// 	})
// 	assert.Nil(t, err)
// 	assert.NotNil(t, rr)
// 	user, err := rr.Pro().SubscriptionPaymentRedirect(context.Background(), nil)
// 	assert.Nil(t, err)
// 	assert.NotNil(t, user)
// 	log.Debugf("user: %v", user.Redirect)
// }

func TestUserData(t *testing.T) {
	opta := client.Options{
		DeviceID: "c8484d35d019ae02",
		Locale:   "en-us",
		DataDir:  os.TempDir(),
		LogDir:   os.TempDir(),
	}

	rr, err := radiance.NewRadiance(opta)
	api, err := radiance.NewAPIHandler(opta)
	assert.Nil(t, err)
	assert.NotNil(t, rr)
	user, err := api.ProServer.UserData(context.Background())
	log.Debugf("user: %v", user)
	assert.Nil(t, err)
	assert.NotNil(t, user)
}

func TestSubscription(t *testing.T) {
	opta := client.Options{
		DeviceID: "c8484d35d019ae02",
		Locale:   "en-us",
		DataDir:  os.TempDir(),
		LogDir:   os.TempDir(),
	}

	rr, err := radiance.NewRadiance(opta)
	api, err := radiance.NewAPIHandler(opta)
	assert.Nil(t, err)
	assert.NotNil(t, rr)
	user, err := api.User.OAuthLoginUrl(context.Background(), "google")
	log.Debugf("user: %v", user)
	assert.Nil(t, err)
	assert.NotNil(t, user)
}
