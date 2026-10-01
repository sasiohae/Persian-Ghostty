import SwiftUI
import AppKit

/// Detailed diagnostic sheet displaying human-readable root causes, technical logs, and actionable resolution buttons.
public struct DiagnosticSheetView: View {
    @Environment(AppViewModel.self) private var environmentViewModel: AppViewModel?
    @State private var fallbackViewModel = AppViewModel()

    private var viewModel: AppViewModel {
        environmentViewModel ?? fallbackViewModel
    }

    public let report: AppDiagnosticReport
    @Binding var isPresented: Bool
    @State private var isDetailsExpanded: Bool = true
    @State private var copied: Bool = false

    public init(report: AppDiagnosticReport, isPresented: Binding<Bool>) {
        self.report = report
        self._isPresented = isPresented
    }

    public var body: some View {
        VStack(spacing: 0) {
            // MARK: - Header
            HStack(spacing: 12) {
                Image(systemName: report.domain.iconName)
                    .font(.system(size: 26))
                    .foregroundStyle(Color.red)
                    .padding(8)
                    .background(Color.red.opacity(0.12))
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(report.title)
                            .font(.title3.weight(.bold))
                        Text(report.domain.rawValue)
                            .font(.caption2.weight(.semibold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.secondary.opacity(0.15))
                            .foregroundStyle(Color.secondary)
                            .clipShape(Capsule())
                    }
                    Text(report.summary)
                        .font(.caption)
                        .foregroundStyle(Color.secondary)
                }

                Spacer()

                Button {
                    isPresented = false
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(Color.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(20)
            .background(Color(nsColor: .windowBackgroundColor))

            Divider()

            // MARK: - Body Content
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    // Root Cause Card
                    VStack(alignment: .leading, spacing: 6) {
                        Label("Root Cause Analysis", systemImage: "magnifyingglass")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Color.primary)
                        Text(report.rootCause)
                            .font(.callout)
                            .foregroundStyle(Color.primary)
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(nsColor: .controlBackgroundColor))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }

                    // Suggested Resolution Card
                    VStack(alignment: .leading, spacing: 6) {
                        Label("Suggested Resolution", systemImage: "lightbulb")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Color.primary)
                        Text(report.recoverySuggestion)
                            .font(.callout)
                            .foregroundStyle(Color.secondary)
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(nsColor: .controlBackgroundColor))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }

                    // Interactive Action Buttons
                    if !report.actions.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Quick Actions")
                                .font(.subheadline.weight(.semibold))

                            HStack(spacing: 12) {
                                ForEach(report.actions) { action in
                                    Button {
                                        execute(action)
                                    } label: {
                                        Label(action.title, systemImage: action.systemImage)
                                    }
                                    .buttonStyle(.bordered)
                                    .controlSize(.regular)
                                }
                            }
                        }
                    }

                    // Collapsible Technical Diagnostics Box
                    VStack(alignment: .leading, spacing: 8) {
                        DisclosureGroup(
                            isExpanded: $isDetailsExpanded,
                            content: {
                                VStack(alignment: .leading, spacing: 8) {
                                    ScrollView([.horizontal, .vertical]) {
                                        Text(report.technicalDetails)
                                            .font(.system(.caption, design: .monospaced))
                                            .foregroundStyle(Color.primary)
                                            .padding(10)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                            .textSelection(.enabled)
                                    }
                                    .frame(maxHeight: 180)
                                    .background(Color(nsColor: .textBackgroundColor))
                                    .clipShape(RoundedRectangle(cornerRadius: 6))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 6)
                                            .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
                                    )

                                    HStack {
                                        Button {
                                            NSPasteboard.general.clearContents()
                                            NSPasteboard.general.setString(report.formattedReportForClipboard, forType: .string)
                                            copied = true
                                            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                                copied = false
                                            }
                                        } label: {
                                            Label(copied ? "Copied Diagnostics!" : "Copy Diagnostics to Clipboard", systemImage: copied ? "checkmark" : "doc.on.doc")
                                        }
                                        .buttonStyle(.bordered)
                                        .controlSize(.small)

                                        Spacer()
                                    }
                                }
                                .padding(.top, 4)
                            },
                            label: {
                                Text("Technical Output & Diagnostic Logs")
                                    .font(.subheadline.weight(.semibold))
                            }
                        )
                    }
                    .padding(12)
                    .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .padding(20)
            }
            .background(Color(nsColor: .controlBackgroundColor))

            Divider()

            // MARK: - Footer
            HStack {
                Spacer()
                Button("Close") {
                    isPresented = false
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(16)
            .background(Color(nsColor: .windowBackgroundColor))
        }
        .frame(minWidth: 640, minHeight: 520)
    }

    private func execute(_ action: DiagnosticAction) {
        switch action.kind {
        case .revertChanges:
            viewModel.resetChanges()
            isPresented = false
        case .restoreLastBackup:
            if let latest = viewModel.backups.first {
                Task {
                    await viewModel.restoreBackup(latest)
                    isPresented = false
                }
            }
        case .revealInFinder(let url):
            NSWorkspace.shared.activateFileViewerSelecting([url])
        case .runValidation:
            Task {
                await viewModel.validateCurrentDocument()
            }
        case .copyDiagnostics:
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(report.formattedReportForClipboard, forType: .string)
        case .dismiss:
            isPresented = false
        }
    }
}
