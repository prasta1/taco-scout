import SwiftUI

struct FilterView: View {
    @Binding var filter: FilterState
    @Environment(\.dismiss) var dismiss
    @Environment(SettingsManager.self) private var settingsManager
    
    var body: some View {
        NavigationStack {
            Form {
                // Sort By
                Section("Sort By") {
                    Picker("Sort", selection: $filter.sortBy) {
                        ForEach(SortOption.allCases) { option in
                            Text(option.rawValue).tag(option)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                
                // Price Filter
                Section("Price Range") {
                    HStack(spacing: 12) {
                        ForEach(PriceFilter.allCases) { price in
                            PriceButton(
                                price: price,
                                isSelected: filter.priceFilter == price
                            ) {
                                HapticManager.selection()
                                filter.priceFilter = price
                            }
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                }
                
                // Rating Filter
                Section("Minimum Rating") {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "star.fill")
                                .foregroundStyle(.orange)
                            Text(filter.minRating == 0 ? "Any" : String(format: "%.1f+", filter.minRating))
                                .fontWeight(.semibold)
                        }
                        
                        Slider(value: $filter.minRating, in: 0...5, step: 0.5) { _ in
                            HapticManager.selection()
                        }
                        .tint(.orange)
                    }
                }
                
                // Distance Filter
                Section("Maximum Distance") {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "location.circle")
                                .foregroundStyle(.blue)
                            Text("\(String(format: "%.1f", filter.maxDistance)) \(settingsManager.distanceUnit == .miles ? "miles" : "km")")
                                .fontWeight(.semibold)
                        }

                        Slider(value: $filter.maxDistance, in: 0.5...50, step: 0.5) { _ in
                            HapticManager.selection()
                        }
                        .tint(.blue)
                    }
                }
                
                // Open Now Toggle
                Section {
                    Toggle(isOn: $filter.openNowOnly) {
                        Label {
                            Text("Open Now Only")
                        } icon: {
                            Image(systemName: "clock.fill")
                                .foregroundStyle(.green)
                        }
                    }
                    .onChange(of: filter.openNowOnly) { _, _ in
                        HapticManager.selection()
                    }
                }
                
                // Reset Button
                Section {
                    Button(action: resetFilters) {
                        HStack {
                            Image(systemName: "arrow.counterclockwise")
                            Text("Reset All Filters")
                        }
                        .frame(maxWidth: .infinity)
                        .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Filters")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        HapticManager.impact(.light)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
    
    func resetFilters() {
        HapticManager.notification(.warning)
        withAnimation {
            filter = FilterState()
            filter.sortBy = settingsManager.defaultSortOrder
            filter.maxDistance = Double(settingsManager.searchRadius.rawValue)
        }
    }
}

struct PriceButton: View {
    let price: PriceFilter
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(price.label)
                .font(.headline)
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(isSelected ? Color.tacoOrange : Color(.systemGray5))
                .foregroundStyle(isSelected ? .white : .primary)
                .clipShape(RoundedRectangle(cornerRadius: Layout.radiusMedium))
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    FilterView(filter: .constant(FilterState()))
}
