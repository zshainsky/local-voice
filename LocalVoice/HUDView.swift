import SwiftUI

// MARK: - Recording pulse dot

private struct RecordingDot: View {
    @State private var scale: CGFloat = 1.0

    var body: some View {
        Circle()
            .fill(Color.red)
            .frame(width: 10, height: 10)
            .scaleEffect(scale)
            .onAppear {
                withAnimation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true)) {
                    scale = 1.5
                }
            }
    }
}

// MARK: - HUD

struct HUDView: View {
    @ObservedObject var appState: AppState

    var body: some View {
        HStack(spacing: 10) {
            stateIcon
            Text(label)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundColor(.white)
                .lineLimit(1)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.black.opacity(0.82))
                .shadow(color: .black.opacity(0.4), radius: 10, x: 0, y: 4)
        )
        .fixedSize()
    }

    @ViewBuilder
    private var stateIcon: some View {
        switch appState.phase {
        case .recording:
            RecordingDot()
        case .transcribing, .cleaning:
            ProgressView()
                .progressViewStyle(.circular)
                .scaleEffect(0.65)
                .tint(.white)
        case .injecting:
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
                .font(.system(size: 14))
        case .error:
            Image(systemName: "exclamationmark.circle.fill")
                .foregroundColor(.orange)
                .font(.system(size: 14))
        case .loading:
            ProgressView()
                .progressViewStyle(.circular)
                .scaleEffect(0.65)
                .tint(.white)
        case .idle:
            EmptyView()
        }
    }

    private var label: String {
        switch appState.phase {
        case .loading:      return "Loading model…"
        case .recording:    return "Listening…"
        case .transcribing: return "Transcribing…"
        case .cleaning:     return "Cleaning…"
        case .injecting:    return "Done"
        case .error(let m): return m
        case .idle:         return ""
        }
    }
}
