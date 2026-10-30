package lanterncore

import (
	"bytes"
	"context"
	"crypto/rand"
	"crypto/sha256"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"math/big"
	"net/http"
	"strconv"
	"strings"
	"time"

	"github.com/1Password/srp"
	"golang.org/x/crypto/pbkdf2"

	"github.com/getlantern/radiance/account"
	"github.com/getlantern/radiance/common"
	"github.com/getlantern/radiance/common/settings"
	"github.com/getlantern/radiance/kindling"
)

type legacyEmailAccount interface {
	Settings(context.Context) (settings.Settings, error)
	LoginForAccount(context.Context, string, string, int64) (*account.UserData, error)
}

type legacyEmailBinder struct {
	account legacyEmailAccount
	http    *http.Client
	authURL string
	proURL  string
	timeout time.Duration
}

type legacyEmailIdentity struct {
	userID int64
	token  string
	device string
}

func (lc *LanternCore) legacyEmailBinder() legacyEmailBinder {
	return legacyEmailBinder{
		account: lc.client, http: kindling.HTTPClient(),
		authURL: common.GetBaseURL(), proURL: common.GetProServerURL(),
	}
}

func (b legacyEmailBinder) identity(ctx context.Context) (legacyEmailIdentity, error) {
	s, err := b.account.Settings(ctx)
	if err != nil {
		return legacyEmailIdentity{}, err
	}
	id := fmt.Sprint(s[settings.UserIDKey])
	if number, ok := s[settings.UserIDKey].(float64); ok {
		id = strconv.FormatFloat(number, 'f', -1, 64)
	}
	userID, err := strconv.ParseInt(id, 10, 64)
	token, _ := s[settings.TokenKey].(string)
	device, _ := s[settings.DeviceIDKey].(string)
	if err != nil || userID <= 0 || token == "" || device == "" {
		return legacyEmailIdentity{}, errors.New("not logged in")
	}
	return legacyEmailIdentity{userID: userID, token: token, device: device}, nil
}

func (b legacyEmailBinder) start(ctx context.Context, email string) error {
	ctx, cancel := b.withTimeout(ctx)
	defer cancel()
	identity, err := b.identity(ctx)
	if err != nil {
		return err
	}
	return b.request(ctx, identity, http.MethodPost, b.authURL+"/users/bind_legacy_email",
		map[string]string{"email": strings.ToLower(strings.TrimSpace(email))}, nil)
}

func (b legacyEmailBinder) complete(ctx context.Context, email, password, code string) error {
	identityCtx, cancel := b.withTimeout(ctx)
	identity, err := b.identity(identityCtx)
	cancel()
	if err != nil {
		return err
	}
	email = strings.ToLower(strings.TrimSpace(email))
	if email == "" || password == "" {
		return errors.New("email and password are required")
	}
	salt := make([]byte, 16)
	if _, err := rand.Read(salt); err != nil {
		return err
	}
	key := pbkdf2.Key([]byte(password+email), salt, 4096, 32, sha256.New)
	client := srp.NewSRPClient(srp.KnownGroups[srp.RFC5054Group3072], new(big.Int).SetBytes(key), nil)
	verifier, err := client.Verifier()
	if err != nil {
		return err
	}
	request := struct {
		Email       string `json:"email"`
		Code        string `json:"code"`
		NewSalt     []byte `json:"new_salt"`
		NewVerifier []byte `json:"new_verifier"`
	}{email, code, salt, verifier.Bytes()}
	requestCtx, cancel := b.withTimeout(ctx)
	err = b.request(requestCtx, identity, http.MethodPost, b.authURL+"/users/bind_legacy_email/complete", request, nil)
	cancel()
	if err != nil {
		if ctx.Err() != nil {
			return ctx.Err()
		}
		// A committed binding may outlive its response or verification code.
		var data account.UserDataResponse
		recoveryCtx, cancel := b.withTimeout(ctx)
		fetchErr := b.request(recoveryCtx, identity, http.MethodGet, b.proURL+"/user-data", nil, &data)
		cancel()
		if ctx.Err() != nil {
			return ctx.Err()
		}
		if fetchErr != nil ||
			data.LoginResponse_UserData == nil || data.UserId != identity.userID || !strings.EqualFold(data.Email, email) {
			return err
		}
	}
	loginCtx, cancel := b.withTimeout(ctx)
	defer cancel()
	user, err := b.account.LoginForAccount(loginCtx, email, password, identity.userID)
	if err != nil {
		return fmt.Errorf("legacy_email_bound_login_required: %w", err)
	}
	if user == nil || !user.Success || user.LegacyID != identity.userID {
		return errors.New("legacy_email_bound_login_required")
	}
	return nil
}

func (b legacyEmailBinder) withTimeout(ctx context.Context) (context.Context, context.CancelFunc) {
	timeout := b.timeout
	if timeout <= 0 {
		timeout = common.DefaultHTTPTimeout
	}
	return context.WithTimeout(ctx, timeout)
}

type legacyEmailAPIError struct {
	status  int
	message string
}

func (e *legacyEmailAPIError) Error() string {
	if e.message == "" {
		return fmt.Sprintf("legacy email binding: HTTP %d", e.status)
	}
	return fmt.Sprintf("legacy email binding: HTTP %d: received bad response: %s", e.status, e.message)
}

func (b legacyEmailBinder) request(ctx context.Context, identity legacyEmailIdentity, method, url string, body, result any) error {
	var data []byte
	var err error
	if body != nil {
		data, err = json.Marshal(body)
		if err != nil {
			return err
		}
	}
	req, err := http.NewRequestWithContext(ctx, method, url, bytes.NewReader(data))
	if err != nil {
		return err
	}
	req.Header.Set(common.UserIDHeader, strconv.FormatInt(identity.userID, 10))
	req.Header.Set(common.ProTokenHeader, identity.token)
	req.Header.Set(common.DeviceIDHeader, identity.device)
	req.Header.Set(common.AppNameHeader, common.Name)
	req.Header.Set(common.AppVersionHeader, common.GetVersion())
	req.Header.Set(common.PlatformHeader, common.Platform)
	req.Header.Set("Accept", "application/json")
	if body != nil {
		req.Header.Set("Content-Type", "application/json")
	}
	client := *b.http
	client.CheckRedirect = func(*http.Request, []*http.Request) error { return http.ErrUseLastResponse }
	resp, err := client.Do(req)
	if err != nil {
		return err
	}
	defer resp.Body.Close()
	reader := io.LimitReader(resp.Body, 1<<20)
	if resp.StatusCode < 200 || resp.StatusCode >= 300 {
		var detail struct {
			Message string `json:"msg"`
		}
		_ = json.NewDecoder(reader).Decode(&detail)
		return &legacyEmailAPIError{status: resp.StatusCode, message: detail.Message}
	}
	if result != nil {
		return json.NewDecoder(reader).Decode(result)
	}
	return nil
}
