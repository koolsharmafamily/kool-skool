import SwiftUI

/// First launch. Four screens at most, one decision each, then a session.
///
/// Every question can be skipped, and the one primary button on each screen
/// always moves forward, so the fastest route through is simply tapping it.
struct OnboardingView: View {
    @Bindable var model: OnboardingModel

    @State private var isPickingTradition = false
    @FocusState private var isEditingFocus: Bool
    @ScaledMetric(relativeTo: .largeTitle) private var iconSize: CGFloat = 44

    private static let starters = ["Studying for an exam", "A work project", "Reading", "Writing"]

    var body: some View {
        KSScreen(state: .ready) {
            VStack(alignment: .leading, spacing: KSSpacing.lg) {
                header

                ScrollView {
                    stepContent
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .id(model.step)
                        .ksTransition(.asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal: .move(edge: .leading).combined(with: .opacity)
                        ))
                }
                .scrollIndicators(.hidden)
                .scrollDismissesKeyboard(.interactively)

                footer
            }
            .padding(.vertical, KSSpacing.lg)
        }
        .ksAnimation(KSAnimation.gentle, value: model.step)
        .sheet(isPresented: $isPickingTradition) {
            TraditionPickerSheet(
                selected: model.tradition,
                onSelect: { tradition in
                    model.tradition = tradition
                    isPickingTradition = false
                },
                onClose: { isPickingTradition = false }
            )
        }
    }

    // MARK: Chrome

    private var header: some View {
        HStack {
            if model.canGoBack {
                Button {
                    isEditingFocus = false
                    model.goBack()
                } label: {
                    Label("Back", systemImage: "chevron.left")
                        .ksFont(KSFont.label)
                        .frame(minHeight: KSSize.minimumTapTarget)
                        // A plain button is tappable only where it draws.
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .foregroundStyle(KSColor.textSecondary)
            }

            Spacer()

            progressDots
        }
        .frame(minHeight: KSSize.minimumTapTarget)
    }

    private var progressDots: some View {
        HStack(spacing: KSSpacing.xs) {
            ForEach(0..<model.stepCount, id: \.self) { index in
                Capsule(style: .continuous)
                    .fill(index < model.stepNumber ? KSColor.accent(.ready) : KSColor.track)
                    .frame(width: index == model.stepNumber - 1 ? 24 : 8, height: 8)
            }
        }
        // The dots are 8pt tall; the element around them is a full 44pt.
        .frame(minHeight: KSSize.minimumTapTarget)
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Step \(model.stepNumber) of \(model.stepCount)")
    }

    private var footer: some View {
        VStack(spacing: KSSpacing.xs) {
            switch model.step {
            case .focus:
                KSPrimaryButton(
                    title: model.trimmedFocus.isEmpty ? "Skip for now" : "Next",
                    systemImage: model.trimmedFocus.isEmpty ? nil : "arrow.right",
                    action: next
                )

            case .rhythm:
                KSPrimaryButton(
                    title: model.preferredWorkTime == nil ? "Skip for now" : "Next",
                    systemImage: model.preferredWorkTime == nil ? nil : "arrow.right",
                    action: next
                )

            case .notifications:
                KSPrimaryButton(title: "Allow notifications", systemImage: "bell") {
                    Task { await model.allowNotifications() }
                }
                quietButton("Not now", action: next)

            case .start:
                KSPrimaryButton(title: "Just Start", systemImage: "bolt.fill", isEnabled: !model.isFinishing) {
                    Task { await model.finish() }
                }
                // Quiet, under the one primary. Forcing a session on someone who
                // wants to look around first is its own kind of friction.
                quietButton("I'll look around first") {
                    Task { await model.finish(startingSession: false) }
                }
            }
        }
    }

    // MARK: Steps

    @ViewBuilder
    private var stepContent: some View {
        switch model.step {
        case .focus: focusStep
        case .rhythm: rhythmStep
        case .notifications: notificationStep
        case .start: startStep
        }
    }

    private var focusStep: some View {
        VStack(alignment: .leading, spacing: KSSpacing.md) {
            heading("What do you want to focus on?")
            detail("One thing is plenty. It'll be pinned to Today, and your first session will be on it.")

            // Wraps instead of clipping a long answer or a large text size.
            TextField("Revise chapter four", text: $model.focusText, axis: .vertical)
                .ksFont(KSFont.headline)
                .foregroundStyle(KSColor.textPrimary)
                .textInputAutocapitalization(.sentences)
                .lineLimit(1...3)
                .submitLabel(.next)
                .focused($isEditingFocus)
                .onSubmit(next)
                .onChange(of: model.focusText) { _, text in
                    // A wrapping field turns Return into a newline. A task title
                    // has no use for one, so Return moves on instead, as it would
                    // in a single-line field.
                    guard text.contains("\n") else { return }
                    model.focusText = text.replacingOccurrences(of: "\n", with: "")
                    next()
                }
                .padding(KSSpacing.md)
                .background(KSColor.surface, in: RoundedRectangle(cornerRadius: KSRadius.md, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: KSRadius.md, style: .continuous)
                        .strokeBorder(KSColor.hairline, lineWidth: KSStroke.hairline)
                )
                .accessibilityLabel("What you want to focus on")

            // A blank field is a blank page. A starter takes the edge off it.
            // One column, so no starter is squeezed at large text sizes.
            VStack(spacing: KSSpacing.xs) {
                ForEach(Self.starters, id: \.self) { starter in
                    choiceChip(starter, isSelected: model.focusText == starter) {
                        model.focusText = model.focusText == starter ? "" : starter
                    }
                }
            }
        }
    }

    private var rhythmStep: some View {
        VStack(alignment: .leading, spacing: KSSpacing.md) {
            heading("When do you work best?")
            detail("A guess is fine. Once there's enough history, Insights will show whether your sessions agree.")

            VStack(spacing: KSSpacing.xs) {
                ForEach(TimeOfDay.allCases) { time in
                    timeRow(time)
                }
            }

            framingRow
        }
    }

    private var notificationStep: some View {
        VStack(alignment: .leading, spacing: KSSpacing.md) {
            Image(systemName: "bell.badge")
                .font(.system(size: iconSize, weight: .semibold))
                .foregroundStyle(KSColor.accent(.ready))
                .accessibilityHidden(true)

            heading("Want a nudge when time's up?")
            detail("If you're in another app when a session ends, Kool Skool can tell you. That's what notifications are for here — plus a medication reminder, only if you ever switch one on.")
            detail("The timer on your Lock Screen works either way.")
        }
    }

    private var startStep: some View {
        VStack(alignment: .leading, spacing: KSSpacing.md) {
            heading("Five minutes. That's it.")
            detail("Just Start runs for five minutes. When it ends, stop — or keep going if it's flowing. Starting is the hard part, so starting is all this asks.")

            if !model.trimmedFocus.isEmpty {
                KSCard {
                    VStack(alignment: .leading, spacing: KSSpacing.xxs) {
                        Text("Working on")
                            .ksFont(KSFont.caption)
                            .foregroundStyle(KSColor.textSecondary)
                        Text(model.trimmedFocus)
                            .ksFont(KSFont.headline)
                            .foregroundStyle(KSColor.textPrimary)
                    }
                }
                .accessibilityElement(children: .combine)
            }
        }
    }

    // MARK: Pieces

    private func timeRow(_ time: TimeOfDay) -> some View {
        let isSelected = model.preferredWorkTime == time

        return Button {
            KSHaptics.shared.fire(.selection)
            model.preferredWorkTime = isSelected ? nil : time
        } label: {
            HStack {
                Text(time.displayName)
                    .ksFont(KSFont.bodyEmphasis)
                Spacer()
                Text(time.hoursLabel)
                    .ksFont(KSFont.caption)
                    .foregroundStyle(isSelected ? KSColor.onAccent(.ready) : KSColor.textSecondary)
            }
            .padding(.horizontal, KSSpacing.md)
            .frame(maxWidth: .infinity, minHeight: KSSize.minimumTapTarget + KSSpacing.xs)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(isSelected ? KSColor.onAccent(.ready) : KSColor.textPrimary)
        .background(
            isSelected ? KSColor.accent(.ready) : KSColor.surfaceRaised,
            in: RoundedRectangle(cornerRadius: KSRadius.md, style: .continuous)
        )
        .accessibilityLabel("\(time.displayName), \(time.hoursLabel)")
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }

    /// The spec puts the framing choice in onboarding. It rides along here as
    /// one optional row rather than a fifth screen: it is an invitation, and the
    /// secular default needs no answer.
    private var framingRow: some View {
        Button {
            isPickingTradition = true
        } label: {
            HStack(spacing: KSSpacing.sm) {
                VStack(alignment: .leading, spacing: KSSpacing.xxs) {
                    Text("Framing for breathing breaks")
                        .ksFont(KSFont.caption)
                        .foregroundStyle(KSColor.textSecondary)
                    Text(model.tradition.displayName)
                        .ksFont(KSFont.body)
                        .foregroundStyle(KSColor.textPrimary)
                }
                Spacer()
                Text("Change")
                    .ksFont(KSFont.label)
                    .foregroundStyle(KSColor.accent(.ready))
                    // Never truncated; the label beside it wraps instead.
                    .fixedSize()
                    .layoutPriority(1)
            }
            .padding(KSSpacing.md)
            .background(KSColor.surface, in: RoundedRectangle(cornerRadius: KSRadius.md, style: .continuous))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityHint("Optional. Changes the wording of breathing breaks, never what they ask you to do.")
    }

    private func choiceChip(_ title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button {
            KSHaptics.shared.fire(.selection)
            action()
        } label: {
            Text(title)
                .ksFont(KSFont.label)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, KSSpacing.sm)
                .frame(maxWidth: .infinity, minHeight: KSSize.minimumTapTarget)
        }
        .buttonStyle(.plain)
        .foregroundStyle(isSelected ? KSColor.onAccent(.ready) : KSColor.textPrimary)
        .background(
            isSelected ? KSColor.accent(.ready) : KSColor.surfaceRaised,
            in: RoundedRectangle(cornerRadius: KSRadius.md, style: .continuous)
        )
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }

    private func heading(_ text: String) -> some View {
        Text(text)
            .ksFont(KSFont.title)
            .foregroundStyle(KSColor.textPrimary)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityAddTraits(.isHeader)
    }

    private func detail(_ text: String) -> some View {
        Text(text)
            .ksFont(KSFont.body)
            .foregroundStyle(KSColor.textSecondary)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func quietButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .ksFont(KSFont.label)
                .frame(maxWidth: .infinity, minHeight: KSSize.minimumTapTarget)
                // A plain button is tappable only where it draws.
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(KSColor.textSecondary)
    }

    private func next() {
        isEditingFocus = false
        model.advance()
    }
}

#if DEBUG
#Preview {
    OnboardingView(model: OnboardingModel(
        repositories: UnavailableRepositoryProvider(reason: "Preview has no store."),
        clock: PreviewClock.fixed,
        initialSettings: AppSettings(),
        notificationStatus: .notDetermined,
        applySettings: { _ in },
        requestNotifications: { .authorised },
        startSession: { _ in }
    ))
}
#endif
