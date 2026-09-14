#!/bin/sh
# Accessibility lint. Run from anywhere: sh scripts/lint-accessibility.sh
#
# 1. Motion goes through the Reduce Motion aware helpers in KSAnimation.
# 2. No text or icon uses a literal point size, which Dynamic Type cannot scale.
# 3. No tap target is reachable only by a gesture VoiceOver cannot perform.
#
# Every allowlisted file checks Reduce Motion or VoiceOver for itself. Adding a
# file to a list is a decision to justify, not a way to make CI pass.

cd "$(dirname "$0")/.." || exit 1
status=0

motion_allowed='KoolSkool/DesignSystem/KSAnimation.swift|KoolSkool/DesignSystem/Components/KSButton.swift|KoolSkool/Features/Rewards/Views/ConfettiView.swift|KoolSkool/Features/Rewards/Views/CountingNumber.swift|KoolSkool/Features/Stillness/Views/BreathPacer.swift|KoolSkool/Features/BodyDoubling/Views/CompanionView.swift'
motion=$(grep -rnE 'withAnimation\(|\.animation\(|repeatForever|phaseAnimator|keyframeAnimator' --include='*.swift' KoolSkool | grep -vE "^($motion_allowed):")
if [ -n "$motion" ]; then
    echo "Animation that bypasses the Reduce Motion helpers (use ksAnimation, withKSAnimation or ksTransition):"
    echo "$motion"
    status=1
fi

sizes=$(grep -rnE '\.system\(size: *[0-9]' --include='*.swift' KoolSkool | grep -v '^KoolSkool/DesignSystem/KSFont.swift:')
if [ -n "$sizes" ]; then
    echo "Literal point sizes that Dynamic Type cannot scale (use KSFont or @ScaledMetric):"
    echo "$sizes"
    status=1
fi

gesture_allowed='KoolSkool/Features/Rewards/Views/CelebrationOverlay.swift'
gestures=$(grep -rnE 'onTapGesture|onLongPressGesture' --include='*.swift' KoolSkool | grep -vE "^($gesture_allowed):")
if [ -n "$gestures" ]; then
    echo "Gesture-only targets that VoiceOver cannot reach (use a Button, or add an accessibilityAction):"
    echo "$gestures"
    status=1
fi

if [ $status -eq 0 ]; then
    echo "Accessibility lint passed."
fi
exit $status
