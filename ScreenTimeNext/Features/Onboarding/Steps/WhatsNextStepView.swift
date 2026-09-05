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
            symbol: "star.fill",
            color: Theme.lavender,
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
                        HStack(spacing: 10) {
                            Image(systemName: activity.symbolName)
                                .foregroundStyle(selected ? .white : Theme.color(for: activity))
                            Text(activity.displayName).fontWeight(.semibold)
                            Spacer()
                            if selected { Image(systemName: "checkmark.circle.fill") }
                        }
                        .padding(.vertical, 12).padding(.horizontal, 12)
                        .frame(maxWidth: .infinity)
                        .foregroundStyle(selected ? .white : .primary)
                        .background(RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(selected ? Theme.color(for: activity) : Theme.color(for: activity).opacity(0.12)))
                    }
                    .buttonStyle(.plain)
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
