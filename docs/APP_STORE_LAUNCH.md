# v1 App Store launch — status

App: **Forget Me Not: Habit Builder** · `com.lucianlabs.forgetmenot` · ASC app id `6796055439`
Version record: **1.0** (PREPARE_FOR_SUBMISSION)

## Done (via the App Store Connect API)

| Item | Value |
|---|---|
| Name | Forget Me Not: Habit Builder |
| Subtitle | Reminders that come back |
| Description | Written — the "things that never get finished" angle |
| Keywords | routine, chores, recurring, reminder, tracker, streak, cleaning, laundry, hydration, adhd, daily, checklist |
| Promotional text | set |
| Support URL | https://tasks.lucianlabs.ca/support.html |
| Marketing URL | https://tasks.lucianlabs.ca |
| Privacy policy URL | https://tasks.lucianlabs.ca/privacy.html |
| Categories | Productivity (primary) · Health & Fitness (secondary) |
| Age rating | 4+ (everything declared none/false) |
| Screenshots | iPhone 6.9" ×2, iPad 13" ×1 — captured from a **Release** build |
| Build | 261 attached; **264** uploaded and auto-attaching once processed |

Privacy + support pages are live and version-controlled in `public/`.

## Still needs you (not possible via API)

1. **App Privacy questionnaire** — App Store Connect ▸ App Privacy. The honest answer is
   **"Data Not Collected"**: no analytics, no tracking, no ads, and `PrivacyInfo.xcprivacy`
   already declares an empty `NSPrivacyCollectedDataTypes` with `NSPrivacyTracking = false`.
   (The web push server stores reminder titles, but that's the *website*, not this app.)
2. **App Review contact phone** — the API refuses `appStoreReviewDetails` without
   `contactPhone`. Everything else for it is drafted (name, email, notes saying no login is
   needed). Add the phone in ASC ▸ App Review Information.
3. **Pricing & availability** — price tier (free?) and territories.
4. **Submit for review.**

## Notes for review

- No account or login — nothing for a reviewer to sign into.
- On-device only: icon generation + nudge text use Apple Intelligence where available and
  fall back to static text. Nothing is sent to a server.
- iPad is supported (`TARGETED_DEVICE_FAMILY = 1,2`), so it gets reviewed on iPad too.
- The local MCP dev server is `#if DEBUG` only and is compiled out of Release (verified).
