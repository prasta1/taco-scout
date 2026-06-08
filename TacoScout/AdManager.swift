import Foundation
import Observation
import GoogleMobileAds
import AppTrackingTransparency
import UIKit
import os.log

private let logger = Logger(subsystem: "com.tacoscout.app", category: "AdManager")

/// Manages Google AdMob native ads for TacoScout.
/// Handles consent (UMP/GDPR), ATT authorization, SDK init, ad loading, and caching.
@Observable
@MainActor
final class AdManager: NSObject {
    static let shared = AdManager()

    var isAdsEnabled = true
    var loadedAds: [GoogleMobileAds.NativeAd] = []

    @ObservationIgnored private var adLoader: GoogleMobileAds.AdLoader?
    @ObservationIgnored private let adUnitID: String
    @ObservationIgnored private var isLoading = false

    private static let productionAdUnitID = "ca-app-pub-1535647318722240/1255770409"
    private static let testAdUnitID = "ca-app-pub-3940256099942544/3986624511" // Google's official test ID

    private override init() {
        #if DEBUG
        self.adUnitID = AdManager.testAdUnitID
        #else
        self.adUnitID = AdManager.productionAdUnitID
        #endif
        super.init()
    }

    // MARK: - Consent + ATT + SDK Init

    /// Startup sequence: ATT authorization → AdMob init.
    /// Must be called once after the window hierarchy is ready.
    func requestConsentAndInitialize() async {
        // Request ATT (Apple's app tracking transparency prompt).
        // Required before AdMob can access the IDFA for personalized ads.
        if ATTrackingManager.trackingAuthorizationStatus == .notDetermined {
            logger.debug("Requesting ATT authorization...")
            _ = await ATTrackingManager.requestTrackingAuthorization()
        }

        initializeAds()
    }

    /// Initialize Google Mobile Ads SDK
    func initializeAds() {
        GoogleMobileAds.MobileAds.shared.start { status in
            logger.info("AdMob initialized: \(status.adapterStatusesByClassName.keys.joined(separator: ", "))")
        }
    }

    /// Load a batch of native ads
    func loadAds(count: Int = 5) {
        guard isAdsEnabled, !isLoading else { return }

        isLoading = true
        logger.debug("Loading \(count) native ads...")

        let options = GoogleMobileAds.MultipleAdsAdLoaderOptions()
        options.numberOfAds = count

        adLoader = GoogleMobileAds.AdLoader(
            adUnitID: adUnitID,
            rootViewController: nil,
            adTypes: [.native],
            options: [options]
        )

        adLoader?.delegate = self
        adLoader?.load(GoogleMobileAds.Request())
    }

    /// Get a cached ad if available
    func getNextAd() -> GoogleMobileAds.NativeAd? {
        guard !loadedAds.isEmpty else {
            // If we're out of ads, request more
            loadAds()
            return nil
        }
        return loadedAds.removeFirst()
    }

    /// Clear all cached ads
    func clearAds() {
        loadedAds.removeAll()
        isLoading = false
    }
}

// MARK: - NativeAdLoaderDelegate

extension AdManager: GoogleMobileAds.NativeAdLoaderDelegate {
    nonisolated func adLoader(_ adLoader: GoogleMobileAds.AdLoader, didReceive nativeAd: GoogleMobileAds.NativeAd) {
        logger.debug("✅ Native ad loaded successfully")
        Task { @MainActor in
            nativeAd.delegate = self
            self.loadedAds.append(nativeAd)
        }
    }

    nonisolated func adLoader(_ adLoader: GoogleMobileAds.AdLoader, didFailToReceiveAdWithError error: Error) {
        logger.error("❌ Failed to load ad: \(error.localizedDescription)")
        Task { @MainActor in
            self.isLoading = false
        }
    }

    nonisolated func adLoaderDidFinishLoading(_ adLoader: GoogleMobileAds.AdLoader) {
        Task { @MainActor in
            logger.info("Ad loader finished - \(self.loadedAds.count) ads cached")
            self.isLoading = false
        }
    }
}

// MARK: - NativeAdDelegate

extension AdManager: GoogleMobileAds.NativeAdDelegate {
    nonisolated func nativeAdDidRecordClick(_ nativeAd: GoogleMobileAds.NativeAd) {
        logger.debug("📊 Ad clicked")
    }

    nonisolated func nativeAdDidRecordImpression(_ nativeAd: GoogleMobileAds.NativeAd) {
        logger.debug("📊 Ad impression recorded")
    }

    nonisolated func nativeAdWillPresentScreen(_ nativeAd: GoogleMobileAds.NativeAd) {
        logger.debug("Ad will present screen")
    }

    nonisolated func nativeAdDidDismissScreen(_ nativeAd: GoogleMobileAds.NativeAd) {
        logger.debug("Ad dismissed screen")
    }
}
