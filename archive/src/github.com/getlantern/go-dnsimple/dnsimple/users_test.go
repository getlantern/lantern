package dnsimple

import (
	"fmt"
	"net/http"
	"reflect"
	"testing"
)

func TestUsersService_User(t *testing.T) {
	setup()
	defer teardown()

	mux.HandleFunc("/v1/user", func(w http.ResponseWriter, r *http.Request) {
		testMethod(t, r, "GET")
		fmt.Fprint(w, `
			{
			  "user": {
				"id": 1,
				"email": "example@example.com",
				"referral_token": "referral-token",
				"api_token": "api-token",
				"domain_count": 32,
				"domain_limit": 1000,
				"login_count": 2,
				"failed_login_count": 1,
				"created_at": "2011-03-17T21:30:25.731Z",
				"updated_at": "2014-12-13T13:52:08.343Z"
			  }
			}
		`)
	})

	user, _, err := client.Users.User()

	if err != nil {
		t.Errorf("Users.User returned error: %v", err)
	}

	want := User{Id: 1, Email: "example@example.com"}
	if !reflect.DeepEqual(user, want) {
		t.Errorf("Users.User returned %+v, want %+v", user, want)
	}
}
