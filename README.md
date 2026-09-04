# Transition

**Screen Time Transition Assistant + Parental Control** · iOS / iPadOS

> Make screen time end peacefully.

## What it does
Transition helps parents set a screen-time budget, select protected content, warn a child before
time expires, guide the child toward a next activity, and enforce the end of selected screen time
using Apple's Screen Time frameworks.

It is not another countdown timer. The product thesis is that a child who **chooses what happens
next** transitions with less conflict — and that enforcement has to be real for a parent to trust it.

## V1 scope
- Family Controls authorization
- `FamilyActivityPicker` content selection
- Daily budget (default 60 min)
- 10 / 5 / 1-minute transition warnings
- Child-selected next activity
- DeviceActivity monitoring
- ManagedSettings shielding
- Parent temporary extension (+10 / +20 / Allow Once)
- Local persistence via App Group
- **No backend**

Out of scope in V1: multi-child, cross-device, cloud accounts, Android, AI recommendations, social
features, ads, complex scheduling, subscriptions. See `docs/prd/01-vision-and-goals.md` §4.

## Repository layout

```text
CLAUDE.md                 agent instructions + workflow — read first
docs/
├── prd/                  the PRD as readable markdown (READ THIS)
├── architecture.md       condensed architecture reference
├── tasks/
│   ├── PROGRESS.md       project status — read first, update last
│   └── 001…020-*.md      the 20 implementation tasks, in order
├── DECISIONS.md          why things are the way they are
├── BLOCKERS.md           what code cannot fix
└── reference/            the signed .docx PRD, archived
Transition/               app source (see Transition/README.md)
Tests/                    unit tests
```

## Getting started
1. Read `CLAUDE.md`.
2. Read `docs/tasks/PROGRESS.md` to see where the project stands.
3. Check `docs/BLOCKERS.md` before starting anything entitlement-dependent.
4. Open the next task file and implement **only** that task.
5. Build and test, then fill in the task's completion report and update `PROGRESS.md`.

## Definition of Done
V1 is complete only when the app provides a coherent transition experience **and** reliably enforces
the configured limit through Apple's Screen Time APIs, with the app closed.

A polished timer without actual enforcement is a prototype, not the V1 product.

## Important platform note
Family Controls distribution requires the appropriate Apple entitlement and approval. This is
**calendar time, not engineering time** — request it as early as possible and track it in
`docs/BLOCKERS.md` (B-001). Verify current Apple documentation and installed SDK behavior before
implementation or App Store submission.
