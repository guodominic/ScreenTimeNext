# 01 — Vision, Goals & Validation

PRD sections: Document Purpose, §1 Executive Summary, §2 Vision & Positioning, §3 V1 Goals,
§4 V1 Non-Goals, §21 Product Validation.

## Document purpose
Defines the V1 product requirements, user experience, system architecture, data model,
Apple Screen Time API integration, testing strategy, and implementation plan for **ScreenTimeNext** —
a child screen-time transition assistant combined with parental control enforcement.

## §1 Executive summary
ScreenTimeNext is not intended to be another countdown timer. Its core promise is to help a child
move from screen time to the next real-world activity with less conflict. V1 combines a gentle
transition experience with Apple's FamilyControls, DeviceActivity, and ManagedSettings so the
product can both **prepare** the child and **enforce** the end of selected screen time.

> Core product statement: **"Make screen time end peacefully."**

## §2 Vision & positioning
- **Category:** Screen Time Transition Assistant + Parental Control
- **Primary audience:** Parents of children approximately 5–12 years old
- **Core problem:** Children struggle to stop highly stimulating digital activities, creating
  repeated negotiation and parent-child conflict.
- **Differentiator:** Focus on the transition from "screen" to "what's next", not only restriction.
- **Product principle:** Should feel like a supportive guide, not a punishment system.

## §3 V1 goals
1. Parent can authorize the app for Screen Time management.
2. Parent can select apps/categories/web domains using Apple's `FamilyActivityPicker`.
3. Parent can configure a daily screen-time budget.
4. Provide 10-, 5-, and 1-minute transition warnings.
5. Child can choose a next activity.
6. Enforce the end of screen time through ManagedSettings shielding.
7. Provide a parent-controlled temporary extension flow.
8. Persist configuration and protection state locally.
9. Collect **no** child usage data on a backend in V1.

## §4 V1 non-goals
Anything in this list is **out of scope** — do not build it, do not design around it:

- Multi-child family management
- Cross-device remote management
- Cloud account / login system
- Android support
- AI recommendations
- Social features
- Advertising
- Complex school/bedtime scheduling
- Subscription infrastructure before product-market validation

## §21 Product validation
The business hypothesis is **not** that parents want another timer. It is that parents will value
a product that reduces conflict at the moment screen time ends. Validation should measure
willingness to pay and observed behavioral improvement, not downloads.

Open validation questions:
- Would parents pay approximately **$30/year** for a calmer screen-time ending experience?
- Do children actually transition more easily when they choose the next activity?
- Does advance warning reduce parent-child negotiation?
- Do parents perceive the enforcement as reliable enough to trust?
