# Validation and release evidence

## Reload regression

ReloadUIFix.xcresult: all 10 tests passed (7 model tests and 3 UI tests) on iPhone 15 Pro / iOS 17.5. Regressions cover repeated pull-to-refresh, retained content on cancelled refresh, CancellationError cleanup, and stale-response isolation. ReloadFix.xcresult measured unit-only app coverage at 91.41%, passing the greater-than-80% gate. Core production code was unchanged.

## Coverage

Local Swift package run: 5 XCTest methods passed, zero failures. DynamicUICore Engine.swift: 84/84 executable lines, 100% line coverage using llvm-cov. Reproduce with `bash scripts/check-coverage.sh`.

Unit-only Simulator run: 3 model tests passed. Forma.app: 381/417 executable lines, 91.37% coverage. UI tests excluded via `-only-testing:FormaTests`. Hosted tests launch the app; this metric includes view construction during launch. Enforce using `bash scripts/check-app-coverage.sh UnitValidation.xcresult`. Core and app have separate denominators; generated code and test sources are excluded.

App-model tests cover scenario loading, action outcomes, source failure, and unknown required components. Both UI tests passed in FinalValidation.xcresult: size selection, purchase validation, materials navigation, and sold-out notification simulation. The iOS 17 Menu test uses a coordinate tap after its AX scroll-to-visible action failed despite a visible control. Manual VoiceOver verification remains required.

## Manual acceptance

- Review standard, sale, and sold-out compositions on small and large iPhones and iPad.
- Verify light/dark mode and largest Dynamic Type sizes without clipped actions.
- Test VoiceOver order, selected sizes, alert announcements, sheet entry/exit focus, and icon labels.
- Run Accessibility Inspector and document any findings.
- Confirm price/stock handling with real backend integration before any production use.

## Demo capture

Record standard product, size selection, add-to-bag feedback, details sheet, sale composition, then sold-out notification. Explain that all commerce operations are simulated. Record a separate accessibility walkthrough after manual verification.

`walkthrough.mp4` is a compressed automated Simulator recording covering the tested standard purchase/details flow and sold-out composition. It is test evidence, not an edited promotional video; the sale composition and accessibility walkthrough still need a separate recording. `pdp.png` was captured and visually inspected on iPhone 15 Pro / iOS 17.5.

```bash
xcrun simctl io booted recordVideo docs/demo.mp4
# Perform the walkthrough, then press Ctrl-C to finalize.
xcrun simctl io booted screenshot docs/pdp.png
```

## GitHub readiness

Public destination: https://github.com/PranithMargam/DynamicUI. The project is published at the repository root with screenshots and a recorded demo. Parent workspace files, build artifacts, and local xcresult bundles are excluded. An open-source license has not been selected. The manual acceptance checks above remain release requirements.
