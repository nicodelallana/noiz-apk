# iOS Live Activities & Dynamic Island Integration Guide

This guide documents the exact configuration steps required in Xcode to enable Barik's ActivityKit Live Activities and Dynamic Island support on iOS 16.1+.

---

## 1. Prerequisites
- **Xcode:** 15.0 or later.
- **Deployment Target:** iOS 16.1+ (iOS 17.0+ recommended for full interactive widgets).
- **Target Architecture:** arm64 (physical devices and simulator).

---

## 2. Project Target Setup

### Step A: Add Widget Extension
1. Open `ios/Runner.xcworkspace` in Xcode.
2. Select **File → New → Target...**
3. Choose **Widget Extension** under iOS Application Extension.
4. Set Target details:
   - **Product Name:** `LiveTripWidget`
   - **Language:** Swift
   - **Configuration Intent:** Do NOT check "Include Configuration Intent" (ActivityKit uses static `ActivityAttributes`).
   - Check **Include Live Activity**.
5. When prompted, click **Activate** scheme.

### Step B: Link Source Files
Ensure the following files in `ios/LiveTripWidget/` have Target Membership checked for **both** `Runner` and `LiveTripWidget`:
- `LiveTripWidgetAttributes.swift`
- `LiveTripWidgetLiveActivity.swift`

---

## 3. Info.plist Configuration

In `ios/Runner/Info.plist`, ensure the following keys are present:

```xml
<key>NSSupportsLiveActivities</key>
<true/>
<key>NSSupportsLiveActivitiesFrequentUpdates</key>
<true/>
```

---

## 4. App Groups & Shared Keychain (Optional for Push-to-Start)
1. In Xcode, navigate to `Runner` target → **Signing & Capabilities**.
2. Click **+ Capability** → **App Groups**.
3. Add group identifier: `group.com.bizkaia.transit`.
4. Repeat the same capability for `LiveTripWidgetExtension`.

---

## 5. Live Activity Lifecycle & APNs Push Token Handling

To update lock-screen activities when the app is suspended or killed, register APNs push tokens:

```swift
if #available(iOS 16.1, *) {
    Task {
        for await token in activity.pushTokenUpdates {
            let tokenString = token.map { String(format: "%02.2hhx", $0) }.joined()
            // Forward tokenString to Supabase live_trip_sessions table
        }
    }
}
```

---

## 6. Verification with SwiftUI Previews
In Xcode, open `LiveTripWidgetLiveActivity.swift` and use the SwiftUI Canvas to inspect:
- State 1: `tracking` (Normal on-time transit).
- State 2: `delayed` (+3 min in amber).
- State 3: `arriving` (Vehicle within 200m of destination).
- State 4: `at_stop` (Train stopped at platform).
- State 5: `ended` (Arrival checkmark banner).
