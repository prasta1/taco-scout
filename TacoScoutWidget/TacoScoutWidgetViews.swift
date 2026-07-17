import SwiftUI
import WidgetKit
import CoreLocation

// MARK: - Small Widget (Lucky Pick)

struct SmallTacoWidgetView: View {
    let entry: TacoWidgetEntry

    var body: some View {
        VStack(spacing: 8) {
            Text("🌮")
                .font(.system(size: 48))
            Text("Feelin' lucky,\npunk?")
                .font(.caption)
                .fontWeight(.semibold)
                .multilineTextAlignment(.center)
                .foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .containerBackground(for: .widget) {
            LinearGradient(
                colors: [Color.tacoOrange, Color.tacoYellow],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
        // Link is ignored in systemSmall — widgetURL is the only tap target there
        .widgetURL(URL(string: "tacoscout://lucky"))
    }
}

// MARK: - Medium Widget

struct MediumTacoWidgetView: View {
    let entry: TacoWidgetEntry

    var body: some View {
        if !entry.tacos.isEmpty, let userLocation = entry.userLocation {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text("🌮 Nearby Tacos")
                        .font(.headline)
                    Spacer()
                }
                .padding(.bottom, 8)

                ForEach(Array(entry.tacos.enumerated()), id: \.element.id) { index, taco in
                    let dist = DistanceCalculator.distance(from: userLocation, to: taco.coordinate, unit: entry.distanceUnit)

                    HStack {
                        Text(taco.name)
                            .font(.subheadline)
                            .lineLimit(1)
                        Spacer()
                        HStack(spacing: 2) {
                            Image(systemName: "star.fill")
                                .font(.caption2)
                                .foregroundStyle(.orange)
                            Text(String(format: "%.1f", taco.rating))
                                .font(.caption2)
                                .fontWeight(.semibold)
                        }
                        Text(taco.priceString)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .frame(width: 28, alignment: .center)
                        Text("\(String(format: "%.1f", dist)) \(entry.distanceUnit.abbreviation)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .frame(width: 50, alignment: .trailing)
                    }

                    if index < entry.tacos.count - 1 {
                        Divider()
                            .padding(.vertical, 2)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .containerBackground(for: .widget) {
                Color(.systemBackground)
            }
        } else {
            HStack(spacing: 12) {
                Text("🌮")
                    .font(.system(size: 50))
                VStack(alignment: .leading, spacing: 4) {
                    Text("Taco Scout")
                        .font(.headline)
                    Text("Open the app to find tacos nearby")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .containerBackground(for: .widget) {
                Color(.systemBackground)
            }
        }
    }
}
