# Kool Skool

An iOS app for adults with ADHD who need help **starting**, **feeling time pass**, and **not collapsing after a missed day**.

- SwiftUI, iOS 17.0+, iPhone only
- SwiftData, local-only in v1, written to be sync-ready
- MVVM: SwiftUI views, `@Observable` view models, plain Swift services
- Swift Concurrency throughout, no Combine
- No third-party dependencies

---

## Status

**Milestone 4 complete — XP, coins, streaks with freezes, the celebration moment, the collection.**

The full loop runs: dump what's in your head, pin up to three for today, break one into steps, start a session, get paid for it, and watch a streak build that forgives two missed days a month without being asked.

Remaining milestones, in order: time blindness → body doubling → check-ins and insights → stillness → Live Activities and widgets → onboarding and settings → accessibility pass.

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
├── Features/
│   ├── Focus/      The session engine, its pure decision logic, and its screens
│   ├── Rewards/    XP, coins, streaks, the celebration, the collection
│   └── Tasks/      Today, the task list, the step splitter, mode suggestion
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

**Nothing counts down.** The only durable facts are `startedAt` and `plannedDuration`, both written to the store before the first frame renders. Everything on screen is recomputed from those against the wall clock, so a missed tick, a killed app, or a rebooted device cannot make the timer wrong — there is no accumulated state to lose.

`SessionSnapshot` does that derivation and holds no state. `FocusEngine` owns the running session; its tick loop only refreshes the display and notices the planned end, and `tick()` is callable directly so tests drive time by hand instead of sleeping.

What happens when the app was not watching:

| Case | Behaviour |
|---|---|
| Relaunched mid-session | Picked up from the store and keeps running, elapsed time correct |
| Count-down end passed while away | Credited, dated at the **planned end** — not at whenever the app came back |
| Count-up left running past 4h | Closed at its last heartbeat, recorded but **not** credited |
| Device clock dragged backwards | Elapsed clamps at zero; the session keeps running |
| DST change or timezone change mid-session | No effect — elapsed is absolute-time arithmetic |

A running session writes a heartbeat every 30 seconds and on backgrounding. It exists only for Flowmodoro, which has no planned end: without it, a phone that dies twenty minutes in and gets charged overnight would read as four hours of deep work.

### Streaks are recomputed, never incremented

`StreakCalculator.evaluate` walks the session history backwards from today and returns the streak, the record, and which days a freeze covered. Nothing about the streak or the freeze budget is stored as a running total, so a missed update, a restore from backup, or a clock that jumped cannot leave a wrong number stuck in the store. It is idempotent and self-healing by construction.

Freezes fall out of the same walk — two per calendar month, applied to the missed day's month, entirely retroactively. Two rules that took some thought:

- **Today is never held against you.** A day with no session yet is neither counted nor treated as a break; the day isn't over.
- **Freezes spent on a streak that broke anyway are handed back.** Walking back over four missed days with two freezes ends the streak, so those two freezes were never load-bearing and are not charged.

The copy is "Fresh start", never "you lost 47 days" — `UserProgress.streakLabel` is the single place that decides.

### The reward economy

`RewardCalculator.reward(for:rolls:)` is pure: the same session and the same three random draws always produce the same reward. The randomness is taken at the edge and injected, which is what makes the one-in-five chest testable.

The base XP and coins **always land**. The chest can only ever add — and if a cosmetic chest opens when there is nothing left to give, it pays out in coins instead rather than opening onto nothing.

| | |
|---|---|
| XP | 2/minute, floor of 10, times 1.0–1.6 for resistance |
| Coins | one per five minutes, floor of 1 |
| Chest | 1 in 5 completed sessions; coins ×2/×3, or a cosmetic |
| Unfinished session | pays nothing — not a penalty, just nothing to pay out for |

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
| — | `FocusSession.lastHeartbeatAt` | Added in M2. Bounds a Flowmodoro session the app stopped watching. |
| — | `FocusSession.endReason` | Added in M2. "How do my sessions actually end" is what Insights will want. |

### Judgement calls

All reversible, all worth your veto.

**Focus (M2)**

1. **Ending early past 80% still counts as completed.** Twenty-four of twenty-five minutes is a finished Pomodoro, and calling it a failure is the shame mechanic the spec rules out. `FocusRules.completionThreshold`.
2. **Just Start asks nothing.** The home button starts a five-minute session immediately — no mode, no intent, no resistance rating. The ritual is behind "Choose a mode". Every question is another chance to bounce.
3. **"Keep going" writes two sessions, not one long one.** The five minutes are credited on their own, then a fresh Pomodoro starts carrying the same intent.
4. **Sessions under 10 seconds are discarded.** A mis-tap should not leave litter in the history.

**Tasks (M3)**

5. **Completing a must frees a slot.** The cap counts open musts, not all musts. You never face more than three at once, but finishing one lets you pick another.
6. **A brain dump splits on newlines.** One line becomes one task. A dump is a list by nature, and merging them only creates sorting work later.
7. **Today shows one empty slot, not three.** Three dashed boxes on a fresh install reads as three chores rather than an invitation.
8. **High-resistance tasks open on Just Start.** A task rated 4 or 5 overrides the default mode, and the setup screen says why in plain words rather than deciding quietly. `TaskSuggestion`.
9. **The "no first step yet" nudge is selective.** Only tasks with a long estimate or three-plus steps get it. Asking "what is the smallest first step?" about *buy milk* is noise, and noise is why people stop reading prompts.
10. **The task editor saves on leaving the screen and on field commit, not per keystroke.** Edits abandoned by a force quit mid-typing are lost. Acceptable for v1; say if not.

**Rewards (M4)**

11. **Freezes spent on a streak that broke anyway are refunded.** They kept nothing alive, so charging for them would be a quiet penalty.
12. **The freeze note only appears when a freeze was actually used.** Nobody needs telling about a safety net they are not standing on.
13. **A cosmetic chest with nothing left to give pays coins instead.** A chest that opens onto nothing is worse than no chest.
14. **The Collection is honest about what equipping does today.** Companions and soundscapes don't exist until Milestone 6, and the screen says so rather than selling something that isn't there. If you'd rather the whole screen waited until those features land, it's one route to delete.
15. **Sound is missing from the celebration.** The spec asks for confetti, haptics, sound, and a count-up; there's no audio stack until Milestone 6, so the other three ship now and sound joins them there.

---

## Testing

`KoolSkoolTests` uses Swift Testing. Every time-dependent test moves a `MutableDateProvider` by hand — nothing sleeps.

- **XP and levels** — curve is monotonic, `level(forXP:)` inverts `xpRequired(forLevel:)`, progress stays in `0...1`
- **Session modes** — every mode's timings, Flowmodoro's divide-by-five with its clamps
- **Session maths** — elapsed is wall-clock, clamps on overrun and on a backwards clock
- **Snapshot** — formatting past an hour, VoiceOver phrasing that does not re-announce every second
- **Focus engine** — persists before the first tick; finishes at the planned instant not the tick instant; force quit; end-passed-while-away; the Flowmodoro cap; keep-going; DST mid-session; timezone change mid-session; clock dragged backwards
- **Today** — brain dump splitting, the rule-of-three cap as a notice rather than an error, finishing a must freeing a slot, musts not leaking across days, next-step driving the label
- **Task list and detail** — sectioning, pin toggling, step lifecycle, templates, draft saving
- **Mode suggestion** — high-resistance override and its explanation, nudge selectivity
- **Streaks** — freezes applied retroactively, the per-month budget, wasted freezes refunded, today never held against you, idempotence, DST in both directions, a bounded walk over 800 days
- **Rewards** — the XP curve and resistance multiplier, the base always landing whatever the chest does, chest frequency landing on 1-in-5, level-up unlocks, purchases, the cosmetic-chest fallback
- **Day arithmetic** — spring forward, fall back, midnight rollover, timezone shift
- **Repositories** — round-trips, soft delete cascade, the rule-of-three cap, singleton rows, reseeding without losing unlocks

Streak and freeze logic get their tests in Milestone 4, when they exist.

## Deferred seams

Written as protocols now, implemented later, so nothing has to be retrofitted:

- `SessionAlertScheduling` — the local-notification backstop. No-op until Milestone 9, where the permission prompt belongs. The engine's schedule-on-start and cancel-on-early-end paths are already written and tested.
- Live Activities and Dynamic Island — Milestone 9.
- The depleting **disc**, the full-screen ambient colour migration, time-check pulses, and making the digits secondary and toggleable — Milestone 5. Milestone 2 ships a correct ring that drains and already interpolates its stroke colour toward the overrun accent.
- The commitment card — Milestone 6. `FocusSession.commitment` and `SessionPlan.commitment` exist and are persisted.
- AI-assisted task breakdown — not in v1 and not stubbed. The offline template row in the step editor is the shape it would slot into if it ever ships.
- XP, coins, streaks, the celebration moment, and the post-session energy check-in — Milestones 4 and 7. The completion screen leaves that space empty rather than filling it with a placeholder.

There is no pause. The spec never asks for one, so it was not invented.

---

## Not in v1

App blocking, accounts, cloud sync, multiplayer rooms, AI task breakdown, any network call, social features, Watch/iPad/Mac, IAP, HealthKit, streamed practice content.

**Content rule, permanent:** nothing is ever generated or paraphrased in the voice of a named real person, and no voice or likeness is synthesised. Quotes from real teachers appear only verbatim, correctly attributed, and public domain or explicitly licensed. Everything else is the app's own words.

Kool Skool is not a medical device and gives no medical advice. The medication log is a log.
