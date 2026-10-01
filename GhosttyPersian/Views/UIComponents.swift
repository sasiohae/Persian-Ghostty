import SwiftUI

/// Compact status badge representing the active document state and Ghostty CLI validation status.
public struct StatusBadgeView: View {
    public let isDirty: Bool
    public let dirtyCount: Int
    public let validationState: ValidationState

    public init(isDirty: Bool, dirtyCount: Int, validationState: ValidationState) {
        self.isDirty = isDirty
        self.dirtyCount = dirtyCount
        self.validationState = validationState
    }

    public var body: some View {
        HStack(spacing: 5) {
            if isDirty {
                Circle()
                    .fill(Color.orange)
                    .frame(width: 7, height: 7)
                Text("Modified (\(dirtyCount))")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.orange)
            } else {
                switch validationState {
                case .valid:
                    Circle()
                        .fill(Color.green)
                        .frame(width: 7, height: 7)
                    Text("Valid")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.green)
                case .invalid(let issues, _):
                    Circle()
                        .fill(Color.red)
                        .frame(width: 7, height: 7)
                    Text("\(issues.count) Issue\(issues.count == 1 ? "" : "s")")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.red)
                case .validating:
                    ProgressView()
                        .controlSize(.mini)
                    Text("Validating...")
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.secondary)
                case .skipped, .unknown:
                    Circle()
                        .fill(Color.secondary.opacity(0.5))
                        .frame(width: 7, height: 7)
                    Text("Synced")
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(badgeBackground)
        .clipShape(Capsule())
        .overlay(
            Capsule()
                .stroke(badgeBorderColor, lineWidth: 1)
        )
    }

    private var badgeBackground: Color {
        if isDirty {
            return Color.orange.opacity(0.12)
        }
        switch validationState {
        case .valid:
            return Color.green.opacity(0.12)
        case .invalid:
            return Color.red.opacity(0.12)
        case .validating, .skipped, .unknown:
            return Color(nsColor: .controlBackgroundColor).opacity(0.6)
        }
    }

    private var badgeBorderColor: Color {
        if isDirty {
            return Color.orange.opacity(0.25)
        }
        switch validationState {
        case .valid:
            return Color.green.opacity(0.25)
        case .invalid:
            return Color.red.opacity(0.25)
        case .validating, .skipped, .unknown:
            return Color(nsColor: .separatorColor).opacity(0.5)
        }
    }
}

/// Floating non-intrusive toast banner for user operation feedback.
public struct FloatingToastView: View {
    public let toast: AppViewModel.ToastNotification
    public let onDismiss: () -> Void
    public let onInspect: (() -> Void)?

    public init(
        toast: AppViewModel.ToastNotification,
        onDismiss: @escaping () -> Void,
        onInspect: (() -> Void)? = nil
    ) {
        self.toast = toast
        self.onDismiss = onDismiss
        self.onInspect = onInspect
    }

    public var body: some View {
        HStack(spacing: 12) {
            Image(systemName: toast.isError ? "exclamationmark.circle.fill" : "checkmark.circle.fill")
                .foregroundStyle(toast.isError ? Color.red : Color.green)
                .font(.title3)

            VStack(alignment: .leading, spacing: 2) {
                Text(toast.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.primary)
                Text(toast.message)
                    .font(.caption)
                    .foregroundStyle(Color.secondary)
                    .lineLimit(2)

                if toast.isError, let onInspect = onInspect {
                    Button {
                        onInspect()
                    } label: {
                        Text("Inspect Diagnostics...")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(Color.red)
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 2)
                }
            }

            Spacer()

            Button {
                onDismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(Color.secondary)
                    .padding(4)
                    .background(Color.secondary.opacity(0.12))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(minWidth: 280, maxWidth: 380)
        .background(Color(nsColor: .windowBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .shadow(color: Color.black.opacity(0.18), radius: 8, x: 0, y: 4)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
        )
    }
}
