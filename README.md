# Lidless

A Mac stays awake while the Eye is open. The Eye closes when the lid does.

Tolkien's Sauron has the Lidless Eye, the one that never sleeps. This is an app
about lids. That is the entire product and the entire joke.

Menu bar only. No Dock icon, no window, no preferences.

## What it actually does

`caffeinate` has two problems this exists to solve:

1. It has no say over clamshell sleep.
2. It survives a sleep/wake cycle, so a hold started before the lid closed is
   still holding when you reopen hours later.

Lidless holds two power assertions, `NoDisplaySleep` and
`PreventUserIdleSystemSleep`, and releases both on either of:

- **the lid closing**, polled every three seconds, because closing the lid with an
  external display attached does not sleep the machine and therefore notifies
  nothing;
- **the machine having slept**, via `NSWorkspace.didWakeNotification`.

No subprocesses, no PID files. The shell version of this shelled out to
`caffeinate`, `ioreg` and `pmset`; none of that survives sandboxing or reads
cleanly, and all of it is available as API.

On a desktop there is no clamshell, so `AppleClamshellState` is absent and only
the sleep condition can fire. The menu says so rather than promising lid
behaviour that cannot happen.

## Running it

```sh
cd app && xcodegen generate
xcodebuild -project Lidless.xcodeproj -scheme Lidless -configuration Release \
  -derivedDataPath build/dd CODE_SIGNING_ALLOWED=NO build
open build/dd/Build/Products/Release/Lidless.app
```

It registers itself as a login item on first launch, with the hold **off**. An app
that silently changes a laptop's power behaviour at login is how a battery dies
in a bag.

### Proving it works

The menu bar item cannot be clicked from a script, so there is a launch hook:

```sh
open -a Lidless --args --open-the-eye
pmset -g assertions | grep Lidless
```

Two assertions should appear. Do not trust the UI alone; the whole point of the
app is a system-level assertion, so check the system.

## Releasing

```sh
ASC_ISSUER=<issuer-uuid> ./scripts/release.sh
```

Builds, signs with Developer ID, notarizes, staples, and writes `dist/Lidless.dmg`.
`--unsigned` skips all of that for local testing and produces a DMG that
Gatekeeper will block.

## Getting the certificate

Signing for distribution outside the App Store needs a **Developer ID Application**
certificate. The App Store Connect API refuses to create one:

```
POST /v1/certificates  DEVELOPER_ID_APPLICATION -> 403
"This operation can only be performed by the Account Holder."
```

That is Apple's rule, not a permissions gap, so it cannot be automated. Steps are
in the release notes below.

## Known limits

- **It cannot sit next to the clock.** macOS places every third-party menu bar item
  to the left of the system cluster. Users can Cmd-drag to reorder among
  third-party icons; nothing can move right of the system ones.
- Developer ID certificates are limited per team and revoking one invalidates
  every app already signed with it. Create one, keep it, do not churn it.
