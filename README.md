# BudgetFlow

An in-development iOS budgeting app for tracking job income, recurring expenses and savings goals. The interface includes weekly and monthly summaries, cash-flow charts, currency selection and optional work-hours limits.

**Personal project by Albin Binoy · AI-assisted development · v1.10 / build 10**

[Portfolio](https://albinoy.github.io/Albin-Binoy-Interactive-CV/) · [Try the interactive web demo](https://albinoy.github.io/Albin-Binoy-Interactive-CV/budgetflow/)

## Try it without Xcode

The [browser demonstration](https://albinoy.github.io/Albin-Binoy-Interactive-CV/budgetflow/) lets you edit fictional income and recurring expenses, switch between weekly and monthly summaries, and update sample savings goals. No installation or sign-in is needed.

This is a separate, AI-assisted web implementation of selected workflows, not the native iOS app or a browser port of its Swift code. Edits are stored in your browser where available. It does not connect to banks or implement Core Data, CloudKit or target-date planning. Its consistent annual-average calculations do not mean the known native calculation issue below has been fixed. Use fictional data only.

## My contribution

My work on BudgetFlow focuses on product direction: defining the budgeting workflow, requesting features, reviewing iterations and deciding what to improve next. Implementation and code changes were produced with AI assistance. This repository documents that process and the resulting app; it is not a claim that I independently authored the Swift code.

Examples of the requirements I directed include named savings goals, weekly/monthly dashboard views, monthly cash-flow visualisation with scroll-triggered animation, and exploring private iCloud sync.

## Features in the codebase

- Add, edit and delete jobs with weekly hours and hourly pay.
- Manage recurring weekly, monthly and yearly expenses; include or exclude them from totals.
- Create named savings goals, set optional target dates and update savings.
- Choose a display currency and a weekly or monthly primary dashboard view.
- View income-by-job, estimated cash flow and savings-planning visualisations.
- Complete or skip first-launch setup, share a text summary and reset app data with confirmation.
- Use Core Data for local persistence, with CloudKit-backed storage configuration and local fallback handling.
- Use Liquid Glass styling on iOS 26 and later, with older-system fallbacks.

Charts are estimates derived from recurring entries and savings targets, not a transaction history or a record of actual daily bank balances. Changing the display currency does not convert stored amounts using exchange rates.

## Technology

Swift, SwiftUI, Core Data, NSPersistentCloudKitContainer and UIKit sharing. The deployment target is iOS 15.0; the source requires Xcode 26 or later to compile its availability-guarded Liquid Glass APIs.

The current implementation keeps views, managed-object subclasses, persistence setup and calculation helpers in `BudgetFlowApp/BudgetFlowApp.swift`. The compiled Core Data schema lives in `BudgetFlow.xcdatamodeld`.

## Run locally

1. Clone this repository and open `BudgetFlowApp.xcodeproj` in Xcode 26 or later.
2. Select the `BudgetFlow` scheme and a compatible simulator. No personal database is included.
3. For a physical device or iCloud testing, select your own Apple Developer team, change the bundle/container identifiers as needed and configure the matching capabilities and profiles. The identifiers in the project are configuration values, not credentials or permission to use an Apple container.
4. Replace the privacy-policy and support placeholders before distributing the app.

To build without signing:

```sh
xcodebuild -project BudgetFlowApp.xcodeproj \
  -scheme BudgetFlow -configuration Debug \
  -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' \
  CODE_SIGNING_ALLOWED=NO build
```

## Validation and known limitations

On 16 November 2026, the saved v1.10 source passed an unsigned Debug build for a generic iOS Simulator destination using Xcode 27.2. This published copy replaces the support email with a placeholder; it otherwise preserves that app implementation. Runtime testing was blocked by a CoreSimulator service version mismatch. The app is not presented as released or App Store-ready.

Current improvement priorities:

- **Consistent period calculations:** expense conversion currently assumes four weeks per month, while income and the cash-flow chart use 52/12. For example, a 1,200 monthly expense appears as 1,200 in the dashboard but totals 1,300 in the chart.
- **Reliable persistence feedback:** some editors dismiss after an unsuccessful save, and some fallback paths do not check whether local storage loaded successfully.
- **Accurate sync status:** Settings reflects the sync configuration flag rather than the storage mode actually selected at startup.
- **Multi-device reconciliation:** deterministic handling of duplicate settings records needs testing and improvement.
- **Input and arithmetic bounds:** finite-number parsing exists, but extreme finite amounts can still overflow calculations.
- **Export clarity:** excluded expenses should be identified explicitly in the shared summary.

Device/simulator flows, migration from prior stores, offline/two-device CloudKit sync, accessibility, signing and archive validation remain unverified. No automated test suite is included yet. Previous SwiftData stores are not automatically imported into this Core Data version.

## Repository contents

```text
BudgetFlowApp/                 App source, assets, Core Data model and entitlements
BudgetFlowApp.xcodeproj/       Xcode project
README.md                     Project scope, setup and current limitations
.gitignore                    Excludes local Xcode state, build output and data stores
```

No user financial data, provisioning profiles, signing certificates or build outputs are included. This is a budgeting experiment, not financial advice.
