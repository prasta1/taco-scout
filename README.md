# 🌮 TacoScout

A delicious iOS app that helps you discover authentic taco restaurants near you using real-time location data.

**Version .33 (beta release 1)**

## ✨ Features

- **📍 Smart Location Detection**: Uses your GPS location to find nearby taco spots
- **🗺️ Interactive Map View**: Visual exploration of taco restaurants on a beautiful map
- **📋 Persistent Bottom Sheet**: Draggable sheet with peek/half/full detents, powered by UIKit pan gestures for jitter-free performance
- **⭐ Favorites System**: Save and manage your favorite taco spots with heart toggles
- **🎲 Lucky Pick**: Let the app randomly select a taco restaurant for you (with sound effects!)
- **🔍 Smart Filtering**: Filter chips for sort order, price level, open now, rating, and favorites — with pull-to-refresh
- **📸 Photo Carousel**: Floating photo viewer for restaurant images
- **🌐 Dual Data Sources**: Google Places API with Overpass API fallback
- **🔄 Landscape Support**: Adaptive layout with a left side panel in landscape orientation
- **⚙️ Settings**: Configurable defaults for search radius, sort order, filters, distance units, and sounds
- **🚗 Delivery & Directions**: Deep links to Apple Maps, DoorDash, Uber Eats, and Grubhub
- **🔎 Spotlight Search**: Quick search overlay for fast restaurant lookup
- **🌙 Dark Mode**: Full dark mode support
- **👋 Onboarding Tutorial**: Get started with an intuitive walkthrough

## 🏗️ Architecture

TacoScout uses a **dual-layer fallback architecture** to ensure you always get results:

1. **Primary: Google Places API** (Fast, Rich Data)
   - Real-time business data
   - Actual ratings and reviews
   - Photo URLs
   - Price levels
   - ~1-2 second response time

2. **Secondary: OpenStreetMap Overpass API** (Free Fallback)
   - Automatic fallback if Google Places is unavailable
   - Three different endpoints for redundancy
   - No API key required
   - Community-driven data

## 🚀 Getting Started

### Prerequisites

- iOS 17.0+
- Xcode 15.0+
- Swift 5.9+

### Installation

1. **Clone the repository**
   ```bash
   git clone https://github.com/prasta1/TacoScout-App.git
   cd TacoScout-App
   ```

2. **Open in Xcode**
   ```bash
   open TacoScout/TacoScout.xcodeproj
   ```

3. **(Optional) Configure Google Places API**
   
   For the best experience with real-time business data:
   
   - Go to [Google Cloud Console](https://console.cloud.google.com/)
   - Create a new project named "TacoScout"
   - Enable "Places API"
   - Create an API Key (restrict to iOS)
   - In Xcode:
     - Select the TacoScout target
     - Go to Build Settings
     - Search for "Info"
     - Add `GOOGLE_PLACES_API_KEY` = `your_key_here`
   
   **Note**: Google Places API is optional. Without it, the app uses Overpass API (free) automatically.

4. **Build and Run**
   - Select your simulator or device
   - Press Cmd + R to build and run

## 📁 Project Structure

```
TacoScout/
├── TacoScoutApp.swift           # App entry point
├── ContentView.swift             # Main hub — portrait/landscape adaptive layout
├── PersistentBottomSheet.swift   # UIKit-backed draggable sheet + landscape side panel
├── MapView.swift                 # MKMapView wrapper with dynamic insets
├── TacoListView.swift            # List items, empty states, loading overlays
├── TacoDetailView.swift          # Restaurant detail sheet
├── TacoService.swift             # API integration & data fetching
├── LocationManager.swift         # GPS location handling
├── FavoritesManager.swift        # Favorites persistence (UserDefaults)
├── SettingsManager.swift         # App preferences & default filters
├── SettingsView.swift            # Settings UI
├── FilterView.swift              # Search filtering UI
├── LuckyPickView.swift           # Random restaurant picker
├── SoundManager.swift            # Sound effects (lucky pick, etc.)
├── DeliveryLinkHelper.swift      # Deep links to delivery apps
├── OnboardingView.swift          # Tutorial walkthrough
├── TacoLocation.swift            # Data model
├── DistanceCalculator.swift      # Distance calculations
├── Utilities.swift               # Helper functions & extensions
└── Assets.xcassets/              # App icons, images & colors
```

## 🔑 Key Components

### TacoService
The core service that handles all taco restaurant queries with intelligent fallback logic:
```swift
searchNearbyTacos(location:radiusMeters:) -> [TacoLocation]
```

### PersistentBottomSheet
A UIKit-backed draggable sheet (`BottomSheetContainer`) that uses `UIPanGestureRecognizer` for smooth, jitter-free dragging. In landscape, it switches to a fixed 320pt side panel. Includes filter chips, pull-to-refresh, and a floating photo carousel overlay.

### ContentView
Adaptive layout hub — detects orientation via `verticalSizeClass` and branches between a portrait layout (map + bottom sheet) and a landscape layout (side panel + map in an `HStack`).

### SettingsManager
Manages all user preferences (search radius, default sort/filter, distance units, sounds) with `@AppStorage` persistence. Settings changes auto-sync to active filters on dismiss.

### LocationManager
Manages GPS permission and provides real-time location updates using the system location manager.

### FavoritesManager
Persists favorite restaurants using UserDefaults, allowing offline access to saved locations.

### DeliveryLinkHelper
Opens the best available delivery app (DoorDash, Uber Eats, Grubhub) via deep links, with a web fallback.

## 🌍 Supported Regions

The app works worldwide! It has been tested in:
- 🗽 New York
- 🏙️ San Francisco
- 🌆 Los Angeles
- 🎵 Austin, TX
- 🏔️ Cupertino
- ❄️ Burlington, VT

## 🔒 Privacy & Permissions

TacoScout respects your privacy:
- **Location**: Only used to find nearby restaurants (required for core functionality)
- **No Tracking**: Your location data is not stored or tracked
- **No Ads**: Complete ad-free experience
- **No User Analytics**: Your activity is never recorded

## 💡 Testing

### Debug Location Override
In `ContentView.swift`, you can override your location for testing:

```swift
// Uncomment one of these to test different cities:
// - San Francisco: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
// - New York: CLLocationCoordinate2D(latitude: 40.7128, longitude: -74.0060)
// - Los Angeles: CLLocationCoordinate2D(latitude: 34.0522, longitude: -118.2437)
// - Austin: CLLocationCoordinate2D(latitude: 30.2672, longitude: -97.7431)
```

## 🔄 How It Works

1. **User opens the app** → Requests location permission
2. **Location acquired** → App queries Google Places API with coordinates
3. **Google Places responds** → Displays results on map + in draggable bottom sheet
4. **No results or error?** → Automatically falls back to Overpass API
5. **User interacts** → Tap a pin or list item to select, view details, get directions, order delivery, or save to favorites
6. **Rotate to landscape** → Layout adapts to a side panel + full map view
7. **Pull to refresh** → Re-fetches nearby tacos from current location

## 🎓 Learning Resources

- [Apple MapKit Documentation](https://developer.apple.com/mapkit/)
- [Google Places API Docs](https://developers.google.com/maps/documentation/places)
- [OpenStreetMap Wiki](https://wiki.openstreetmap.org/)
- [SwiftUI Documentation](https://developer.apple.com/xcode/swiftui/)

## 📄 Additional Documentation

- [API Key Quick Start Guide](API_KEY_QUICK_START.md)
- [Google Places Setup Guide](GOOGLE_PLACES_SETUP.md)
- [Icon Setup Guide](ICON_SETUP_GUIDE.md)
- [Implementation Summary](IMPLEMENTATION_SUMMARY.md)

## 🐛 Known Issues & Limitations

- Initial app load may take 2-3 seconds due to location permission request
- Some regions have limited data in OpenStreetMap (Overpass API)
- Google Places API requires API key configuration for premium features
- Landscape layout optimized for iPhone — iPad support is planned

## 🚀 Future Enhancements

- [ ] iPad-native layout with NavigationSplitView
- [ ] Reviews and ratings from multiple sources
- [ ] Real-time crowd popularity
- [ ] Extended favorites sync across devices (CloudKit)
- [ ] Restaurant recommendations based on history
- [ ] Home screen widget

## 📱 System Requirements

| Requirement | Version |
|---|---|
| iOS | 17.0+ |
| Xcode | 15.0+ |
| Swift | 5.9+ |
| macOS (for development) | macOS 14+ |

## 🤝 Contributing

Contributions are welcome! Feel free to:
1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## 📝 License

This project is open source and available under the MIT License - see the LICENSE file for details.

## 👨‍💻 Author

**Rasta**

- GitHub: [@prasta1](https://github.com/prasta1)
- Project: [TacoScout-App](https://github.com/prasta1/TacoScout-App)

---

## 🌮 Why TacoScout?

Because the best taco is the one you haven't discovered yet. Let TacoScout guide you on delicious adventures!

**Happy taco hunting! 🌮🗺️**
