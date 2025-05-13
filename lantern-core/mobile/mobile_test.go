package mobile

import (
	"context"
	"os"
	"testing"

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
	assert.Nil(t, err)
	assert.NotNil(t, rr)

}

func TestStartVPN(t *testing.T) {
	data := radianceOptions().DataDir
	log := radianceOptions().LogDir
	rr, err := client.NewVPNClient(data, log, nil, false)
	assert.Nil(t, err)
	assert.NotNil(t, rr)
	err1 := rr.StartVPN()
	assert.Nil(t, err1)
}

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
	log.Debugf("user: %v", user)
	assert.Nil(t, err)
	assert.NotNil(t, user)
}

func TestOAuthLoginUrl(t *testing.T) {
	rr, err := radiance.NewRadiance(radianceOptions())
	api := rr.APIHandler().User
	assert.Nil(t, err)
	assert.NotNil(t, rr)
	user, err := api.OAuthLoginUrl(context.Background(), "google")
	log.Debugf("user: %v", user)
	assert.Nil(t, err)
	assert.NotNil(t, user)
}
