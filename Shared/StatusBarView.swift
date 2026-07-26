import SwiftUI

struct StatusBarView<Trailing: View>: View {
    let text: String
    var isError: Bool = false
    var isLoading: Bool = false
    @ViewBuilder var trailing: () -> Trailing

    init(text: String, isError: Bool = false, isLoading: Bool = false, @ViewBuilder trailing: @escaping () -> Trailing = { EmptyView() }) {
        self.text = text
        self.isError = isError
        self.isLoading = isLoading
        self.trailing = trailing
    }

    var body: some View {
        if !text.isEmpty || (isLoading && !text.isEmpty) {
            HStack(spacing: 6) {
                if isLoading { ProgressView().scaleEffect(0.7) }
                if !text.isEmpty {
                    Image(systemName: isError ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                        .font(.callout)
                    Text(text)
                        .font(.callout)
                        .lineLimit(2)
                }
                Spacer()
                trailing()
            }
            .foregroundStyle(isError ? .red : .green)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(.bar)
        }
    }
}
