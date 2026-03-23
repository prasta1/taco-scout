import SwiftUI
import GoogleMobileAds

/// SwiftUI wrapper for Google AdMob Native Ad
/// Renders inline with taco list items in a non-intrusive way
struct NativeAdView: UIViewRepresentable {
    let nativeAd: GADNativeAd
    
    func makeUIView(context: Context) -> GADNativeAdView {
        let adView = GADNativeAdView()
        
        // Create a compact, tasteful layout that matches TacoListItemView
        let containerView = createAdLayout()
        adView.addSubview(containerView)
        
        // Constraint the container to fill the ad view
        containerView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            containerView.topAnchor.constraint(equalTo: adView.topAnchor),
            containerView.leadingAnchor.constraint(equalTo: adView.leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: adView.trailingAnchor),
            containerView.bottomAnchor.constraint(equalTo: adView.bottomAnchor)
        ])
        
        // Bind ad properties to views
        adView.nativeAd = nativeAd
        adView.headlineView = containerView.viewWithTag(1) as? UILabel
        adView.bodyView = containerView.viewWithTag(2) as? UILabel
        adView.iconView = containerView.viewWithTag(3) as? UIImageView
        adView.callToActionView = containerView.viewWithTag(4) as? UIButton
        
        return adView
    }
    
    func updateUIView(_ uiView: GADNativeAdView, context: Context) {
        // Update if needed
    }
    
    private func createAdLayout() -> UIView {
        let container = UIView()
        container.backgroundColor = UIColor.secondarySystemBackground
        container.layer.cornerRadius = 10
        container.clipsToBounds = true
        
        // "Sponsored" badge
        let sponsoredBadge = UILabel()
        sponsoredBadge.text = "SPONSORED"
        sponsoredBadge.font = UIFont.systemFont(ofSize: 10, weight: .bold)
        sponsoredBadge.textColor = .white
        sponsoredBadge.backgroundColor = UIColor(red: 1.0, green: 0.54, blue: 0.0, alpha: 1.0) // tacoOrange
        sponsoredBadge.textAlignment = .center
        sponsoredBadge.layer.cornerRadius = 3
        sponsoredBadge.clipsToBounds = true
        sponsoredBadge.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(sponsoredBadge)
        
        // Icon (optional)
        let iconView = UIImageView()
        iconView.tag = 3
        iconView.contentMode = .scaleAspectFill
        iconView.layer.cornerRadius = 10
        iconView.clipsToBounds = true
        iconView.backgroundColor = .systemGray5
        iconView.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(iconView)
        
        // Headline
        let headlineLabel = UILabel()
        headlineLabel.tag = 1
        headlineLabel.font = UIFont.systemFont(ofSize: 16, weight: .semibold)
        headlineLabel.numberOfLines = 1
        headlineLabel.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(headlineLabel)
        
        // Body text
        let bodyLabel = UILabel()
        bodyLabel.tag = 2
        bodyLabel.font = UIFont.systemFont(ofSize: 13, weight: .regular)
        bodyLabel.textColor = .secondaryLabel
        bodyLabel.numberOfLines = 2
        bodyLabel.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(bodyLabel)
        
        // Call to action button
        let ctaButton = UIButton(type: .system)
        ctaButton.tag = 4
        ctaButton.titleLabel?.font = UIFont.systemFont(ofSize: 14, weight: .semibold)
        ctaButton.backgroundColor = UIColor(red: 0.2, green: 0.78, blue: 0.35, alpha: 1.0) // tacoGreen
        ctaButton.setTitleColor(.white, for: .normal)
        ctaButton.layer.cornerRadius = 8
        ctaButton.contentEdgeInsets = UIEdgeInsets(top: 8, left: 16, bottom: 8, right: 16)
        ctaButton.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(ctaButton)
        
        // Layout constraints - mimicking TacoListItemView style
        NSLayoutConstraint.activate([
            // Sponsored badge - top right
            sponsoredBadge.topAnchor.constraint(equalTo: container.topAnchor, constant: 8),
            sponsoredBadge.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -8),
            sponsoredBadge.widthAnchor.constraint(equalToConstant: 75),
            sponsoredBadge.heightAnchor.constraint(equalToConstant: 16),
            
            // Icon
            iconView.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 12),
            iconView.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 60),
            iconView.heightAnchor.constraint(equalToConstant: 60),
            
            // Headline
            headlineLabel.topAnchor.constraint(equalTo: container.topAnchor, constant: 12),
            headlineLabel.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 12),
            headlineLabel.trailingAnchor.constraint(equalTo: sponsoredBadge.leadingAnchor, constant: -8),
            
            // Body
            bodyLabel.topAnchor.constraint(equalTo: headlineLabel.bottomAnchor, constant: 4),
            bodyLabel.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 12),
            bodyLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -12),
            
            // CTA Button
            ctaButton.topAnchor.constraint(equalTo: bodyLabel.bottomAnchor, constant: 8),
            ctaButton.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 12),
            ctaButton.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -12),
            ctaButton.heightAnchor.constraint(equalToConstant: 36)
        ])
        
        // Populate with ad data
        if let headline = nativeAd.headline {
            headlineLabel.text = headline
        }
        if let body = nativeAd.body {
            bodyLabel.text = body
        }
        if let icon = nativeAd.icon {
            iconView.image = icon.image
        }
        if let cta = nativeAd.callToAction {
            ctaButton.setTitle(cta, for: .normal)
        }
        
        return container
    }
}

/// Wrapper to make native ads identifiable in lists
struct AdItem: Identifiable {
    let id = UUID()
    let nativeAd: GADNativeAd
}
