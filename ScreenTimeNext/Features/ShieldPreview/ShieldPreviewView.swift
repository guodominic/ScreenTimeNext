//  ShieldPreviewView.swift
//  ScreenTimeNext
//
//  D-012. Parent-facing: "see what your child will see". Lets Dominic tune the copy and show the
//  real moment to real children before the Family Controls entitlement exists (D-007 gate).
//  Every string comes from `ShieldPresentation.make` — the same function the Phase 1 extension uses.

import SwiftUI
import ScreenTimeNextCore

struct ShieldPreviewView: View {
    @Environment(\.dismiss) private var dismiss
    let childName: String
    /// The activities the parent approved, so the preview shows what this family will actually get.
    let activities: [TransitionActivity]

    @State private var momentIndex = 0
    @State private var activity: TransitionActivity?
    @State private var minutes = 5
    @State private var immersive = false
    /// Which reminder in the sequence — this is what drives the colour, not the clock (D-018).
    @State private var urgency: ShieldUrgency = .calm

    private var moment: ShieldMoment {
        switch momentIndex {
        case 0: return .reminder(minutesLeft: minutes, activity: activity)
        // D-044 — the second of the three shields a child meets. Previewable, because a parent
        // should be able to see the one that ASKS before their child does.
        case 1: return .chooseNext(minutesLeft: minutes, options: ShieldMomentResolver.chooserOptions(activities))
        case 2: return .finished(activity: activity)
        default: return .spentForToday
        }
    }

    private var presentation: ShieldPresentation {
        .make(for: moment, childName: childName, urgency: momentIndex <= 1 ? urgency : nil)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                stage
                controls
            }
            .navigationTitle("What your child sees")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } }
            }
        }
        .fullScreenCover(isPresented: $immersive) {
            ZStack {
                PretendAppBackdrop()
                ShieldCardView(presentation: presentation) { immersive = false }
            }
            .overlay(alignment: .topTrailing) {
                Button { immersive = false } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.white.opacity(0.8))
                        .padding()
                }
            }
        }
    }

    private var stage: some View {
        ZStack {
            PretendAppBackdrop()
            ShieldCardView(presentation: presentation)
                .id(presentation)          // re-run the entrance animation on every change
        }
        .frame(maxHeight: 420)
        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: presentation)
    }

    private var controls: some View {
        Form {
            Section {
                // D-044 — the three shields, in the order a child meets them, plus the one they
                // only see if they come back later in the day.
                Picker("Moment", selection: $momentIndex) {
                    Text("1 · Heads-up").tag(0)
                    Text("2 · Pick next").tag(1)
                    Text("3 · Finished").tag(2)
                    Text("Later").tag(3)
                }
                .pickerStyle(.segmented)

                if momentIndex <= 1 {
                    Picker("Which reminder", selection: $urgency) {
                        Text("1st · green").tag(ShieldUrgency.calm)
                        Text("2nd · orange").tag(ShieldUrgency.soon)
                        Text("Last · red").tag(ShieldUrgency.last)
                    }
                    .pickerStyle(.segmented)
                    Stepper("Minutes left: \(minutes)", value: $minutes, in: 1...15)
                }

                // The chooser builds its own list from the parent's activities, and "Later today"
                // never names one, so this only applies to the other two.
                if momentIndex == 0 || momentIndex == 2 {
                    Picker("Next activity", selection: $activity) {
                        Text("Not chosen").tag(TransitionActivity?.none)
                        ForEach(activities) { a in
                            Text(a.displayName).tag(TransitionActivity?.some(a))
                        }
                    }
                }
            } footer: {
                Text("This is a preview. The real screen appears inside the app being used, and needs Screen Time access. Colour follows the countdown: green, then orange, then red, and the finish is the only colourful one.")
            }

            Section {
                Button {
                    immersive = true
                } label: {
                    Label("Show it full screen", systemImage: "arrow.up.left.and.arrow.down.right")
                }
            } footer: {
                Text("Full screen is the honest test: hand the device over and watch what happens.")
            }
        }
        .scrollContentBackground(.hidden)
    }
}

#Preview {
    ShieldPreviewView(childName: "Ivy", activities: TransitionActivity.allCases)
}
