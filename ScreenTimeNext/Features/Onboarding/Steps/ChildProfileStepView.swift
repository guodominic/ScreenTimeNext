//  ChildProfileStepView.swift — PRD §6.2
import SwiftUI
import ScreenTimeNextCore

struct ChildProfileStepView: View {
    @Bindable var viewModel: OnboardingViewModel
    @FocusState private var nameFocused: Bool

    var body: some View {
        OnboardingStepScaffold(
            title: "What's your child's first name?",
            subtitle: "Just a first name. It stays on this device.",
            buttonTitle: "Continue",
            buttonEnabled: viewModel.draft.isChildNameValid,
            action: { viewModel.advance(to: .permission) }
        ) {
            TextField("First name", text: $viewModel.draft.childName)
                .textFieldStyle(.roundedBorder)
                .textContentType(.givenName)
                .autocorrectionDisabled()
                .submitLabel(.continue)
                .focused($nameFocused)
                .onSubmit {
                    if viewModel.draft.isChildNameValid { viewModel.advance(to: .permission) }
                }
        }
        .onAppear { nameFocused = true }
    }
}
