import SwiftUI

struct AsyncButton<Label: View>: View {
    let action: () async -> Void
    @ViewBuilder let label: () -> Label

    var body: some View {
        Button {
            Task { await action() }
        } label: {
            label()
        }
        .buttonStyle(PressableButtonStyle())
    }
}
