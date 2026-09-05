# Privacy Policy — ScreenTimeNext

**Status: DRAFT.** Written before the first build so that App Store Connect and the Family
Controls entitlement request have a policy URL to point at. Task 018 audits the shipped code
against this document and finalizes it; until then, treat every statement below as a commitment
the code must be checked against, not a description of code that exists.

_Last updated: 2026-09-04_

## What ScreenTimeNext is
ScreenTimeNext is a parental control app for iOS and iPadOS. A parent sets a daily screen-time
budget for one child on the child's device, chooses which apps, categories and web domains it
applies to, and the app warns the child before the budget ends, lets the child choose a next
activity, and shields the selected content when the budget is exhausted.

## What we collect
- **The child's first name**, entered by the parent, stored only on the device, used only to
  address the child in the app.
- **The parent's configuration**: daily budget, warning settings, chosen activities. Stored only
  on the device.
- **The parent's content selection**, as Apple's privacy-preserving `FamilyActivitySelection`.
  Stored only on the device. We never convert it to app names, never log it, and never transmit it.
- **Enforcement state** (whether content is currently shielded, and any active extension
  granted by the parent). Stored only on the device.

## What we do not collect
- No account, sign-in, email address or phone number.
- No usage history, browsing history, location, contacts, messages, photos or screenshots.
- No analytics, crash reporting or advertising SDKs.
- Nothing is sent to any server. ScreenTimeNext has no backend.

## Where data lives
All data is stored in an App Group container on the device, shared only between the ScreenTimeNext
app and its Device Activity Monitor extension so that enforcement works when the app is not open.
Deleting the app deletes the data.

## Apple Screen Time frameworks
ScreenTimeNext uses Apple's Family Controls, Device Activity and Managed Settings frameworks.
Authorization is requested on the child's device and can be revoked at any time in
Settings › Screen Time. Managed Settings changes are limited to a store owned by ScreenTimeNext;
we never alter Screen Time settings made by Apple or by other apps.

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
