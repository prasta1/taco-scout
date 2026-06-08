import SwiftUI
import MapKit

struct LuckyPickView: View {
    let taco: TacoLocation
    let userLocation: CLLocationCoordinate2D
    let onSelect: (TacoLocation) -> Void
    let onReroll: () -> Void
    @Environment(SettingsManager.self) private var settingsManager

    @State private var isRevealed = false
    @State private var rotation: Double = 0
    @State private var rollCount: Int = 0

    var body: some View {
        let distance = DistanceCalculator.distance(from: userLocation, to: taco.coordinate, unit: settingsManager.distanceUnit)

        VStack(spacing: 24) {
            // Header
            Text("🎲 I'm Feeling Lucky!")
                .font(.title2)
                .fontWeight(.bold)

            // Taco Card with Animation
            VStack(spacing: 16) {
                Text("🌮")
                    .font(.system(size: 80))
                    .rotationEffect(.degrees(rotation))
                    .onAppear {
                        spinAndReveal()
                    }

                if isRevealed {
                    VStack(spacing: 8) {
                        Text(taco.name)
                            .font(.title3)
                            .fontWeight(.bold)
                            .multilineTextAlignment(.center)

                        HStack(spacing: 12) {
                            RatingBadge(rating: taco.rating)

                            Text(taco.priceString)
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(.tacoPriceTeal)

                            Text("\(String(format: "%.1f", distance)) \(settingsManager.distanceUnit.abbreviation)")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }

                        Text(taco.cuisine)
                            .font(.caption)
                            .foregroundColor(.secondary)

                        if taco.isOpenNow {
                            OpenBadge()
                        }
                    }
                    .transition(.scale.combined(with: .opacity))
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 32)
            .background(Color(.systemGray6))
            .cornerRadius(Layout.radiusLarge)

            // Action Buttons
            if isRevealed {
                HStack(spacing: 16) {
                    Button(action: {
                        HapticManager.impact(.medium)
                        isRevealed = false
                        onReroll()
                        spinAndReveal()
                    }) {
                        HStack {
                            Image(systemName: "arrow.clockwise")
                            Text("Reroll")
                        }
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color(.systemGray5))
                        .foregroundColor(.primary)
                        .cornerRadius(Layout.radiusLarge)
                    }

                    Button(action: {
                        HapticManager.notification(.success)
                        onSelect(taco)
                    }) {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                            Text("Let's Go!")
                        }
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.tacoOrange)
                        .foregroundColor(.white)
                        .cornerRadius(Layout.radiusLarge)
                    }
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            Spacer()
        }
        .padding(Layout.paddingOuter)
    }


    private func spinAndReveal() {
        rollCount += 1
        withAnimation(.easeInOut(duration: 0.6)) {
            rotation = Double(rollCount) * 360
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            withAnimation(.bouncy) {
                isRevealed = true
            }
        }
    }
}

#Preview {
    LuckyPickView(
        taco: TacoLocation(
            id: "1",
            name: "El Farolito",
            latitude: 37.7527,
            longitude: -122.4180,
            cuisine: "Mexican Street Tacos",
            rating: 4.8,
            address: "2779 Mission St, San Francisco",
            priceLevel: 1,
            photos: [],
            reviews: [],
            hours: nil,
            phone: nil,
            website: nil
        ),
        userLocation: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
        onSelect: { _ in },
        onReroll: {}
    )
    .environment(SettingsManager())
}
