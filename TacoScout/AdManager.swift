import Foundation
import GoogleMobileAds
import os.log

private let logger = Logger(subsystem: "com.tacoscout.app", category: "AdManager")

/// Manages Google AdMob native ads for TacoScout.
/// Handles ad loading, caching, and lifecycle management.
class AdManager: NSObject, ObservableObject {
    static let shared = AdManager()
    
    @Published var isAdsEnabled = true
    @Published var loadedAds: [GADNativeAd] = []
    
    private var adLoader: GADAdLoader?
    private let adUnitID: String
    private var isLoading = false
    
    // Test Ad Unit ID from Google - replace with your own when ready
    // This is Google's official test ID for native ads
    private static let testAdUnitID = "ca-app-pub-3940256099942544/3986624511"
    
    private override init() {
        // Use test ID for now - user can replace with production ID later
        self.adUnitID = AdManager.testAdUnitID
        super.init()
    }
    
    /// Initialize Google Mobile Ads SDK
    func initializeAds() {
        GADMobileAds.sharedInstance().start { status in
            logger.info("AdMob initialized: \(status.adapterStatusesByClassName.keys.joined(separator: ", "))")
        }
    }
    
    /// Load a batch of native ads
    func loadAds(count: Int = 5) {
        guard isAdsEnabled, !isLoading else { return }
        
        isLoading = true
        logger.debug("Loading \(count) native ads...")
        
        let options = GADMultipleAdsAdLoaderOptions()
        options.numberOfAds = count
        
        adLoader = GADAdLoader(
            adUnitID: adUnitID,
            rootViewController: nil,
            adTypes: [.native],
            options: [options]
        )
        
        adLoader?.delegate = self
        adLoader?.load(GADRequest())
    }
    
    /// Get a cached ad if available
    func getNextAd() -> GADNativeAd? {
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

// MARK: - GADNativeAdLoaderDelegate

extension AdManager: GADNativeAdLoaderDelegate {
    func adLoader(_ adLoader: GADAdLoader, didReceive nativeAd: GADNativeAd) {
        logger.debug("✅ Native ad loaded successfully")
        DispatchQueue.main.async {
            self.loadedAds.append(nativeAd)
        }
    }
    
    func adLoader(_ adLoader: GADAdLoader, didFailToReceiveAdWithError error: Error) {
        logger.error("❌ Failed to load ad: \(error.localizedDescription)")
        DispatchQueue.main.async {
            self.isLoading = false
        }
    }
    
    func adLoaderDidFinishLoading(_ adLoader: GADAdLoader) {
        logger.info("Ad loader finished - \(self.loadedAds.count) ads cached")
        DispatchQueue.main.async {
            self.isLoading = false
        }
    }
}

// MARK: - GADNativeAdDelegate

extension AdManager: GADNativeAdDelegate {
    func nativeAdDidRecordClick(_ nativeAd: GADNativeAd) {
        logger.debug("📊 Ad clicked")
    }
    
    func nativeAdDidRecordImpression(_ nativeAd: GADNativeAd) {
        logger.debug("📊 Ad impression recorded")
    }
    
    func nativeAdWillPresentScreen(_ nativeAd: GADNativeAd) {
        logger.debug("Ad will present screen")
    }
    
    func nativeAdDidDismissScreen(_ nativeAd: GADNativeAd) {
        logger.debug("Ad dismissed screen")
    }
}
