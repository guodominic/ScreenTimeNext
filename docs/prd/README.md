# PRD — Transition V1

Source of record: `docs/reference/Screen_Time_Transition_Assistant_V1_PRD_Technical_Specification.docx`
(Working product name: **Transition** · Version 1.0 · September 2026)

This directory is the machine-readable split of that document. **Read these files, not the .docx.**
If the .docx is revised, re-split it here and note the change in `docs/DECISIONS.md`.

| File | PRD sections | Read it when |
|---|---|---|
| [01-vision-and-goals.md](01-vision-and-goals.md) | Purpose, §1–§4, §21 | Deciding whether something is in V1 scope |
| [02-user-journey.md](02-user-journey.md) | §5 | Wiring navigation and end-to-end flow |
| [03-screen-specs.md](03-screen-specs.md) | §6.1–§6.16 | Building any screen (copy, defaults, controls) |
| [04-ux-principles.md](04-ux-principles.md) | §7 | Writing user-facing copy or child UI |
| [05-architecture.md](05-architecture.md) | §8–§11 | Any structural or state-machine decision |
| [06-data-model.md](06-data-model.md) | §12–§13 | Defining models or persistence |
| [07-enforcement.md](07-enforcement.md) | §14–§15 | DeviceActivity, shielding, parent extension |
| [08-privacy-security-appstore.md](08-privacy-security-appstore.md) | §16–§18 | Logging, entitlements, submission |
| [09-qa-and-done.md](09-qa-and-done.md) | §19, §22 | Defining or checking acceptance |
| [10-appendices.md](10-appendices.md) | Appendix A, B | Folder layout, agent operating rules |

## The one-line version
Transition is **not another countdown timer**. It helps a child move from screen time to the
next real-world activity with less conflict, and it enforces the end of screen time through
Apple's Screen Time frameworks. A polished timer without real enforcement is a prototype, not V1.
