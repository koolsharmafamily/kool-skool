# Kool Skool

An iOS app for adults with ADHD who need help **starting**, **feeling time pass**, and **not collapsing after a missed day**.

- SwiftUI, iOS 17.0+, iPhone only
- SwiftData, local-only in v1, written to be sync-ready
- MVVM: SwiftUI views, `@Observable` view models, plain Swift services
- Swift Concurrency throughout, no Combine
- No third-party dependencies

---

## Status

**Milestone 9 complete — Live Activities, widgets, Siri and Shortcuts, and the session-end notification backstop.**

The full loop runs: dump what's in your head, pin up to three for today, break one into steps, say out loud what you're about to do, start a session with something working alongside you and a noise bed running, watch a disc drain while the background warms toward the deadline, glance at it on the Lock Screen without unlocking, get paid for it, take a breath practice on the break, and watch a streak build that forgives two missed days a month without being asked.

Remaining milestones, in order: onboarding and settings → accessibility pass.

### Widgets and the App Group — one switch for you to flip

The home screen and Lock Screen widgets read a small snapshot the app writes into the App Group `group.com.koolskool.app`. **The entitlement for that group is deliberately not set**, because a free Apple ID cannot sign an App Group, and adding it would stop the app installing on a device for anyone on a free account.

So as shipped, the widgets work as a one-tap **Just Start** launcher, and the Live Activity and Dynamic Island — which need no App Group — work fully. If you have a paid Developer Program account, add the **App Groups** capability with `group.com.koolskool.app` to both the `KoolSkool` and `KoolSkoolWidgetsExtension` targets, and the widgets start showing the streak, today's three, and the running timer. No code changes.

### Content in the stillness layer

**No line in the app is attributed to anybody, because nothing in it came from anybody.** Every practice script, every framing, and every closing line is written for this app and presented as the app's own words. `Practice.attribution` is nil across the whole bundled catalogue; it renders next to the passage wherever it is set, so verbatim public-domain or licensed text drops in later without touching a view. Three tests hold the line: attributions are nil, no script contains quotation marks or attributive verbs, and no framing does either.

**There is no recorded audio.** The spec asks for bundled local audio and text scripts. The scripts are here and `audioAssetName` is wired through, but nothing is bundled: no recording exists, and synthesising a voice is off the table under the same rule. So guidance is text cues paced by the timer, plus a synthesised bell whose pitch changes with the framing. Real recordings are a sourcing problem before an engineering one — when they arrive, they set `audioAssetName` and the practice screen already knows what to do with it.

**The tradition selector changes vocabulary, the closing line, and the bell.** It never changes what a practice asks you to do, and the app is complete on the secular default. Each framing's picker line describes what changes *in the app*, not what the tradition teaches — the app is in no position to do the second.

### The audio tradeoff you should know about

The spec asks soundscapes to mix with other audio, respect the silent switch, **and** keep playing in the background. iOS gives you two of those. `.ambient` mixes and respects the switch but dies the moment the app leaves the foreground; `.playback` mixes and survives backgrounding but ignores the switch.

This ships `.playback` + `.mixWithOthers`, so **the silent switch does not stop a soundscape.** A focus timer whose bed cuts out when the screen locks is broken in a way people notice within one session, whereas the switch is usually flipped to stop notifications rather than deliberate media. The app's own off switch is on the session screen and in settings. Say if you'd rather have it the other way round — it's a one-line change in `SoundscapeEngine.activateSession()`.

Background audio also means the app now declares `UIBackgroundModes = audio`. That is visible to App Review and they will ask what it's for.

### Health-adjacent data

Check-ins, the medication log, and reflections conform to `HealthAdjacentRecord`. Today that is only a label — there is no sync and no analytics, ever. It exists so the future sync engine has exactly one thing to check: those records are **excluded by default** and including them takes its own consent, separate from syncing tasks and sessions. A test pins the list, so changing it is a deliberate privacy decision rather than an accident.

Nothing about medication appears anywhere until someone switches tracking on. The app has no drug database and knows nothing about any medication — the only facts it holds are the ones typed into it. The daily reminder's lock-screen text is "Your daily reminder.", and a test fails if a future edit makes it say otherwise.

---

## Building

Requires **Xcode 16 or newer**. Open `KoolSkool.xcodeproj` and run.

Set your own team under Signing & Capabilities before running on a device — on **both** the `KoolSkool` and `KoolSkoolWidgetsExtension` targets. The bundle identifiers are `com.koolskool.app` and `com.koolskool.app.widgets`; the extension's must stay prefixed by the app's, so change both together if they clash with something you already own.

Every push is compiled and tested on a macOS runner by `.github/workflows/build.yml`. The project is written on Windows, where the Apple SDKs do not exist, so that workflow is the only place the code meets a compiler.

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
│   ├── Tasks/      Today, the task list, the step splitter, mode suggestion
│   ├── TimeBlindness/  The disc, the ambient shift, estimate calibration
│   ├── CheckIns/   Check-ins, the medication log and its reminder
│   ├── Insights/   The calendar, the time-of-day chart, every observation sentence
│   ├── Surfaces/   Live Activity, widget publishing, notifications, Siri and Shortcuts
│   ├── Stillness/  The breath pacer, the practice library, breaks, reflection
│   └── BodyDoubling/   The companion, the audio stack, the commitment card
├── Domain/         Pure Sendable value types. No SwiftData, no SwiftUI.
│   ├── Core/       Clock, sync metadata, session modes, shared enums
│   ├── Entities/   The eleven entities, as structs
│   └── Repositories/  Protocols the whole app talks to
├── Persistence/    The only place SwiftData is imported
│   ├── Models/     @Model classes plus their mapping to and from Domain
│   └── SwiftData/  The store actor and its repository conformances
└── Preview/        Preview helpers, the unavailable-store provider, the gallery

KoolSkoolShared/    Compiled into the app and the widget extension. May reference nothing app-only.
KoolSkoolWidgets/   The widget extension: Live Activity, Dynamic Island, home and Lock Screen widgets
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

Four renames and some additions, all noted here so they are not a surprise:

| Spec | Built as | Why |
|---|---|---|
| `Task` | `FocusTask` | `Task` is Swift Concurrency's type. Shadowing it breaks every `Task { }` in the module. |
| `Settings` | `AppSettings` | Collides with SwiftUI's `Settings` scene. |
| `ReflectionEntry` | `Reflection` | Cosmetic. |
| `isMustToday: Bool` | `mustForDate: Date?` | A bare flag never resets. Storing the day is what makes the rule of three clear itself each morning. |
| — | `Practice.attribution` | Carries the source for any verbatim public-domain text, per the hard content rule. |
| — | `FocusSession.lastHeartbeatAt` | Added in M2. Bounds a Flowmodoro session the app stopped watching. |
| — | `FocusSession.endReason` | Added in M2. "How do my sessions actually end" is what Insights will want. |
| Bundled practice audio | Text cues paced by the timer | Added in M8. Nothing can be recorded here and a synthesised voice is forbidden by the same rule that forbids attributed guidance. `audioAssetName` is wired and unused. |

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
14. **The Collection is honest about what equipping does today.** Companion skins and soundscapes now do something; themes and timer styles still do not, and the screen says so rather than selling something that is not there.
15. **Sound was missing from the celebration** until Milestone 6 brought the audio stack. It plays now.

**Time blindness (M5)**

16. **The digits sit below the disc at 52pt, not 76pt.** The spec wants timers at 72pt+ *and* the digits secondary to the disc. Those pull against each other, so the disc leads at ~300pt and the digits stay large but clearly beneath it. Turning them off leaves a pure disc.
17. **A count-up disc fills through each minute instead of draining.** Flowmodoro has no end to drain toward. A still disc would look broken; a draining one would invent a deadline the mode exists to avoid.
18. **The ambient shift never warms during Flowmodoro.** Same reason — migrating toward the overrun colour would imply a finish line that isn't there.
19. **Time-check pulses are counted, not timed.** Returning from twenty minutes in the background fires one pulse, not three in a row. Three buzzes together is an alarm, not a time check.
20. **Calibration uses the median, not the mean.** One task estimated at fifteen minutes that became a four-hour rabbit hole would drag a mean far enough to make every suggestion useless.
21. **The app says nothing about your estimates until ten finished tasks.** Nine is a hunch. Inventing a pattern from it would be the app making things up about the user.
22. **Auto-padding stores the padded number, and the row says so.** Tap 30, record 48, with a note explaining why. The alternative — showing padded numbers on the buttons — makes the picker read as nonsense.

**Body doubling (M6)**

23. **The silent switch does not mute soundscapes.** See the tradeoff above. Reversible in one line.
24. **Three soundscapes are generated, two are honestly missing.** Brown, pink and rain are synthesised in `NoiseSource` — no assets, no audible loop point, nothing added to the bundle. Café and Library cannot be faked, so they report themselves unavailable and say why rather than shipping silence behind a name. Drop `soundscape-cafe.m4a` and `soundscape-library.m4a` into the bundle and they light up on their own.
25. **The companion is SF Symbols on a drawn desk, not artwork.** No assets, it takes the energy-state colour for free, and `symbolEffect` gives the milestone reactions without a sprite sheet. If you want a real illustrated character this is the seam to replace, and only `CompanionView` changes.
26. **It reacts four times a session and no more.** Quarter, half, three-quarters, nearly done. A companion that responds to everything is a pet demanding attention, which is the opposite of what body doubling is for.
27. **The commitment card replaces the intent field rather than joining it.** Both ask nearly the same question and the setup screen has ten seconds before people bounce. Off by default; it reads as pressure to some people.
28. **The celebration chime is synthesised too.** Two decaying partials built into a buffer — the sound the spec asked for in Milestone 4, arriving here with the audio stack, still with no asset.

**Check-ins and Insights (M7)**

29. **The pre-session check-in is off by default; the post-session one is on.** The spec asks for two taps of energy and mood before a session *and* says of the setup screen "do not add more steps — this is where users bounce". Those conflict, so the setup screen stays as it was unless someone asks for more. The one-tap "how did that go?" lands on the completion screen, which is already a pause.
30. **"How did that go?" is its own field, `focusQuality`, not reused `mood`.** It's a different question, and it's the one the chart of how sessions felt is built on.
31. **The chart is by time of day, not by hour.** Twenty-four bars of one person's sessions is mostly empty bars and noise — two sessions at 3pm is not a pattern. Five named blocks give each bar enough in it to mean something. Bars with fewer than five sessions are drawn faded rather than hidden or shown at full strength.
32. **Every sentence waits for enough data.** Two weeks and ten sessions for the time-of-day line, five sessions a block, a week of days on each side for medication. Below that, the screen says how long until it can say something, instead of guessing.
33. **"About the same" is reported as a finding.** Below a 15% difference the sentence says sessions go equally well whenever, rather than inflating noise into a pattern.
34. **The medication reminder arrives in M7, not M9.** It is inseparable from notifications, and asking for permission the moment someone switches on a reminder is exactly the "in context, with a reason" the spec wants for onboarding. Milestone 9's session-end backstop reuses whatever was granted here. The toggle only stays on if the reminder is genuinely armed — if permission is refused it flips back off and says why.
35. **The medication observation is the one to look hardest at.** It reports completion on days with a log against days without, as bare arithmetic, with the caveat inline: a day without a log isn't necessarily a day without it, plenty else changes, and "talk to whoever prescribes it before changing anything". A test fails if the sentence ever says *because*, *helps*, *works*, *should*, or similar. If you'd rather not show it at all, it's one card to delete — nothing else depends on it.
36. **Reflections are marked health-adjacent too.** The spec only names mood, energy and medication. But "what was hard today" and a line of gratitude are journaling, and the conservative default for journaling is the same one.
37. **Sessions closed after their heartbeat are left out of every chart.** Nobody confirmed what happened in them, and counting them as failures would skew the chart toward whenever someone tends to leave the app running.

**Stillness (M8)**

38. **Nothing is attributed, because nothing came from anyone.** See the content section above. The attribution rendering path exists and is unused; adding a real quotation means finding verbatim source text and checking it, which is your call, not something to be written from memory.
39. **No bundled audio, so guidance is text cues paced by the timer.** The alternative was a synthesised voice, which the rule forbids outright, or silence with a script nobody reads. Cues spread evenly across the chosen length and hold on the last one if the sit overruns.
40. **A sit is written when it ends, not when it starts.** The opposite of a focus session, deliberately: the schema has no open-sit state, and losing a two-minute practice to a force quit costs far less than the machinery to recover one. A sit does survive backgrounding while the app lives, which covers walking meditation with the phone in a pocket.
41. **A plain break timer is not a sit and records nothing.** "Just give me the five minutes" is a legitimate break. Counting it would inflate the calm streak with minutes nobody practised.
42. **The calm streak reuses the focus streak's walk with a freeze budget of zero.** Same code, one parameter. It has no freezes because it has nothing to rescue — a day without a sit simply does not appear, and `applyingCalm` deliberately touches none of the freeze fields so it can never spend the focus streak's budget.
43. **The pacer ticks ten times a second; everything else ticks once.** A phase boundary landing up to a second late is a pacer people stop trusting. Nothing accumulates across ticks, so the rate only affects how promptly a boundary is noticed.
44. **The shape animates to where it is going, not to where it is.** On a phase change the view animates to the step's end fullness over the step's own duration. Following `fullness` frame by frame would stutter at whatever rate the model happens to tick.
45. **Under Reduce Motion the shape does not move at all.** The instruction word, the count and a filling bar carry the pacing instead. Someone who asked the system for less motion should not be handed a pulsing circle as the centrepiece of a calming screen.
46. **Box breathing gets a rounded square, the sigh gets a circle.** The shape names the practice, which is one less thing to explain.
47. **No confirmation dialog when you end a sit.** The focus screen has one because abandoning work is costly. Leaving a two-minute breath practice is not, and "are you sure?" there would be its own small nag.
48. **The sound anchor rings its bells whether or not interval bells are switched on.** The bell *is* that practice; silencing it leaves nothing to do. Every other long sit respects the setting.
49. **The break offer is a screen after the completion screen, not a button on it.** The completion screen already has a job. The suggested practice is pre-chosen so taking a break is one decision rather than a menu, and swapping it is a row of chips that stays out of the way.
50. **Open awareness is shown locked rather than hidden.** A library that hides most of itself reads as a short library instead of a growing one. The row says exactly what it needs: "After 20 more sits".
51. **The morning intention appears during a session only when the session has no intent of its own.** Both are one line of text above the disc, and three lines up there is three lines nobody reads.
52. **The framing changes the bell's pitch.** That is the spec's "ambient sound palette", done with the synthesiser that already exists rather than with audio files that do not.

**System surfaces (M9)**

53. **No App Group entitlement by default.** See the section at the top. Free accounts cannot sign one, and a widget that stops the app installing is a worse trade than a widget that is only a launcher until you flip one switch.
54. **No Control Center control.** `OpenURLIntent` rejects custom URL schemes, so opening the app from a control needs a universal link, which needs a web domain. The spec said "if straightforward"; it isn't.
55. **The Live Activity carries dates and is never updated while a session runs.** The system renders the countdown from `startedAt` and `plannedEnd`, so the Lock Screen cannot disagree with the app — the same "nothing counts down" rule as the engine, applied outside it.
56. **It goes stale at the planned end.** A session that runs out with the app closed turns coral and says "Time's up" instead of sitting on a frozen 0:00 until someone opens the app.
57. **It is dismissed immediately when a session finishes.** A session only ever finishes with the app in the foreground, where the completion screen has already replaced it. Keeping it on the Lock Screen afterwards would be clutter.
58. **The Live Activity shows the task; Lock Screen widgets never do.** The first is a session you started seconds ago. The second is always on, readable by whoever picks the phone up. The session-end notification never names the task either.
59. **The session-end alert never asks for permission on its own.** The moment a session starts is the worst moment for a dialog. Settings has an Allow button until onboarding asks in context in Milestone 10, and the switch there reflects what iOS actually allows, not what the setting says.
60. **The session-end banner is swallowed while the app is open.** The completion screen is the notification. The medication reminder still shows.
61. **"Start a focus session" from Siri skips the setup screen.** Asking questions between the request and the session is the friction the app exists to remove. A request that arrives mid-launch waits until any running session has been recovered, and one that arrives during a session or a sit is refused rather than stacked.
62. **Brain dump from Siri does not open the app.** Getting a thought out of your head should not cost you whatever you were in the middle of.
63. **One model container per process.** Intents can run the app with no interface, and two containers on one store file in one process is a way to lose writes. Both go through `SharedStore`.
64. **Nothing health-adjacent can reach a widget, by construction.** `WidgetSnapshot.make` does not take check-ins, medication or reflections as parameters, and a test pins the snapshot's key list.
65. **Session recovery moved from the root view into launch.** It has to finish before an intent can safely start anything, and a view's `.task` gave no ordering guarantee against the app's.
66. **Widgets redraw on their own only at the planned end and at midnight.** Timers count themselves, and an unchanged snapshot is not republished, because the system budgets widget reloads.

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
- **Time checks** — off by default, fires on the interval, one pulse after backgrounding rather than a burst, no backlog replayed on restore
- **Depleting disc** — empty at zero, whole circle at one, clamped above one, animatable as one continuous value
- **Estimate calibration** — silence below ten samples, median resisting a 40x outlier, padding clamped at 0.5–3x, per-task deltas
- **Noise generation** — every bed stays inside full scale and finite, brown reads smoother than pink once normalised by RMS, a zero seed does not lock the generator at silence, filters reset without clicking
- **Body doubling** — milestones fire once each and do not stack when several bands are skipped at once, soundscapes appear only when both owned and playable, companion state through start, finish and reset
- **Insights** — block boundaries including the one that wraps midnight, which sessions count, the two-week gate, focus quality drawn only from post-session check-ins, a real difference vs a wobble vs nothing to compare, the calendar's states, today never drawn as a miss
- **Medication** — the observation stays silent below a week each side, only taken and undeleted logs count, the sentence never offers a reason or advice, the lock-screen text never mentions medication, a refused permission leaves the toggle honestly off
- **Check-ins** — a skipped check-in writes no row, changing an answer updates in place, clearing removes it, keep-going does not carry the old energy reading forward
- **Breath pacer** — every second of a box cycle lands in the right phase, fullness rises evenly and holds through a hold, the exhale of the sigh outlasts both inhales, twenty minutes of elapsed time changes nothing because nothing accumulates, one haptic per boundary and never two
- **Practice content** — every attribution is nil, no script or framing contains quotation marks or an attributive verb, every framing says a wandering mind is the practice, ids are stable so reseeding cannot duplicate the catalogue
- **Sits** — starting writes nothing, running to the end records a completed sit, the eighty-percent rule, a mis-tap leaves no litter, a plain break timer records nothing, the framing is recorded on the sit rather than looked up later
- **Calm streak** — consecutive days build it, a gap is *not* bridged by a freeze, today is never held against you, the longest survives a lapse, it never spends the focus streak's freeze budget
- **Breaks** — the offer respects its setting, Just Start has no break so offers none, the suggestion always fits inside the break, a longer break gets a longer practice, a locked practice is never suggested
- **Interval bells** — off unless asked for, spaced by elapsed time so they cannot drift, the sound anchor rings either way, short sits stay quiet
- **Reflection** — the morning line and the evening close land in one row, writing the evening does not wipe the morning, saying nothing writes nothing, a new day starts blank
- **Live Activity** — carries dates not a countdown, a count-up session never goes stale, the timer range is never backwards, a relaunch updates the activity rather than stacking one, a new session clears leftovers
- **Widgets** — the snapshot's key allowlist, the rule-of-three cap, streak wording matching the app's, idle to running to time's up, yesterday's musts hidden today, unchanged pictures not resent, redraws only at the planned end and midnight, a snapshot from another version ignored
- **Session-end alerts** — scheduled at the planned end, none for Flowmodoro or an end already passed, the Lock Screen text never names the task, clearing never touches the medication reminder, swallowed in the foreground, the setting turns alerts off without turning off the Lock Screen timer
- **Siri and Shortcuts** — every mode reachable, a start mid-launch waits then runs, a second start is refused, brain dump works with the app closed, an empty dump writes nothing
- **Deep links** — every link round-trips, other schemes and unknown destinations are ignored
- **Data sensitivity** — the health-adjacent list is pinned
- **Day arithmetic** — spring forward, fall back, midnight rollover, timezone shift
- **Repositories** — round-trips, soft delete cascade, the rule-of-three cap, singleton rows, reseeding without losing unlocks

## Deferred seams

Written as protocols now, implemented later, so nothing has to be retrofitted:

- **The App Group** — written to and read from, never entitled. See the section at the top: one capability on two targets and the widgets show real data.
- A Control Center control — needs a universal link, which needs a web domain. `DeepLink` is the seam: the same destinations over `https`.
- The in-context notification ask — Milestone 10's onboarding. Until then, Settings has the Allow button.
- A real Settings screen — Milestone 10. `TimeSettingsSheet` carries the Milestone 5 switches in the meantime, because a feature nobody can reach is a feature nobody can judge; it folds into Settings when that lands.
- Real multiplayer co-working rooms — out of scope for v1, they need a backend. `BodyDoublingProvider` is the seam: `LocalCompanionProvider` returns one synthetic coworker, a `RemoteRoomProvider` would return several real ones, and the session screen already renders a list rather than a single figure.
- Recorded soundscapes — Café and Library expect `soundscape-cafe.m4a` and `soundscape-library.m4a` in the bundle and light up on their own once those exist.
- `PracticeProvider` — `BundledPracticeProvider` reads a constant today. A `RemotePracticeProvider` serving a larger library replaces it and nothing else: views and view models talk to the repository, which is seeded from the provider.
- Recorded practice guidance — `Practice.audioAssetName` is wired through to the practice screen and set on nothing. `attribution` renders wherever it is set and is set on nothing. Between them, a licensed course recorded by a consenting named teacher drops in as data.
- Multi-week programs — `Practice.programID` and `orderInProgram` are in the schema and unused, so "21 days of morning stillness" is not a migration.
- AI-assisted task breakdown — not in v1 and not stubbed. The offline template row in the step editor is the shape it would slot into if it ever ships.
- XP, coins, streaks, the celebration moment, and the post-session energy check-in — Milestones 4 and 7. The completion screen leaves that space empty rather than filling it with a placeholder.

There is no pause. The spec never asks for one, so it was not invented.

---

## Not in v1

App blocking, accounts, cloud sync, multiplayer rooms, AI task breakdown, any network call, social features, Watch/iPad/Mac, IAP, HealthKit, streamed practice content.

**Content rule, permanent:** nothing is ever generated or paraphrased in the voice of a named real person, and no voice or likeness is synthesised. Quotes from real teachers appear only verbatim, correctly attributed, and public domain or explicitly licensed. Everything else is the app's own words.

Kool Skool is not a medical device and gives no medical advice. The medication log is a log.
