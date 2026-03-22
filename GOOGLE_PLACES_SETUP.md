# Google Places API Setup Guide

## Overview

TacoScout now uses **Google Places API as the primary data source** with **OpenStreetMap Overpass API as an automatic fallback**. This hybrid approach provides:

- **Reliable, high-quality data** from Google (ratings, photos, real business info)
- **Zero-cost fallback** via Overpass when Google fails or API key is missing
- **Automatic fallback chain**: Google Places → Overpass API (3 endpoints) → Demo data

## Cost Estimate

- **Google Places API**: ~$7-17 per 1,000 queries (based on typical usage)
- **Overpass API**: FREE (fallback)
- **First-time setup**: Need a Google Cloud project with billing enabled

## Setup Instructions

### Step 1: Create Google Cloud Project

1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Click the project dropdown and select "NEW PROJECT"
3. Name it "TacoScout"
4. Click CREATE

### Step 2: Enable Places API

1. In the Google Cloud Console, search for "Places API"
2. Select "Places API" from the results
3. Click ENABLE
4. Wait for the API to enable (usually takes 1-2 minutes)

### Step 3: Create API Key

1. Go to [Credentials page](https://console.cloud.google.com/apis/credentials)
2. Click "CREATE CREDENTIALS" → "API Key"
3. A dialog will show your new API key (copy this!)
4. Restrict the key:
   - Click on your new key in the credentials list
   - Under "Key restrictions", select "iOS apps"
   - Click "Add an item" and add your bundle identifier
   - Under "API restrictions", select "Places API"
   - Click SAVE

### Step 4: Add API Key to Your App

You have two options:

#### Option A: Info.plist (Recommended for Development)

1. Open `TacoScout.xcodeproj` in Xcode
2. Select the TacoScout target
3. Select the "Info" tab
4. Add a new property:
   - Key: `GOOGLE_PLACES_API_KEY`
   - Type: String
   - Value: (paste your API key from Step 3)
5. Save and rebuild the app

#### Option B: Environment Variable

```bash
export GOOGLE_PLACES_API_KEY="YOUR_API_KEY_HERE"
```

Then rebuild the app in Xcode.

### Step 5: Verify It's Working

1. Build and run the app
2. Open TacoScout and use your current location or change the `debugLocationOverride` in ContentView.swift to test
3. Check the Xcode console output for log messages:
   - ✅ "Attempting Google Places API query..." → API key is configured
   - ✅ "Successfully fetched X tacos from Google Places API" → Working!
   - ⚠️ "Google Places API key not configured..." → API key not found (will use Overpass API instead)

## Architecture

### API Selection Flow

```
searchNearbyTacos()
  ↓
  1. Try Google Places API
     ├─ If API key configured → Query Google Places
     ├─ If returns results → Use them ✅
     └─ If fails/no results → Continue
  ↓
  2. Try Overpass API (3 endpoints)
     ├─ Try endpoint 1 (overpass-api.de)
     ├─ Try endpoint 2 (overpass.kumi.systems)
     ├─ Try endpoint 3 (z.overpass-api.de)
     ├─ If returns results → Use them ✅
     └─ If all fail → Continue
  ↓
  3. Use demo data (tacos.json) ✅
```

## Monitoring & Debugging

### Console Output Examples

**Success with Google Places:**
```
Attempting Google Places API query...
Google Places API Response Status: 200
Successfully fetched 12 tacos from Google Places API
```

**Fallback to Overpass:**
```
Google Places API key not configured. Skipping Google Places search.
Google Places API unavailable or returned no results. Trying Overpass API...
Attempting Overpass API query (endpoint 1/3): https://overpass-api.de/api/interpreter
Successfully fetched 8 tacos from Overpass API
```

**Complete fallback to demo data:**
```
All Overpass API endpoints failed. Using demo data as fallback.
Successfully loaded 12 tacos from tacos.json
```

## Cost Management Tips

1. **Use debug location override** to test different markets without consuming API quota:
   ```swift
   // In ContentView.swift, line 27
   private let debugLocationOverride: CLLocationCoordinate2D? =
       CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194) // SF
   ```

2. **Monitor API usage** in Google Cloud Console:
   - Go to [API Dashboard](https://console.cloud.google.com/apis/dashboard)
   - Click "Places API"
   - View usage metrics and set quotas if needed

3. **Set up billing alerts**:
   - Go to [Billing](https://console.cloud.google.com/billing)
   - Set a monthly budget alert at $50-100

## Troubleshooting

### API Key Not Working

- ✅ Check API key is in Info.plist under `GOOGLE_PLACES_API_KEY`
- ✅ Verify key has Places API enabled in Google Cloud Console
- ✅ Check iOS app bundle identifier restriction matches your app
- ✅ Check network connectivity

### Getting Demo Data Instead of Google Results

Check the Xcode console logs:
- If "Attempting Google Places API query..." appears → Key is configured
- If "Google Places API Response Status:" shows non-200 → Check API key restrictions
- If no Google message appears → API key not found (add to Info.plist)

### Overpass API Rate Limiting

The app automatically tries 3 different Overpass endpoints if one is slow. If all 3 fail:
- Wait a few minutes and try again
- Or use Google Places API instead

## File Changes

### Modified Files

1. **TacoService.swift**
   - Added `searchNearbyTacosWithGooglePlaces()` - Google Places API implementation
   - Added `searchNearbyTacosWithOverpass()` - Moved Overpass logic here
   - Updated `searchNearbyTacos()` - Now implements fallback chain
   - Added `getGooglePlacesAPIKey()` - Reads from Info.plist

2. **PlacesAPIService.swift**
   - Simplified to just check if API key is configured
   - Main logic moved to TacoService for automatic fallback

## Next Steps

- **Optional:** Implement caching to reduce API costs
- **Optional:** Add place details (reviews, photos, opening hours)
- **Optional:** Implement automatic API key rotation

