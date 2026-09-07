# Privacy Policy — ScreenTimeNext

**Status: audited 2026-09-07.** `scripts/privacy-audit.sh` runs on every test run and fails the
build if networking, logging, third-party SDKs, raw selection access or a global Managed Settings
clear ever appear. The Family Controls, Device Activity and Managed Settings adapters described
below now exist and are covered by that audit.

_Last updated: 2026-09-07_

## What ScreenTimeNext is
ScreenTimeNext is a parental control app for iOS and iPadOS. A parent sets a daily screen-time
budget for one child on the child's device, chooses which apps, categories and web domains it
applies to, and the app warns the child before the budget ends, lets the child choose a next
activity, and shields the selected content when the budget is exhausted.

## What we collect
- **The child's first name**, entered by the parent, stored only on the device, used only to
  address the child in the app.
- **The parent's configuration**: the budget, the reminder times, the list of next activities
  (including any the parent wrote themselves), and any web domains they typed in. Stored only on
  the device.
- **The parent's PIN**, stored on the device as a salted hash — never the digits themselves. If the
  parent turns on the Face ID shortcut, that check is performed by iOS; the app is told only
  whether it succeeded and never sees any biometric data.
- **The parent's content selection**, as Apple's privacy-preserving `FamilyActivitySelection`.
  Stored only on the device. We never convert it to app names, never log it, and never transmit it.
- **Enforcement state** (whether content is currently shielded, and any minutes the parent has
  added). Stored only on the device.
- **A short technical log** of what the background extensions did — a callback name, one of our own
  activity names, and a timestamp. It exists so a misbehaving transition screen can be diagnosed,
  it holds at most twenty lines, it never contains an app name or a web address, and a parent can
  read or clear it in Settings ▸ Enforcement log.

## What we do not collect
- No account, sign-in, email address or phone number.
- No usage history, browsing history, location, contacts, messages, photos or screenshots.
- No analytics, crash reporting or advertising SDKs.
- Nothing is sent to any server. ScreenTimeNext has no backend.

## Where data lives
All data is stored in an App Group container on the device, shared between ScreenTimeNext and its
four extensions — the Device Activity monitor, the two that draw and answer the transition screen,
and the Live Activity widget — so that everything keeps working when the app is not open. Nothing
is stored anywhere else. Deleting the app deletes the data.

## Apple Screen Time frameworks
ScreenTimeNext uses Apple's Family Controls, Device Activity and Managed Settings frameworks.
Authorization is requested on the child's device and can be revoked at any time in
Settings › Screen Time. Managed Settings changes are limited to a store owned by ScreenTimeNext, and
only ever to the four shield keys we set by name; we never call `clearAllSettings()`, so Screen Time
settings made by Apple or by another parental-control app are never altered or erased.

The screens a child sees when content is shielded are drawn in Apple's own shield extensions. Those
extensions are told which app or website was opened as an opaque token. We never read it, store it
or log it: what the screen says depends on the clock, not on which app it was.

## Children's privacy
ScreenTimeNext is configured by a parent and used on a child's device. The only child information
it holds is a first name, on the device. We do not knowingly collect personal information from
children, and nothing in the app is directed at collecting it.

## What we cannot promise
Apple's platform, not ScreenTimeNext, decides what a child can and cannot bypass. We do not claim
to block every possible workaround.

## Contact
Questions about this policy: open an issue at https://github.com/guodominic/ScreenTimeNext
or email guoxiachen@gmail.com.
