//  ParentPINView.swift
//  ScreenTimeNext
//
//  D-031 — the gate between the child's timer and the parent's controls.
//
//  A custom keypad, not a TextField: the system keyboard on a child's device brings autocorrect,
//  a paste bar, dictation and a predictive row, and every one of those is a way out of the screen
//  we are trying to hold. Twelve buttons have no such doors.

import SwiftUI
import ScreenTimeNextCore

struct ParentPINView: View {
    enum Mode {
        case unlock                     // prove you are the parent
        case create                     // pick a PIN (entered twice)
        case change(existing: ParentPIN) // prove, then pick a new one
    }

    @Environment(\.dismiss) private var dismiss

    let mode: Mode
    /// `.unlock` is the only mode that checks a stored PIN; the others are handed theirs by `mode`.
    var storedPIN: ParentPIN?
    /// D-036 — false for the forced first-run setup, where there is nothing to go back to and a
    /// Cancel button would just be a way for a child to skip the gate. Declared BEFORE the two
    /// closures so the memberwise initialiser still takes `onSuccess` as a trailing closure.
    var canCancel: Bool = true
    /// `.unlock` passes nil; `.create` and `.change` pass the new PIN to store.
    let onSuccess: (ParentPIN?) -> Void
    var onCancel: () -> Void = {}

    @State private var digits = ""
    @State private var firstEntry: String?
    @State private var provedIdentity = false
    @State private var lockout = ParentPINLockout()
    /// Separate from `lockout.failedAttempts` on purpose: the COUNT must survive the wait (so the
    /// next delay is longer), while the WAIT itself has to end or the parent is stuck forever.
    @State private var isWaiting = false
    @State private var shake = 0
    @State private var message: String?

    private var pinToMatch: ParentPIN? {
        switch mode {
        case .unlock: return storedPIN
        case .change(let existing): return provedIdentity ? nil : existing
        case .create: return nil
        }
    }

    var body: some View {
        VStack(spacing: 22) {
            Mascot(mood: .thinking, size: 76, tint: Theme.sky, animated: false)
            Text(title)
                .font(.system(.title3, design: .rounded).bold())
                .multilineTextAlignment(.center)
            Text(subtitle)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            dots
                .modifier(ShakeEffect(travel: CGFloat(shake)))

            if let message {
                Text(message).font(.footnote).foregroundStyle(Theme.ruby)
            }

            keypad
                .disabled(isWaiting)
                .opacity(isWaiting ? 0.4 : 1)

            if canCancel {
                Button("Cancel") { onCancel(); dismiss() }
                    .font(.footnote)
                    .padding(.top, 2)
            }
        }
        .padding(.vertical, 24)
        .readableWidth(420)
        .animation(.snappy, value: digits)
    }

    // MARK: Pieces

    private var dots: some View {
        HStack(spacing: 18) {
            ForEach(0..<ParentPIN.length, id: \.self) { index in
                Circle()
                    .fill(index < digits.count ? Theme.sky : Color(.tertiarySystemFill))
                    .frame(width: 16, height: 16)
            }
        }
    }

    private var keypad: some View {
        VStack(spacing: 14) {
            ForEach(0..<3, id: \.self) { row in
                HStack(spacing: 22) {
                    ForEach(1...3, id: \.self) { column in
                        key("\(row * 3 + column)")
                    }
                }
            }
            HStack(spacing: 22) {
                Color.clear.frame(width: 68, height: 68)
                key("0")
                Button(action: backspace) {
                    Image(systemName: "delete.left")
                        .font(.title3)
                        .frame(width: 68, height: 68)
                }
                .buttonStyle(.plain)
                .disabled(digits.isEmpty)
                .opacity(digits.isEmpty ? 0.3 : 1)
            }
        }
    }

    private func key(_ digit: String) -> some View {
        Button { append(digit) } label: {
            Text(digit)
                .font(.system(size: 28, weight: .semibold, design: .rounded))
                .frame(width: 68, height: 68)
                .background(Circle().fill(Color(.secondarySystemBackground)))
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.selection, trigger: digits)
    }

    // MARK: Copy

    private var title: String {
        switch mode {
        case .unlock: return "Parents only"
        case .create: return firstEntry == nil ? "Choose a PIN" : "Enter it again"
        case .change: return provedIdentity ? (firstEntry == nil ? "Choose a new PIN" : "Enter it again") : "Enter your current PIN"
        }
    }

    private var subtitle: String {
        switch mode {
        case .unlock:
            return "Enter your PIN to change the timer or open settings."
        case .create:
            return firstEntry == nil
                ? "Four digits. Your child will need this to leave the timer, so pick something they don't already know."
                : "Just to be sure you'll remember it."
        case .change:
            return provedIdentity ? "Four digits." : "Then you can pick a new one."
        }
    }

    // MARK: Entry

    private func append(_ digit: String) {
        guard digits.count < ParentPIN.length, !isWaiting else { return }
        message = nil
        digits.append(digit)
        if digits.count == ParentPIN.length { submit() }
    }

    private func backspace() {
        _ = digits.popLast()
        message = nil
    }

    private func submit() {
        let entered = digits
        digits = ""

        // Stage 1 of `.unlock` and `.change`: prove who you are.
        if let expected = pinToMatch {
            if expected.matches(entered) {
                lockout.reset()
                if case .unlock = mode {
                    onSuccess(nil)
                    dismiss()
                } else {
                    provedIdentity = true
                }
            } else {
                fail("That's not it. Try again.")
            }
            return
        }

        // Stage 2: pick a new PIN, entered twice.
        guard let first = firstEntry else {
            guard ParentPIN.isValid(entered) else { return }
            firstEntry = entered
            return
        }
        guard first == entered else {
            firstEntry = nil
            fail("Those didn't match. Start again.")
            return
        }
        guard let pin = ParentPIN.make(entered) else {
            firstEntry = nil
            fail("Please use four digits.")
            return
        }
        onSuccess(pin)
        dismiss()
    }

    private func fail(_ text: String) {
        lockout.recordFailure()
        withAnimation(.default) { shake += 1 }
        guard lockout.isLocked else {
            message = text
            return
        }
        let wait = lockout.delaySeconds
        isWaiting = true
        message = "Too many tries. Wait \(wait) seconds."
        Task {
            try? await Task.sleep(for: .seconds(wait))
            isWaiting = false
            message = nil
            // `lockout` is NOT reset here — only a correct PIN clears it. Otherwise sitting out one
            // wait would buy an unlimited number of further guesses.
        }
    }
}

/// A short horizontal wobble on a wrong entry. Faster to read than any sentence.
private struct ShakeEffect: GeometryEffect {
    var travel: CGFloat
    var animatableData: CGFloat {
        get { travel }
        set { travel = newValue }
    }
    func effectValue(size: CGSize) -> ProjectionTransform {
        ProjectionTransform(CGAffineTransform(translationX: 8 * sin(travel * .pi * 2), y: 0))
    }
}
