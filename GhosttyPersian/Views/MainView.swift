import SwiftUI

public struct MainView: View {
    @Environment(AppViewModel.self) private var environmentViewModel: AppViewModel?
    @State private var fallbackViewModel = AppViewModel()

    private var viewModel: AppViewModel {
        environmentViewModel ?? fallbackViewModel
    }

    @State private var selectedSection: NavigationSection? = .general
    @State private var isValidating: Bool = false
    @State private var showPendingChangesSheet: Bool = false
    @State private var showDiagnosticSheet: Bool = false

    public init() {}

    public var body: some View {
        NavigationSplitView {
            SidebarView(selectedSection: $selectedSection)
                .navigationSplitViewColumnWidth(min: 200, ideal: 230, max: 280)
        } detail: {
            ZStack(alignment: .topTrailing) {
                // Section Content
                Group {
                    if let selectedSection {
                        switch selectedSection {
                        case .general:
                            GeneralSettingsView()
                        case .typography:
                            TypographySettingsView()
                        case .persian:
                            PersianSettingsView()
                        case .appearance:
                            AppearanceSettingsView()
                        case .window:
                            WindowSettingsView()
                        case .shell:
                            ShellSettingsView()
                        case .config:
                            ConfigSectionView()
                        }
                    } else {
                        VStack(spacing: 12) {
                            Image(systemName: "terminal")
                                .font(.system(size: 44))
                                .foregroundStyle(Color.secondary)
                            Text("Select a Section")
                                .font(.title3.weight(.medium))
                            Text("Choose a category from the sidebar to inspect and configure Ghostty.")
                                .font(.caption)
                                .foregroundStyle(Color.secondary)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                // Toast Notification Overlay
                if let toast = viewModel.activeToast {
                    FloatingToastView(
                        toast: toast,
                        onDismiss: {
                            viewModel.dismissToast()
                        },
                        onInspect: viewModel.activeDiagnostic != nil ? {
                            showDiagnosticSheet = true
                        } : nil
                    )
                    .padding(20)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .zIndex(100)
                }
            }
        }
        .frame(minWidth: 840, idealWidth: 980, minHeight: 560, idealHeight: 660)
        .toolbar {
            // Document Status Badge
            ToolbarItem(placement: .navigation) {
                StatusBadgeView(
                    isDirty: viewModel.isDirty,
                    dirtyCount: viewModel.configBreakdown.modifiedCount,
                    validationState: viewModel.validationState
                )
            }

            // Global Actions Group
            ToolbarItemGroup(placement: .primaryAction) {
                Button {
                    Task {
                        isValidating = true
                        await viewModel.validateCurrentDocument()
                        isValidating = false
                    }
                } label: {
                    if isValidating {
                        ProgressView().controlSize(.small)
                    } else {
                        Label("Validate", systemImage: "checkmark.shield")
                    }
                }
                .help("Validate configuration with Ghostty CLI")
                .disabled(!viewModel.cliStatus.isAvailable || isValidating)

                Button {
                    Task {
                        await viewModel.reloadFromDisk()
                    }
                } label: {
                    Label("Reload", systemImage: "arrow.clockwise")
                }
                .help("Reload configuration from disk (reverts all in-memory edits)")

                Button {
                    viewModel.openConfigurationInFinder()
                } label: {
                    Label("Reveal", systemImage: "folder")
                }
                .help("Reveal configuration in Finder")

                Button {
                    showPendingChangesSheet = true
                } label: {
                    Label("Review", systemImage: "doc.text.magnifyingglass")
                }
                .help("Review pending configuration changes before saving")
                .disabled(!viewModel.isDirty)

                Button {
                    Task {
                        _ = await viewModel.saveConfiguration()
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "square.and.arrow.down")
                        Text("Save")
                    }
                }
                .buttonStyle(.borderedProminent)
                .help("Save changes to disk with automatic validation and backup")
                .disabled(!viewModel.isDirty)
            }
        }
        .sheet(isPresented: $showPendingChangesSheet) {
            PendingChangesSheetView(isPresented: $showPendingChangesSheet)
        }
        .sheet(isPresented: $showDiagnosticSheet) {
            if let report = viewModel.activeDiagnostic {
                DiagnosticSheetView(report: report, isPresented: $showDiagnosticSheet)
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: viewModel.activeToast)
        .task {
            guard NSClassFromString("XCTestCase") == nil else { return }
            await viewModel.loadInitialData()
        }
    }
}
