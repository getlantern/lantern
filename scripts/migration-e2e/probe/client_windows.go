//go:build windows

package main

import (
	"context"

	"github.com/getlantern/radiance/account"
	"github.com/getlantern/radiance/common/settings"
	"github.com/getlantern/radiance/ipc"
)

type windowsClient struct{ client *ipc.Client }

func newPlatformClient() (serviceClient, error) { return &windowsClient{client: ipc.NewClient()}, nil }
func (client *windowsClient) Close()            { client.client.Close() }

func accountState(data *account.UserData) accountFacts {
	if data == nil || data.LegacyUserData == nil {
		return accountFacts{}
	}
	return accountFacts{Valid: true, UserID: data.LegacyID, NestedID: data.LegacyUserData.UserId,
		Token: data.LegacyToken, NestedToken: data.LegacyUserData.Token,
		DeviceID: data.LegacyUserData.DeviceID, UserLevel: data.LegacyUserData.UserLevel}
}

func (client *windowsClient) UserData(ctx context.Context) (accountFacts, error) {
	data, err := client.client.UserData(ctx)
	return accountState(data), err
}

func (client *windowsClient) FetchUserData(ctx context.Context) (accountFacts, error) {
	data, err := client.client.FetchUserData(ctx)
	return accountState(data), err
}

func (client *windowsClient) Settings(ctx context.Context) (settingsFacts, error) {
	data, err := client.client.Settings(ctx)
	if err != nil {
		return settingsFacts{}, err
	}
	token, tokenOK := data[settings.TokenKey].(string)
	device, deviceOK := data[settings.DeviceIDKey].(string)
	locale, localeOK := data[settings.LocaleKey].(string)
	level, levelOK := data[settings.UserLevelKey].(string)
	autoReport, reportOK := data[settings.TelemetryKey].(bool)
	smartRouting, routingOK := data[settings.SmartRoutingKey].(bool)
	autoLaunch, launchOK := data[settings.LegacyAutoLaunchKey].(bool)
	return settingsFacts{Valid: tokenOK && deviceOK && localeOK && levelOK && reportOK && routingOK && launchOK,
		Token: token, DeviceID: device, Locale: locale, UserLevel: level,
		AutoReport: autoReport, SmartRouting: smartRouting, AutoLaunch: autoLaunch}, nil
}

func (client *windowsClient) VPNStatus(ctx context.Context) (string, error) {
	status, err := client.client.VPNStatus(ctx)
	return string(status), err
}

func (client *windowsClient) ConnectVPN(ctx context.Context) error {
	return client.client.ConnectVPN(ctx, "")
}

func (client *windowsClient) DisconnectVPN(ctx context.Context) error {
	return client.client.DisconnectVPN(ctx)
}
