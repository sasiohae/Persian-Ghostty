import SwiftUI

/// Sidebar navigation view with section icons, reactive modification badges, and Ghostty status footer.
public struct SidebarView: View {
    @Environment(AppViewModel.self) private var environmentViewModel: AppViewModel?
    @State private var fallbackViewModel = AppViewModel()

    private var viewModel: AppViewModel {
        environmentViewModel ?? fallbackViewModel
    }

    @Binding var selectedSection: NavigationSection?

    public init(selectedSection: Binding<NavigationSection?>) {
        self._selectedSection = selectedSection
    }

    public var body: some View {
        VStack(spacing: 0) {
            // MARK: - Navigation List
            List(NavigationSection.allCases, selection: $selectedSection) { section in
                NavigationLink(value: section) {
                    HStack {
                        Label(section.title, systemImage: section.iconName)
                            .font(.body)

                        Spacer()

                        // Badge indicator for pending modifications
                        if viewModel.hasModifications(for: section) {
                            let count = viewModel.modifiedCount(for: section)
                            Text("\(count)")
                                .font(.caption2.weight(.bold))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.orange.opacity(0.18))
                                .foregroundStyle(Color.orange)
                                .clipShape(Capsule())
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
            .listStyle(.sidebar)

            Divider()

            // MARK: - Status Footer
            sidebarFooter
        }
        .navigationTitle("Ghostty Persian")
    }

    // MARK: - Footer Component

    private var sidebarFooter: some View {
        VStack(alignment: .leading, spacing: 6) {
            // CLI Presence Status
            HStack(spacing: 6) {
                Circle()
                    .fill(viewModel.cliStatus.isAvailable ? Color.green : Color.orange)
                    .frame(width: 7, height: 7)

                if viewModel.cliStatus.isAvailable {
                    Text(shortGhosttyVersion)
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(Color.secondary)
                } else {
                    Text("Ghostty CLI Not Found")
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(Color.orange)
                }
                Spacer()
            }

            // Active Config Scope
            if let path = viewModel.effectivePath {
                HStack(spacing: 4) {
                    Image(systemName: "doc.text")
                        .font(.system(size: 10))
                        .foregroundStyle(Color.secondary)
                    Text(path.scope == .macOS ? "macOS Domain" : "XDG Domain")
                        .font(.system(size: 10))
                        .foregroundStyle(Color.secondary)
                    Spacer()
                    if viewModel.configExists {
                        Text("Active")
                            .font(.system(size: 9, weight: .semibold))
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(Color.green.opacity(0.15))
                            .foregroundStyle(Color.green)
                            .clipShape(RoundedRectangle(cornerRadius: 3))
                    }
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.4))
    }

    private var shortGhosttyVersion: String {
        guard let v = viewModel.cliStatus.version else { return "Ghostty Installed" }
        return v.components(separatedBy: .newlines).first ?? v
    }
}
