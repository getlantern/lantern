package mobile

import (
	"context"
	"os"
	"testing"

	"github.com/getlantern/lantern-outline/lantern-core/stub"
	"github.com/getlantern/radiance"
	"github.com/getlantern/radiance/api/protos"
	"github.com/getlantern/radiance/client"
	"github.com/zeebo/assert"
)

func radianceOptions() radiance.Options {
	return radiance.Options{
		DataDir:  os.TempDir(),
		LogDir:   os.TempDir(),
		DeviceID: "test-123",
		Locale:   "en-us",
	}
}

func TestSetupRadiance(t *testing.T) {
	rr, err := radiance.NewRadiance(radianceOptions())
	client, err := client.NewVPNClient(os.TempDir(), os.TempDir(), stub.NewPlatformInterfaceStub(), enableSplitTunneling())
	err = client.StartVPN()
	assert.Nil(t, err)
	assert.NotNil(t, rr)

}

// // skip this test for now
// func TestStartVPN(t *testing.T) {
// 	data := radianceOptions().DataDir
// 	log := radianceOptions().LogDir
// 	rr, err := client.NewVPNClient(data, log, nil, false)
// 	assert.Nil(t, err)
// 	assert.NotNil(t, rr)
// 	err1 := rr.StartVPN()
// 	assert.Nil(t, err1)
// }

func TestCreateUser(t *testing.T) {
	rr, err := radiance.NewRadiance(radianceOptions())
	api := rr.APIHandler().ProServer
	assert.Nil(t, err)
	assert.NotNil(t, rr)
	user, err := api.UserCreate(context.Background())
	assert.Nil(t, err)
	assert.NotNil(t, user)
}

func TestSubscriptionRedirect(t *testing.T) {
	rr, err := radiance.NewRadiance(radianceOptions())
	api := rr.APIHandler().ProServer
	assert.Nil(t, err)
	assert.NotNil(t, rr)
	data := protos.SubscriptionPaymentRedirectRequest{
		Provider:         "stripe",
		Plan:             "monthly",
		DeviceName:       "test-123",
		Email:            "test@getlantern.org",
		SubscriptionType: protos.SubscriptionTypeMonthly,
	}
	user, err := api.SubscriptionPaymentRedirect(context.Background(), &data)
	assert.Nil(t, err)
	assert.NotNil(t, user)
}

func TestUserData(t *testing.T) {
	rr, err := radiance.NewRadiance(radianceOptions())
	api := rr.APIHandler().ProServer
	assert.Nil(t, err)
	assert.NotNil(t, rr)
	user, err := api.UserData(context.Background())
	assert.Nil(t, err)
	assert.NotNil(t, user)
}

func TestPlans(t *testing.T) {
	rr, err := radiance.NewRadiance(radianceOptions())
	api := rr.APIHandler().ProServer
	assert.Nil(t, err)
	assert.NotNil(t, rr)
	plans, err := api.Plans(context.Background(), "non-store")
	assert.Nil(t, err)
	assert.NotNil(t, plans)
}

func TestOAuthLoginUrl(t *testing.T) {
	rr, err := radiance.NewRadiance(radianceOptions())
	api := rr.APIHandler().User
	assert.Nil(t, err)
	assert.NotNil(t, rr)
	user, err := api.OAuthLoginUrl(context.Background(), "google")
	assert.Nil(t, err)
	assert.NotNil(t, user)
}
