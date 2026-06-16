import SwiftUI
import StoreKit

struct SettingsView: View {
    @Bindable var settingsManager: SettingsManager
    @Binding var showOnboarding: Bool
    @Environment(\.dismiss) private var dismiss
    @State private var showingMailError = false

    var body: some View {
        NavigationStack {
            Form {
                // Compact brand mark
                Section {
                    Text("🌮")
                        .font(.system(size: 48))
                        .frame(maxWidth: .infinity, alignment: .center)
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                        .padding(.top, -16)
                }
                .listSectionSpacing(.compact)

                // Filter defaults
                Section("Filter Defaults") {
                    Toggle("Open Now Only", isOn: $settingsManager.defaultOpenNowOnly)

                    Picker("Search Radius", selection: $settingsManager.searchRadius) {
                        ForEach(SearchRadius.allCases) { radius in
                            Text(radius.label(unit: settingsManager.distanceUnit)).tag(radius)
                        }
                    }

                    Picker("Distance Units", selection: $settingsManager.distanceUnit) {
                        ForEach(DistanceUnit.allCases) { unit in
                            Text(unit.rawValue).tag(unit)
                        }
                    }
                    .pickerStyle(.segmented)

                    Picker("Sort By", selection: $settingsManager.defaultSortOrder) {
                        ForEach(SortOption.allCases) { option in
                            Text(option.rawValue).tag(option)
                        }
                    }

                    Picker("Minimum Rating", selection: $settingsManager.defaultMinRating) {
                        Text("Any").tag(0.0)
                        Text("3+").tag(3.0)
                        Text("3.5+").tag(3.5)
                        Text("4+").tag(4.0)
                        Text("4.5+").tag(4.5)
                    }

                    Picker("Price Range", selection: $settingsManager.defaultPriceFilter) {
                        ForEach(PriceFilter.allCases) { price in
                            Text(price.label).tag(price)
                        }
                    }

                    Button("Reset to Defaults", role: .destructive) {
                        HapticManager.notification(.warning)
                        withAnimation { settingsManager.resetFilterDefaults() }
                    }
                }

                // General preferences
                Section("General") {
                    Toggle("Haptic Feedback", isOn: $settingsManager.hapticsEnabled)
                    Toggle("In-App Sounds", isOn: $settingsManager.soundsEnabled)

                    Button("Re-show Onboarding") {
                        UserDefaults.standard.set(false, forKey: "hasSeenOnboarding")
                        showOnboarding = true
                        dismiss()
                    }

                    Link(destination: URL(string: UIApplication.openSettingsURLString)!) {
                        HStack {
                            Text("Open Location Settings")
                            Spacer()
                            Image(systemName: "arrow.up.right.square")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Link(destination: URL(string: "https://github.com/prasta1")!) {
                        HStack {
                            Text("About the Developer")
                            Spacer()
                            Image(systemName: "arrow.up.right.square")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                // Feedback
                Section {
                    Button("Report a Bug") {
                        openEmail(subject: "TacoScout Bug Report", body: bugReportBody)
                    }
                    Button("Request a Feature") {
                        openEmail(subject: "TacoScout Feature Request", body: featureRequestBody)
                    }
                    Button("Rate TacoScout", action: requestAppReview)
                } header: {
                    Text("Feedback")
                } footer: {
                    Text("TacoScout · Version \(appVersion)")
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, 4)
                }
            }
            .tint(.tacoOrange)
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .alert("Unable to Send", isPresented: $showingMailError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Could not open your email client. You can reach us at ruster.patrick@gmail.com")
            }
        }
    }

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    private var bugReportBody: String {
        """

        --- Please describe the bug below ---

        What happened:


        What I expected:


        Steps to reproduce:
        1.
        2.
        3.

        ---
        App Version: \(appVersion)
        iOS: \(UIDevice.current.systemVersion)
        Device: \(UIDevice.current.model)
        """
    }

    private var featureRequestBody: String {
        """

        --- Describe your idea below ---

        What I'd love to see:


        Why it would be useful:


        ---
        App Version: \(appVersion)
        """
    }

    private func openEmail(subject: String, body: String) {
        let encodedSubject = subject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let encodedBody = body.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let mailto = "mailto:ruster.patrick@gmail.com?subject=\(encodedSubject)&body=\(encodedBody)"

        if let url = URL(string: mailto) {
            UIApplication.shared.open(url) { success in
                if !success {
                    showingMailError = true
                }
            }
        } else {
            showingMailError = true
        }
    }

    private func requestAppReview() {
        guard let scene = UIApplication.shared.connectedScenes.first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene else { return }
        AppStore.requestReview(in: scene)
    }
}

#Preview {
    SettingsView(settingsManager: SettingsManager(), showOnboarding: .constant(false))
}
