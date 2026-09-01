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

It registers itself as a login item on first launch. The Eye opens on every
launch of the app, including that silent one at login — one click on the menu
bar icon closes it again, and it stays closed until opened the same way.

### Proving it works

The menu bar item cannot be clicked from a script, but the Eye is open as soon
as the app launches, so no hook is needed to trigger it:

```sh
open -a Lidless
pmset -g assertions | grep Lidless
```

Two assertions should appear. Do not trust the UI alone; the whole point of the
app is a system-level assertion, so check the system.

## Releasing

```sh
ASC_KEY_ID=<key-id> ASC_ISSUER=<issuer-uuid> ./scripts/release.sh
```

Builds, signs with Developer ID, notarizes, staples, and writes `dist/Lidless.dmg`.
`--unsigned` skips all of that for local testing and produces a DMG that
Gatekeeper will block.

## The certificate

Signed by **Bossa Nova Solutions (`AR7DXKP4VP`)**, on a Developer ID Application
certificate valid until **2031-08-27**. Not Tee Time Trainer: Developer ID
creation is restricted to the team's Account Holder, which Fellipe is on Bossa
Nova and is not on Tee Time Trainer.

**No API key can create one, on any team, at any role.** Both certificate types
were tried against both teams and all four returned:

```
POST /v1/certificates -> 403
"This operation can only be performed by the Account Holder."
```

It is a human-in-the-portal step by design. Do not spend time automating it.

**The private key lives at `~/.app-store/lidless/devid.key` and nowhere else.**
It never left this machine, which is the point, and the certificate is worthless
without it. Losing it costs one of the five Developer ID slots the team gets.
Back it up.

Expect a one-time keychain access prompt the first time `codesign` reaches for
the key on any machine. The first build fails, the second succeeds; that is the
prompt, not a bug.

## Distribution

Releases go out as **GitHub Releases**, not committed to the repo:

```sh
ASC_KEY_ID=<key-id> ASC_ISSUER=<issuer-uuid> ./scripts/release.sh
gh release create v1.0 dist/Lidless.dmg --title "Lidless 1.0" --notes "..."
```

Teammates download the DMG, drag to Applications, and open it. The notarization
ticket is stapled, so it opens with no warning even on a Mac that is offline.

## Known limits

- **It cannot sit next to the clock.** macOS places every third-party menu bar item
  to the left of the system cluster. Users can Cmd-drag to reorder among
  third-party icons; nothing can move right of the system ones.
- Developer ID certificates are limited per team and revoking one invalidates
  every app already signed with it. Create one, keep it, do not churn it.
