package mobile

import (
	"testing"
	"time"

	"github.com/getlantern/radiance/ipc"
)

func TestGetClientDoesNotWaitForIPCLifecycleLock(t *testing.T) {
	want := &ipc.Client{}
	ipcClient.Store(want)
	t.Cleanup(func() {
		ipcClient.Store(nil)
	})

	ipcMu.Lock()
	defer ipcMu.Unlock()

	result := make(chan *ipc.Client, 1)
	go func() {
		client, _ := getClient()
		result <- client
	}()

	select {
	case got := <-result:
		if got != want {
			t.Fatalf("getClient() = %p, want %p", got, want)
		}
	case <-time.After(time.Second):
		t.Fatal("getClient blocked on the IPC lifecycle lock")
	}
}

// // todo implement a mock for all test cases
// func radianceOptions() radiance.Options {
// 	return radiance.Options{
// 		DataDir:  os.TempDir(),
// 		LogDir:   os.TempDir(),
// 		DeviceID: "test-123",
// 		Locale:   "en-us",
// 	}
// }

// func TestSetupRadiance(t *testing.T) {
// 	rr, err := radiance.NewRadiance(radianceOptions())
// 	assert.Nil(t, err)
// 	assert.NotNil(t, rr)

// }

// // // skip this test for now
// // func TestStartVPN(t *testing.T) {
// // 	data := radianceOptions().DataDir
// // 	log := radianceOptions().LogDir
// // 	rr, err := client.NewVPNClient(data, log, nil, false)
// // 	assert.Nil(t, err)
// // 	assert.NotNil(t, rr)
// // 	err1 := rr.StartVPN()
// // 	assert.Nil(t, err1)
// // }

// func TestCreateUser(t *testing.T) {
// 	rr, err := radiance.NewRadiance(radianceOptions())
// 	api := rr.APIHandler()
// 	assert.Nil(t, err)
// 	assert.NotNil(t, rr)
// 	user, err := api.NewUser(context.Background())
// 	assert.Nil(t, err)
// 	assert.NotNil(t, user)
// }

// func TestSubscriptionRedirect(t *testing.T) {
// 	rr, err := radiance.NewRadiance(radianceOptions())
// 	apiClient := rr.APIHandler()
// 	assert.Nil(t, err)
// 	assert.NotNil(t, rr)
// 	data := api.PaymentRedirectData{
// 		Provider:    "stripe",
// 		Plan:        "monthly",
// 		DeviceName:  "test-123",
// 		Email:       "test@getlantern.org",
// 		BillingType: api.SubscriptionTypeSubscription,
// 	}
// 	user, err := apiClient.SubscriptionPaymentRedirectURL(context.Background(), data)
// 	assert.Nil(t, err)
// 	assert.NotNil(t, user)
// }

// func TestUserData(t *testing.T) {
// 	rr, err := radiance.NewRadiance(radianceOptions())
// 	api := rr.APIHandler()
// 	assert.Nil(t, err)
// 	assert.NotNil(t, rr)
// 	user, err := api.UserData(context.Background())
// 	assert.Nil(t, err)
// 	assert.NotNil(t, user)
// }

// func TestPlans(t *testing.T) {
// 	rr, err := radiance.NewRadiance(radianceOptions())
// 	api := rr.APIHandler()
// 	assert.Nil(t, err)
// 	assert.NotNil(t, rr)
// 	plans, err := api.SubscriptionPlans(context.Background(), "non-store")
// 	assert.Nil(t, err)
// 	assert.NotNil(t, plans)
// }

// func TestOAuthLoginUrl(t *testing.T) {
// 	rr, err := radiance.NewRadiance(radianceOptions())
// 	api := rr.APIHandler()
// 	assert.Nil(t, err)
// 	assert.NotNil(t, rr)
// 	user, err := api.OAuthLoginUrl(context.Background(), "google")
// 	assert.Nil(t, err)
// 	assert.NotNil(t, user)
// }
