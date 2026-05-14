# Google Play purchase flow (Android, v9.x)

**Scope**: this document covers the **v9.x Android Google Play subscription flow only** — the path used by the radiance + Flutter client to sell subscription products (e.g. `1m_sub`, `1y_sub`). iOS StoreKit, Shepherd (AliPay/WeChat), Stripe, and the legacy pre-radiance Lantern client all have separate flows and are out of scope.

How an in-app purchase made on Google Play is supposed to make its way from the user's tap to a row in `pro_server.subscriptions` and a `level = pro` update on `pro_server.pro_users` — and where it can fall down when any single link in that chain fails.

## Layers involved

| Layer | Purpose | Repo | Entry point |
|---|---|---|---|
| **Play Store** (local) | Charges the user's Google account, holds a record of the purchase on-device and on Google's servers | (Google) | `BillingClient` |
| **Flutter UI** | Initiates the purchase, listens for `BillingClient` callbacks, forwards the receipt to the ack pipeline | `getlantern/lantern` | `lib/features/plans/provider/payment_notifier.dart`, `lib/core/services/app_purchase.dart` |
| **Kotlin bridge** | Translates Flutter method-channel calls to gomobile FFI | `getlantern/lantern` | `android/app/src/main/kotlin/org/getlantern/lantern/handler/MethodHandler.kt` |
| **lantern-core** | Gomobile-exposed Go layer; forwards the ack to the radiance daemon over IPC | `getlantern/lantern-core` | `core.go:860` |
| **radiance daemon** | Local long-running process; speaks HTTP through kindling to Lantern's backend | `getlantern/radiance` | `ipc/client.go:636`, `backend/radiance.go:1132`, `account/subscription.go:112` |
| **pro-server** (HTTP API) | Receives the ack, verifies the token with Google, writes the entitlement | `getlantern/lantern-cloud` | `cmd/api/pro-server/handlers/subscription_gooleplay.go` (sic — upstream filename misses the second `g` in "googleplay"; the matching `_test.go` file is spelled correctly. Grep both spellings.) |
| **Postgres** | `pro_server.subscriptions` (purchase metadata + status) + `pro_server.pro_users` (level/expiration) | `lantern-cloud` Cloud SQL | n/a |

## 1. Happy path — what's supposed to happen

```mermaid
sequenceDiagram
    autonumber
    actor User
    participant Play as Play Store<br/>(local + Google)
    participant Flutter as Flutter<br/>app_purchase.dart
    participant Kotlin as Kotlin bridge<br/>MethodHandler.kt
    participant Core as lantern-core<br/>core.go
    participant Radiance as radiance daemon<br/>account/subscription.go
    participant Pro as pro-server (api)<br/>subscription_gooleplay.go
    participant DB as Postgres<br/>pro_server.*

    User->>Flutter: Tap "Buy Pro" plan
    Flutter->>Play: launchBillingFlow(productId, obfuscatedAccountId=device_id, obfuscatedProfileId=user_id)
    Play->>User: Google Play UI charges card
    Play-->>Flutter: onPurchasesUpdated(purchase)<br/>app_purchase.dart:_onPurchaseUpdates
    Note over Flutter: app_purchase.dart:380<br/>extract purchaseToken + planId ⚠️
    Flutter->>Kotlin: lanternService.acknowledgeInAppPurchase(token, planId)<br/>lantern_service.dart:336
    Kotlin->>Core: Mobile.acknowledgeGooglePurchase(token, planId)<br/>MethodHandler.kt:452
    Core->>Radiance: IPC POST subscriptionVerifyEndpoint<br/>ipc/client.go:636
    Radiance->>Pro: POST /v0/pro-server/purchase-googleplay-subscription<br/>account/subscription.go:112<br/>via kindling.HTTPClient()
    Pro->>Play: Google Purchases.Subscriptionsv2.Get(token) [verify]
    Play-->>Pro: verified, ACTIVE
    Pro->>DB: INSERT INTO pro_server.subscriptions (subscription_id=purchaseToken, user, plan_id, status, ...)
    Pro->>DB: UPDATE pro_server.pro_users SET level='pro', expiration=...
    Pro-->>Radiance: 200 OK<br/>VerifySubscriptionResponse
    Radiance-->>Core: result
    Core-->>Kotlin: subscriptionData bytes
    Kotlin-->>Flutter: success
    Flutter->>Play: completePurchase(purchase)<br/>(acknowledge/consume locally)
    Flutter->>User: "You're now Pro" UI
```

Every link is single-shot. **There is no on-disk retry queue between steps 4 and 10**, and there is **no recovery mechanism** if the chain breaks anywhere in there.

## 2. What can go wrong

The chain has no on-disk persistence and no retry. Any single failure in steps 4–10 of Diagram 1 silently strands the purchase — the user has paid Google but our backend never gets the message.

```mermaid
sequenceDiagram
    autonumber
    actor User
    participant Play as Play Store<br/>(local + Google)
    participant Flutter as Flutter<br/>app_purchase.dart
    participant Kotlin as Kotlin bridge<br/>MethodHandler.kt
    participant Core as lantern-core<br/>core.go
    participant Radiance as radiance daemon
    participant Pro as pro-server (api)
    participant DB as Postgres

    User->>Flutter: Tap "Buy Pro"
    Flutter->>Play: launchBillingFlow(...)
    Play->>User: User pays $51.95
    Play-->>Flutter: onPurchasesUpdated(purchase) ⚠️

    rect rgba(255, 200, 200, 0.3)
        Note over Flutter,Pro: 🐛 ANY of these failing strands the purchase permanently:<br/>app_purchase.dart fires ack once, no on-disk persistence, no retry.
        Flutter-xKotlin: app_purchase.dart:380 — process killed, FFI exception, or daemon down ⛔
        Note right of Flutter: failure logged & forgotten<br/>(no on-disk queue)
        Kotlin-xCore: MethodHandler.kt:452 — gomobile crash / panic ⛔
        Core-xRadiance: ipc/client.go:636 — daemon restarting<br/>(connect: connection refused) ⛔
        Radiance-xPro: account/subscription.go:112 — kindling best-effort circumvention fails this dial ⛔
        Pro-xDB: FK violation if user_id was rolled back / GC'd ⛔
    end

    Note over DB: No subscriptions row ever written
    Note over User: User reopens the app — nothing replays automatically.<br/>They file a refund ticket. 🐛
```

**Forensic signature** of a stranded purchase:

- Google Play `orders_get` / `purchases_subscriptions_v2_get` shows the purchase as `PURCHASED` / `ACKNOWLEDGED`
- `pro_server.subscriptions` has zero rows for the purchase token (`subscription_id` column is the purchase token)
- SigNoz: zero log lines mention the purchase token, the user_id, or any `handleGooglePlayPurchase` activity for that user
- The device IS communicating with the backend (datacap polling, config-new, etc. succeed) — so the device is not network-isolated; the ack call specifically didn't reach our backend

Once the chain breaks, there is currently no automatic recovery — the client doesn't queue the failed ack to disk, doesn't reattempt on app launch, and the server has no parallel path that can recover the entitlement from Google directly. The mitigations in section 3 below close those gaps.

## 3. The fix — startup-replay via `BillingClient.queryPurchases()`

Google's documented recovery pattern for *exactly* this case. `BillingClient.queryPurchases()` is a **local-only** call — it asks the on-device Play Store service "what purchases does this Google account hold against this app that haven't been acknowledged/consumed yet?" — no network, no auth, no Lantern backend involvement. The Play Store returns the list (including any that we failed to ack previously) and we re-fire the existing pipeline against each one.

**Product type**: the v9.x Android catalog is subscription-only (`1m_sub`, `1y_sub` via `buyNonConsumable` at `app_purchase.dart:180`), so the relevant Play Billing query is `ProductType.SUBS`. The Flutter `in_app_purchase` plugin's `restorePurchases()` (which already wraps this) handles `BillingClient.queryPurchases` on Android automatically, so the existing helper is enough — see "Where this connects to existing code" below.

```mermaid
sequenceDiagram
    autonumber
    participant AppLifecycle as App lifecycle<br/>(launch, resume, tunnel-up)
    participant Replay as Replay routine<br/>(NEW — app_purchase.dart)
    participant Play as Play Store<br/>(local only)
    participant Pipeline as Existing ack pipeline<br/>(steps 5-10 of Diagram 1)
    participant Pro as pro-server (api)
    participant DB as Postgres

    AppLifecycle->>Replay: init() / onResume() / on tunnel-up
    Replay->>Play: queryPurchases(SUBS)<br/>(via in_app_purchase plugin's restorePurchases)
    Play-->>Replay: list of subscriptions the device holds
    loop For each purchase not already acked by Lantern's backend
        Replay->>Pipeline: acknowledgeInAppPurchase(token, planId)
        Pipeline->>Pro: POST /v0/pro-server/purchase-googleplay-subscription
        Pro->>DB: INSERT pro_server.subscriptions row if missing<br/>UPDATE pro_users.level=pro
        Pro-->>Pipeline: 200 OK
        Pipeline-->>Replay: success — local Play purchase stays "acknowledged" with Google
    end
    Note over Replay,DB: Idempotent on the server side:<br/>repeat acks of the same token return the same row,<br/>no duplicates, no double-grant.
```

Key properties of this fix:

- **Local-only on the client side.** No call to Lantern's backend in step 2; no call to Google's servers from our app. Just Play Store IPC, which is always available when the Play Store is installed.
- **Idempotent on the server side.** `pro_server.subscriptions.subscription_id` is `UNIQUE` (`unique_subscription_id`) and is set to the purchase token; duplicate inserts no-op cleanly. So replaying a purchase that already landed is safe.
- **Fires at three lifecycle moments**: app launch (`init()`), foreground resume (`onResume`), and successful tunnel-up. Each gives the next chance to recover.
- **Doesn't require user action.** Today's `restorePurchases()` works the same way but only fires on a manual "Restore" tap — most affected users never find that button before filing a support ticket.

## Where this connects to the existing code

The lantern repo already has `restorePurchases()` at `lib/core/services/app_purchase.dart:198` that wraps `_inAppPurchase.restorePurchases()` (the `in_app_purchase` plugin's wrapper around `BillingClient.queryPurchases`). The existing call:

- Sets `_isRestoreFlow = true` and shows "restore" UI feedback to the user
- Only fires when the user explicitly taps "Restore" in the settings screen

The minimal change for action item #2:

- Add a `_replayPendingAcks()` method that does the same internal work as `restorePurchases()` but without setting `_isRestoreFlow` (so it's silent — no UI banner saying "restoring" on every app launch).
- Call `_replayPendingAcks()` at the end of `init()` (after the purchase stream is wired up so any deferred-purchase signals are routed correctly).
- Also call it on a `WidgetsBindingObserver.didChangeAppLifecycleState(AppLifecycleState.resumed)` listener.
- Optionally also call it from a hook fired when the radiance daemon reports tunnel-up.

The server-side endpoint already handles replays correctly (`purchase_token` is unique-constrained; the handler updates user level if the purchase row already exists but level wasn't yet bumped).

## Open follow-ups

Coverage gaps in the current v9 pipeline. Priority order:

1. **Server-side: honor Google's `subscriptionNotification` RTDN as authoritative source of truth**, analogous to the Stripe fix. When the RTDN arrives, the server should INSERT the subscription row + apply Pro level if no row exists yet, instead of dropping the message after retries. Makes every Google-charged subscription recoverable regardless of whether the client ack ever landed.
2. **Client-side: on-disk retry queue for the original ack moment.** Catches the case where step 4 in Diagram 1 fails before `queryPurchases` would have a chance to see the unack'd purchase. Strict superset of the startup-replay in coverage, larger surface.
3. **Client-side: `BillingClient.queryPurchases(SUBS)` startup replay** — Diagram 3 above. Lower priority once item 1 lands (server becomes the source of truth), but worth shipping because it shortens time to recovery for users who reopen their app before the RTDN-replay path catches up. Touches `lib/core/services/app_purchase.dart` only.
4. **Operations: re-bind / manual remediation tool** for stranded purchases that fall outside the automated recovery paths. Customer-support relief lever.

## References

- Engineering issue: [getlantern/engineering#3464](https://github.com/getlantern/engineering/issues/3464)
- Google's documentation on `queryPurchases` for recovery: <https://developer.android.com/google/play/billing/integrate#process>
- Server-side handler: `getlantern/lantern-cloud` `cmd/api/pro-server/handlers/subscription_gooleplay.go`
- Client transport (kindling): `getlantern/radiance` `kindling/client.go`
