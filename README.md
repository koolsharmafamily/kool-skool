# Kool Skool

An iOS app for adults with ADHD who need help **starting**, **feeling time pass**, and **not collapsing after a missed day**.

- SwiftUI, iOS 17.0+, iPhone only
- SwiftData, local-only in v1, written to be sync-ready
- MVVM: SwiftUI views, `@Observable` view models, plain Swift services
- Swift Concurrency throughout, no Combine
- No third-party dependencies

---

## Status

**Milestone 1 complete — project skeleton, design system, data model, repository layer.**

There is no feature code yet. `RootView` is a placeholder that proves the stack boots and links to a design system gallery.

Remaining milestones, in order: focus engine → tasks → rewards → time blindness → body doubling → check-ins and insights → stillness → Live Activities and widgets → onboarding and settings → accessibility pass.

---

## Building

Requires **Xcode 16 or newer**. Open `KoolSkool.xcodeproj` and run.

Set your own team under Signing & Capabilities before running on a device. `PRODUCT_BUNDLE_IDENTIFIER` is `com.koolskool.app`; change it if that clashes with something you already own.

The project uses Xcode 16 file-system-synchronized groups, so **new files are picked up automatically** from the `KoolSkool/` and `KoolSkoolTests/` folders. There is no file list in the project to keep in step.

---

## Layout

```
KoolSkool/
├── App/            Composition root, root view, the view-model pattern
├── DesignSystem/   Colour, type, spacing, haptics, animation, components
├── Domain/         Pure Sendable value types. No SwiftData, no SwiftUI.
│   ├── Core/       Clock, sync metadata, session modes, shared enums
│   ├── Entities/   The eleven entities, as structs
│   └── Repositories/  Protocols the whole app talks to
├── Persistence/    The only place SwiftData is imported
│   ├── Models/     @Model classes plus their mapping to and from Domain
│   └── SwiftData/  The store actor and its repository conformances
└── Preview/        Preview helpers, the unavailable-store provider, the gallery
```

The dependency rule is one-way: `App` and future feature folders depend on `Domain`. `Persistence` depends on `Domain`. **Nothing depends on `Persistence`** except the composition root, which picks an implementation.

---

## Architecture decisions

### Repositories speak in value types, not SwiftData objects

Repository protocols take and return the `Sendable` structs in `Domain/Entities`. `@Model` classes never leave `Persistence/`.

This is what makes "sync-ready" real rather than aspirational. It also means no `@Query` in views — view models own state and call repositories, which is what MVVM asks for anyway.

The cost is a mapping layer. It lives next to each model so the two cannot drift.

### One store actor, not one per repository

`KoolSkoolStore` is a single `@ModelActor` conforming to all nine repository protocols, split across `KoolSkoolStore+*.swift`. One `ModelContext` means a write through `TaskRepository` is immediately visible to a read through `SessionRepository`.

### Sync-ready schema rules

Every entity has `id`, `createdAt`, `updatedAt`, `deletedAt`. Nothing is ever hard-deleted.

Every `SD*` model additionally follows CloudKit's constraints even though v1 opts out of CloudKit: **no unique constraints, every property defaulted, every relationship optional**. Turning sync on later should be configuration, not migration.

Associations are plain `UUID` foreign keys. The one real SwiftData relationship is task → steps, which is a true composition.

Enums are stored as raw strings with a computed accessor, because SwiftData predicates against strings are reliable and predicates against stored enums are not.

### Everything reads the clock through `DateProvider`

No `Date()` in logic. Streaks, musts, reflections, and the session timer all take an injected clock, which is the only way the DST and timezone cases are testable. `MutableDateProvider` moves time by hand in tests.

### Timer correctness

`FocusSession` stores `startedAt` and `plannedDuration` and computes elapsed time from wall-clock. Nothing decrements. This is what makes a session survive backgrounding, force quit, and restart — and `SessionRepository.activeSession()` is the recovery path.

Milestone 2 builds the engine on top of this. The maths is already under test.

---

## Deviations from the spec

Four renames and one addition, all noted here so they are not a surprise:

| Spec | Built as | Why |
|---|---|---|
| `Task` | `FocusTask` | `Task` is Swift Concurrency's type. Shadowing it breaks every `Task { }` in the module. |
| `Settings` | `AppSettings` | Collides with SwiftUI's `Settings` scene. |
| `ReflectionEntry` | `Reflection` | Cosmetic. |
| `isMustToday: Bool` | `mustForDate: Date?` | A bare flag never resets. Storing the day is what makes the rule of three clear itself each morning. |
| — | `Practice.attribution` | Carries the source for any verbatim public-domain text, per the hard content rule. |

One behavioural judgement call worth a look: **completing a must frees a slot**, so the cap counts open musts rather than all musts. You never face more than three at once, but finishing one lets you pick another. Say the word if you want the stricter reading.

---

## Testing

`KoolSkoolTests` uses Swift Testing. Milestone 1 covers:

- **XP and levels** — curve is monotonic, `level(forXP:)` inverts `xpRequired(forLevel:)`, progress stays in `0...1`
- **Session modes** — every mode's timings, Flowmodoro's divide-by-five with its clamps
- **Session maths** — elapsed time is wall-clock and survives a killed app, progress clamps on overrun
- **Day arithmetic** — spring forward, fall back, midnight rollover, timezone shift
- **Repositories** — round-trips, soft delete cascade, the rule-of-three cap, singleton rows, reseeding without losing unlocks

Streak logic and the freeze rules get their tests in Milestone 4, when they exist.

---

## Not in v1

App blocking, accounts, cloud sync, multiplayer rooms, AI task breakdown, any network call, social features, Watch/iPad/Mac, IAP, HealthKit, streamed practice content.

**Content rule, permanent:** nothing is ever generated or paraphrased in the voice of a named real person, and no voice or likeness is synthesised. Quotes from real teachers appear only verbatim, correctly attributed, and public domain or explicitly licensed. Everything else is the app's own words.

Kool Skool is not a medical device and gives no medical advice. The medication log is a log.
