# Interview discussion guide

## A two-minute walkthrough

"FORMA renders a native PDP from a versioned JSON contract. A typed registry owns decoding and view construction for each component. The engine resolves component names and versions without a component-specific switch. Three fixtures change ordering, offers, available sizes, and the primary action. Application state stays local and side effects go through an allowlisted action registry. I measured core unit coverage separately from UI coverage and documented the remaining backend and accessibility validation."

## Why SDUI?

Merchandising can reorder supported blocks and activate compositions without a binary release. New component capabilities still need a client release. This adds schema governance, compatibility testing, operational monitoring, and debugging costs; a static PDP may be simpler when composition rarely changes.

## Is this actually server-driven without a server?

The renderer consumes a server-compatible JSON contract behind ScreenSource. The reference app supplies fixtures. Remote content delivery is an integration point, not a completed backend. Describe it as an SDUI client demonstration.

## Why two registries?

Components describe presentation. Actions describe supported intent. Separate registries avoid embedding arbitrary side effects inside the decoding engine and allow service dependencies to change independently.

## How does forward compatibility work?

Resolve the exact component version; skip unknown optional nodes, fail unknown required nodes. Deploy supporting clients before emitting required new capabilities. A production backend should negotiate a client capability manifest or use minimum-supported-version rules.

## What happens when requests race?

The MainActor serializes UI mutation, but async calls can interleave. A generation counter rejects stale responses after suspension; cancellation prevents work from applying when its SwiftUI task is replaced. MainActor alone is not enough to solve stale results.

## What does 80% mean?

Executable line coverage in a named production module. It is not branch, requirement, accessibility, or security coverage. The core gate excludes UI presentation and generated code explicitly. Use failure tests and integration tests alongside the percentage.

## How would this scale?

Split component factories into feature registration modules, negotiate capabilities, validate server contracts, add revision diagnostics, and profile heterogeneous rendering. Avoid storing mutable application state in opaque JSON. Registry access can remain immutable after app composition.

## What would you improve next?

Move view-factory composition out of ProductModel as the component library grows. Add a validated screen representation before view creation, richer semantic props validation, injectable business action services, localization keys and currency values, remote transport/caching, and stale-result tests using a controllable source. Do not claim these are already implemented.

## Accessibility discussion

Native text uses semantic font sizes. Variant buttons expose selected traits. Icons have labels, decorative symbols are hidden, and the size grid adapts. Verify largest accessibility sizes, VoiceOver order, sheet focus, contrast, and iPad layouts on devices. Automated tests cannot certify the full experience.
