# Google Play purchase flow (Android, v9.x)

How an in-app purchase made on Google Play is supposed to make its way from
the user's tap to a row in `pro_server.purchases` (or `pro_server.subscriptions`,
depending on the product type) — and where it currently falls down when any
single link in that chain fails.

This document covers the Android Google Play path only. iOS StoreKit and
Shepherd (AliPay/WeChat) have separate flows.

## Two product types in play

Lantern's Android Google Play catalog has changed over time, and both
flavors are still live in our customer base:

| Product type | Sold by | Server table populated | Google notification |
|---|---|---|---|
| **Subscription** (e.g. `1m_sub`, `1y_sub`) | v9.x (radiance / Flutter) — the **current** client | `pro_server.subscriptions` | `subscriptionNotification` RTDN |
| **One-time product** (e.g. `1y` legacy SKU) | v8.x (flashlight / lantern-client) — the **legacy** client | `pro_server.purchases` | `oneTimeProductNotification` RTDN (must be explicitly subscribed to in Play Console) |

The new VPN sells subscriptions only. Legacy one-time-product purchases
are ~2-3% of the volume (Jigar's estimate from the engineering#3464
thread) but they're a real population — they're users who bought on a
prior install of the v8 client and may now be on v9 trying to redeem
that entitlement.

**The two flows share most of the pipeline (Flutter → Kotlin → gomobile →
radiance → kindling → api.getiantem.org) but diverge at the server side
and in which DB tables they populate.** The diagrams below show the
subscription path; legacy one-time-product purchases follow a parallel
shape that writes to `pro_server.purchases` instead of `subscriptions`.

## Layers involved

| Layer | Purpose | Repo | Entry point |
|---|---|---|---|
| **Play Store** (local) | Charges the user's Google account, holds a record of the purchase on-device and on Google's servers | (Google) | `BillingClient` |
| **Flutter UI** | Initiates the purchase, listens for `BillingClient` callbacks, forwards the receipt to the ack pipeline | `getlantern/lantern` | `lib/features/plans/provider/payment_notifier.dart`, `lib/core/services/app_purchase.dart` |
| **Kotlin bridge** | Translates Flutter method-channel calls to gomobile FFI | `getlantern/lantern` | `android/app/src/main/kotlin/org/getlantern/lantern/handler/MethodHandler.kt` |
| **lantern-core** | Gomobile-exposed Go layer; forwards the ack to the radiance daemon over IPC | `getlantern/lantern-core` | `core.go:860` |
| **radiance daemon** | Local long-running process; speaks HTTP through kindling to Lantern's backend | `getlantern/radiance` | `ipc/client.go:636`, `backend/radiance.go:1132`, `account/subscription.go:112` |
| **pro-server** (HTTP API) | Receives the ack, verifies the token with Google, writes the entitlement | `getlantern/lantern-cloud` | `cmd/api/pro-server/handlers/subscription_gooleplay.go` (sic — upstream filename misses the second `g` in "googleplay"; the matching `_test.go` file is spelled correctly. Grep both spellings.) |
| **Postgres** | `pro_server.purchases` + `pro_users.level` | `lantern-cloud` Cloud SQL | n/a |

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
    Pro->>DB: INSERT INTO pro_server.purchases (purchase_token, user, ...)
    Pro->>DB: UPDATE pro_server.pro_users SET level='pro', expiration=...
    Pro-->>Radiance: 200 OK<br/>VerifySubscriptionResponse
    Radiance-->>Core: result
    Core-->>Kotlin: subscriptionData bytes
    Kotlin-->>Flutter: success
    Flutter->>Play: completePurchase(purchase)<br/>(acknowledge/consume locally)
    Flutter->>User: "You're now Pro" UI
```

Every link is single-shot. **There is no on-disk retry queue between steps 4 and 10**, and there is **no recovery mechanism** if the chain breaks anywhere in there.

## 2. What goes wrong in practice (today)

This is the failure pattern we've seen on multiple v9.1.x "paid but not upgraded" tickets (engineering#3464, support 173542, 173795, 174378/174862).

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

    Note over DB: No purchases row ever written
    Note over User: User restarts the app 8x over 6 days.<br/>Nothing replays. They file a refund ticket. 🐛
```

**Forensic signature of this failure** (from ticket 174862):

- Google Play `orders_get` shows the purchase as `PROCESSED`, `ACKNOWLEDGED`, `CONSUMED`.
- `pro_server.purchases` has **zero rows** for the purchase token.
- SigNoz: **zero log lines** mention the purchase token, the user_id, or `/v0/pro-server/purchase-googleplay-subscription` for that user over a 14-day window.
- The device IS communicating with the backend (datacap polling succeeds). So the device is not network-isolated; the ack call specifically didn't land.

We can't tell from the evidence whether the call was never made (steps 4-7) or made and failed at kindling (step 8). Both fit the data, and **both are bugs we have no recovery for**. The mitigation has to assume either failure mode.

## 3. The fix — startup-replay via `BillingClient.queryPurchases()`

Google's documented recovery pattern for *exactly* this case. `BillingClient.queryPurchases()` is a **local-only** call — it asks the on-device Play Store service "what purchases does this Google account hold against this app that haven't been acknowledged/consumed yet?" — no network, no auth, no Lantern backend involvement. The Play Store returns the list (including any that we failed to ack previously) and we re-fire the existing pipeline against each one.

**Product types**: Lantern's current Android catalog is subscription-only (`1m_sub`, `1y_sub` via `buyNonConsumable` at `app_purchase.dart:180`), so the relevant Play Billing query is `ProductType.SUBS`. The Flutter `in_app_purchase` plugin's `restorePurchases()` (which already wraps this) queries both `SUBS` and `INAPP` on Android, so we don't need to special-case either — using the existing helper is enough. Querying `INAPP` is still worth keeping in the loop in case legacy one-time-product purchases from older Lantern versions need to be recovered (e.g. some pre-9.0 purchases on Google have `oneTimePurchaseDetails`).

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
    Replay->>Play: queryPurchases(SUBS + INAPP)<br/>(the Flutter in_app_purchase plugin's<br/>restorePurchases() queries both types)
    Play-->>Replay: list of purchases the device holds
    loop For each purchase not already acked by Lantern's backend
        Replay->>Pipeline: acknowledgeInAppPurchase(token, planId)
        Pipeline->>Pro: POST /v0/pro-server/purchase-googleplay-subscription
        Pro->>DB: INSERT purchases row if missing<br/>UPDATE pro_users.level=pro
        Pro-->>Pipeline: 200 OK
        Pipeline-->>Replay: success — local Play purchase stays "acknowledged" with Google
    end
    Note over Replay,DB: Idempotent on the server side:<br/>repeat acks of the same token return the same row,<br/>no duplicates, no double-grant.
```

Key properties of this fix:

- **Local-only on the client side.** No call to Lantern's backend in step 2; no call to Google's servers from our app. Just Play Store IPC, which is always available when the Play Store is installed.
- **Idempotent on the server side.** `pro_server.purchases.purchase_token` is `UNIQUE` (`purchases_purchase_token_key`); duplicate inserts no-op cleanly. So replaying a purchase that already landed is safe.
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

Priority order, accounting for the legacy vs subscription split:

1. **Server-side: honor Google's RTDN as authoritative source of truth** (Adam's proposal on the #3464 Slack thread; analogous to the Stripe fix that landed earlier). For both `subscriptionNotification` and `oneTimeProductNotification` events, when the RTDN arrives the server should be able to INSERT the purchase / subscription row + apply Pro level *without* requiring a prior client-driven row to update. This is the highest-leverage server-side change because it makes every Google-charged purchase recoverable regardless of client delivery failures. **The customer in ticket 174862 (a legacy one-time-product purchase) is in this gap and is unrecoverable without it.**
2. **Server-side: enable `oneTimeProductNotification` subscriptions in Play Console + Pub/Sub** if they aren't already. RTDNs for one-time products are not on by default — they require explicit per-product opt-in via the Play Console's Real-Time Developer Notifications setup, and a matching Pub/Sub topic/subscription on our side. Worth checking before assuming the handler from item 1 has anything to consume.
3. **Action item #1** (engineering#3464): client-side on-disk retry queue for the original ack moment. Catches the case where step 4 in Diagram 2 fails before `queryPurchases` would have a chance to see the unack'd purchase. Strict superset of the startup-replay in coverage but bigger surface.
4. **Action item #2** (engineering#3464): client-side `BillingClient.queryPurchases(SUBS + INAPP)` startup replay — Diagram 3 above. Reduced priority vs the original framing: with items 1 + 2 in place, the server side becomes the source of truth and the client retry is a nice-to-have rather than the only path. Still worth shipping because it shortens the time to recovery for users who reopen their app.
5. **Action item #4** (engineering#3464): re-bind tool for stranded purchases where the `obfuscatedExternalProfileId` user_id no longer exists in `pro_users`. Required for the long tail and the broader v9.1.x "Pro lost on upgrade" pattern.

## References

- Engineering issue: [getlantern/engineering#3464](https://github.com/getlantern/engineering/issues/3464)
- Google's documentation on `queryPurchases` for recovery: <https://developer.android.com/google/play/billing/integrate#process>
- Server-side handler: `getlantern/lantern-cloud` `cmd/api/pro-server/handlers/subscription_gooleplay.go`
- Client transport (kindling): `getlantern/radiance` `kindling/client.go`
