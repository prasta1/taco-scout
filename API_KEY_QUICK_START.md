# Google Places API - Quick Start (5 Minutes)

## TL;DR: Get the API Key Working

### 1. Create Google Cloud Project (2 min)
- Go to https://console.cloud.google.com/
- Create new project named "TacoScout"
- Enable "Places API"

### 2. Create API Key (1 min)
- Go to Credentials → CREATE CREDENTIALS → API Key
- Copy the key to clipboard
- Restrict to iOS apps + your bundle identifier

### 3. Add to Xcode (1 min)
- Open TacoScout.xcodeproj
- Select target "TacoScout"
- Go to Info tab
- Add new row:
  - **Key:** `GOOGLE_PLACES_API_KEY`
  - **Type:** String
  - **Value:** (paste your API key)

### 4. Build & Test (1 min)
```
Build → Run

Check Xcode console for:
✅ "Attempting Google Places API query..."
✅ "Successfully fetched X tacos from Google Places API"
```

---

## What If I Don't Have an API Key?

**The app still works!**

It automatically falls back to:
- Overpass API (free OpenStreetMap data)
- Then demo data (Burlington, VT restaurants)

No action needed.

---

## Verify It's Working

### Console Log Indicators

| Log Message | Meaning |
|-------------|---------|
| "Google Places API key not configured" | API key not found - using Overpass ✅ |
| "Attempting Google Places API query..." | API key found, trying Google ✅ |
| "Successfully fetched X tacos from Google Places API" | **Google working!** ✅✅✅ |
| "Google Places API Response Status: 403" | API key invalid or restricted ⚠️ |

---

## If Google Isn't Working

### Check 1: Is the API key in Info.plist?
```
1. Open TacoScout.xcodeproj
2. Target: TacoScout → Info tab
3. Look for GOOGLE_PLACES_API_KEY key
4. If missing → add it
```

### Check 2: Is Places API enabled in Google Cloud?
```
1. Go to console.cloud.google.com
2. Search "Places API"
3. Click it → Make sure it says "Enabled"
4. If not → Click ENABLE
```

### Check 3: Is the key restricted to iOS?
```
1. Go to console.cloud.google.com
2. Credentials page → Click your API key
3. Under "Key restrictions" → select "iOS apps"
4. Add your bundle ID (e.g., "com.yourcompany.TacoScout")
5. Under "API restrictions" → select "Places API"
6. Click SAVE
```

---

## Billing Setup (Important!)

Google Places API requires billing enabled, but you won't be charged for testing:

1. Go to https://console.cloud.google.com/billing
2. Link a payment method
3. (Optional) Set a budget alert at $50/month to avoid surprises

**Cost:** ~$0.007 per search with typical usage = $7 per 1000 searches

---

## Common Questions

**Q: Do I have to use Google Places?**
A: No! The app works perfectly fine without it. Just don't add the API key to Info.plist and it will use Overpass API (free).

**Q: Will I be charged immediately?**
A: No. Google gives free credits for new projects. You only pay after you exceed the free tier.

**Q: How do I stop being charged?**
A: Delete your API key or remove it from Info.plist. The app will automatically use free Overpass API instead.

**Q: Can I disable the API key temporarily?**
A: Yes! Just remove or comment out the `GOOGLE_PLACES_API_KEY` line in Info.plist, rebuild, and it will use Overpass API.

---

## Testing Different Locations

### Without Changing API Key

In `ContentView.swift`, line 27, you can change:

```swift
// This is for testing - comment out to use real GPS
private let debugLocationOverride: CLLocationCoordinate2D? =
    CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194) // San Francisco
```

Pre-configured locations:
```swift
CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194) // San Francisco
CLLocationCoordinate2D(latitude: 40.7128, longitude: -74.0060)  // New York
CLLocationCoordinate2D(latitude: 34.0522, longitude: -118.2437) // Los Angeles
CLLocationCoordinate2D(latitude: 41.8781, longitude: -87.6298)  // Chicago
CLLocationCoordinate2D(latitude: 30.2672, longitude: -97.7431)  // Austin
CLLocationCoordinate2D(latitude: 44.4757, longitude: -73.2130)  // Burlington, VT
```

---

## That's It!

You're done. The app now uses Google Places API with automatic fallback to Overpass/demo data.

Any questions? Check the logs in Xcode console.

