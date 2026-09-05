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

    private var moment: ShieldMoment {
        switch momentIndex {
        case 0: return .reminder(minutesLeft: minutes, activity: activity)
        case 1: return .finished(activity: activity)
        default: return .spentForToday
        }
    }

    private var presentation: ShieldPresentation {
        .make(for: moment, childName: childName)
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
                Picker("Moment", selection: $momentIndex) {
                    Text("Reminder").tag(0)
                    Text("Finished").tag(1)
                    Text("Later today").tag(2)
                }
                .pickerStyle(.segmented)

                if momentIndex == 0 {
                    Stepper("Minutes left: \(minutes)", value: $minutes, in: 1...15)
                }

                if momentIndex != 2 {
                    Picker("Next activity", selection: $activity) {
                        Text("Not chosen").tag(TransitionActivity?.none)
                        ForEach(activities) { a in
                            Text(a.displayName).tag(TransitionActivity?.some(a))
                        }
                    }
                }
            } footer: {
                Text("This is a preview. The real screen appears inside the app your child is using, and needs Screen Time access — see Settings ▸ Status.")
            }

            Section {
                Button {
                    immersive = true
                } label: {
                    Label("Show it full screen", systemImage: "arrow.up.left.and.arrow.down.right")
                }
            } footer: {
                Text("Full screen is the honest test: hand the device to your child and watch what they do.")
            }
        }
        .scrollContentBackground(.hidden)
    }
}

#Preview {
    ShieldPreviewView(childName: "Ivy", activities: TransitionActivity.allCases)
}
