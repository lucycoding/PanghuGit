import SwiftUI

struct EmptyStateView: View {
    let message: String
    var systemImage: String? = nil

    var body: some View {
        VStack(spacing: 6) {
            if let icon = systemImage {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(.quaternary)
            }
            Text(message)
                .font(.body)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
