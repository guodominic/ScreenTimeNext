//  WhatsNextStepView.swift — PRD §6.7 (fixed set of eight activities)
import SwiftUI
import ScreenTimeNextCore

struct WhatsNextStepView: View {
    @Bindable var viewModel: OnboardingViewModel

    private var name: String { viewModel.draft.trimmedChildName }
    private let columns = [GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        OnboardingStepScaffold(
            title: "What can \(name) do next?",
            subtitle: "Pick the activities \(name) can choose from when screen time ends.",
            buttonTitle: "Continue",
            action: { viewModel.advance(to: .ready) }
        ) {
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(TransitionActivity.allCases) { activity in
                    let selected = viewModel.draft.selectedActivities.contains(activity)
                    Button {
                        if selected {
                            viewModel.draft.selectedActivities.remove(activity)
                        } else {
                            viewModel.draft.selectedActivities.insert(activity)
                        }
                    } label: {
                        HStack {
                            Text(activity.displayName)
                            Spacer()
                            if selected {
                                Image(systemName: "checkmark.circle.fill")
                            }
                        }
                        .padding(.vertical, 10)
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .tint(selected ? Color.accentColor : Color.secondary)
                }
            }
            if viewModel.draft.selectedActivities.isEmpty {
                Text("Pick at least one so \(name) has something to look forward to.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
