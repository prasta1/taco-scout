import SwiftUI

struct SettingsView: View {
    @ObservedObject var settingsManager: SettingsManager
    @Binding var showOnboarding: Bool
    @Environment(\.dismiss) private var dismiss
    @State private var showingMailError = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // Branded header
                    VStack(spacing: 6) {
                        Text("🌮")
                            .font(.system(size: 72))
                            .shadow(color: .black.opacity(0.1), radius: 4, y: 2)
                        Text("TacoScout")
                            .font(.title)
                            .fontWeight(.bold)
                        Text("Version \(appVersion)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
                    .background(
                        LinearGradient(
                            colors: [Color.tacoOrange.opacity(0.12), Color.clear],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )

                    // ── Taco Radar Card ──
                    VStack(alignment: .leading, spacing: 0) {
                        // Orange accent stripe
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.tacoOrange)
                            .frame(height: 3)
                            .padding(.horizontal, 24)
                            .padding(.top, 8)

                        // ── Taco Radar ──
                        SectionHeader(emoji: "🛰️", title: "Dial In Your Taco Radar")
                            .padding(.horizontal, 16)
                            .padding(.top, 12)
                            .padding(.bottom, 8)

                        VStack(alignment: .leading, spacing: 14) {
                            // Search Radius
                            VStack(alignment: .leading, spacing: 6) {
                                SettingsLabel("Search Radius", icon: "location.circle")
                                Picker("Search Radius", selection: $settingsManager.searchRadius) {
                                    ForEach(SearchRadius.allCases) { radius in
                                        Text(radius.label(unit: settingsManager.distanceUnit)).tag(radius)
                                    }
                                }
                                .pickerStyle(.segmented)
                            }

                            // Distance Units
                            VStack(alignment: .leading, spacing: 6) {
                                SettingsLabel("Distance Units", icon: "ruler")
                                Picker("Distance Units", selection: $settingsManager.distanceUnit) {
                                    ForEach(DistanceUnit.allCases) { unit in
                                        Text(unit.rawValue).tag(unit)
                                    }
                                }
                                .pickerStyle(.segmented)
                            }

                            // Default Sort
                            VStack(alignment: .leading, spacing: 6) {
                                SettingsLabel("Default Sort", icon: "arrow.up.arrow.down")
                                Picker("Default Sort", selection: $settingsManager.defaultSortOrder) {
                                    ForEach(SortOption.allCases) { option in
                                        Text(option.rawValue).tag(option)
                                    }
                                }
                                .pickerStyle(.segmented)
                            }

                            // Min Rating
                            VStack(alignment: .leading, spacing: 6) {
                                SettingsLabel("Min Rating", icon: "star.fill")
                                Picker("Min Rating", selection: $settingsManager.defaultMinRating) {
                                    Text("Any").tag(0.0)
                                    Text("3+").tag(3.0)
                                    Text("3.5+").tag(3.5)
                                    Text("4+").tag(4.0)
                                    Text("4.5+").tag(4.5)
                                }
                                .pickerStyle(.segmented)
                            }

                            // Price Range
                            VStack(alignment: .leading, spacing: 6) {
                                SettingsLabel("Price Range", icon: "dollarsign.circle")
                                Picker("Price Range", selection: $settingsManager.defaultPriceFilter) {
                                    ForEach(PriceFilter.allCases) { price in
                                        Text(price.label).tag(price)
                                    }
                                }
                                .pickerStyle(.segmented)
                            }

                            // Open Now
                            Toggle(isOn: $settingsManager.defaultOpenNowOnly) {
                                SettingsLabel("Open Now Only", icon: "clock")
                            }
                            .tint(.tacoOrange)
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 16)
                    }
                    .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 12))
                    .shadow(color: .black.opacity(0.08), radius: 8, y: 2)
                    .padding(.horizontal, 16)

                    // ── General Settings & About ──
                    VStack(alignment: .leading, spacing: 0) {
                        // Orange accent stripe
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.tacoOrange)
                            .frame(height: 3)
                            .padding(.horizontal, 24)
                            .padding(.top, 8)

                        SectionHeader(emoji: "🪖", title: "General Settings & About")
                            .padding(.horizontal, 16)
                            .padding(.top, 12)
                            .padding(.bottom, 8)

                        VStack(alignment: .leading, spacing: 14) {
                            Toggle(isOn: $settingsManager.hapticsEnabled) {
                                SettingsLabel("Haptic Feedback", icon: "iphone.radiowaves.left.and.right")
                            }
                            .tint(.tacoOrange)

                            Toggle(isOn: $settingsManager.soundsEnabled) {
                                SettingsLabel("In-App Sounds", icon: "speaker.wave.2")
                            }
                            .tint(.tacoOrange)

                            Button {
                                UserDefaults.standard.set(false, forKey: "hasSeenOnboarding")
                                showOnboarding = true
                                dismiss()
                            } label: {
                                SettingsLabel("Re-show Onboarding", icon: "book.pages")
                            }

                            Button(action: openFeedbackEmail) {
                                HStack {
                                    SettingsLabel("Send Feedback", icon: "envelope")
                                    Spacer()
                                    Image(systemName: "arrow.up.right.square")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }

                            Link(destination: URL(string: "https://github.com/prasta")!) {
                                HStack {
                                    SettingsLabel("GitHub", icon: "chevron.left.forwardslash.chevron.right")
                                    Spacer()
                                    Image(systemName: "arrow.up.right.square")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 16)
                    }
                    .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 12))
                    .shadow(color: .black.opacity(0.08), radius: 8, y: 2)
                    .padding(.horizontal, 16)
                }
                .padding(.bottom, 20)
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .alert("Unable to Send", isPresented: $showingMailError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Could not open your email client. Please send feedback to ruster.patrick@gmail.com")
            }
        }
    }

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    private func openFeedbackEmail() {
        let subject = "TacoScout Feedback"
            .addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let mailto = "mailto:ruster.patrick@gmail.com?subject=\(subject)"

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
}

// MARK: - Reusable Components

/// Bold, prominent section header with an emoji or SF Symbol to visually anchor each group.
private struct SectionHeader: View {
    var emoji: String?
    var icon: String?
    let title: String

    var body: some View {
        HStack(spacing: 6) {
            if let emoji {
                Text(emoji)
                    .font(.system(size: 16))
            } else if let icon {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.tacoOrange)
            }
            Text(title)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
        }
        .textCase(nil)
        .padding(.bottom, 2)
    }
}

/// Settings row label with an orange icon and secondary text.
private struct SettingsLabel: View {
    let text: String
    let icon: String

    init(_ text: String, icon: String) {
        self.text = text
        self.icon = icon
    }

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .foregroundColor(.tacoOrange)
                .font(.subheadline)
            Text(text)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }
}

#Preview {
    SettingsView(settingsManager: SettingsManager(), showOnboarding: .constant(false))
}
