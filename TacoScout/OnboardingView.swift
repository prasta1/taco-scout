import SwiftUI

struct OnboardingView: View {
    @Binding var isPresented: Bool
    @State private var currentPage = 0
    
    let pages: [(icon: String, title: String, subtitle: String)] = [
        ("🌮", "Find Tacos Fast", "Discover the best taco spots near you in seconds"),
        ("📍", "Location Matters", "We'll use your location to find nearby gems"),
        ("🎲", "Feeling Lucky?", "Can't decide? Let us pick a random winner for you"),
        ("❤️", "Save Your Favorites", "Build your personal list of go-to spots")
    ]
    
    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [.tacoOrange, .tacoYellow],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 40) {
                Spacer()
                
                // Page Content
                TabView(selection: $currentPage) {
                    ForEach(0..<pages.count, id: \.self) { index in
                        VStack(spacing: 24) {
                            Text(pages[index].icon)
                                .font(.system(size: 100))
                            
                            Text(pages[index].title)
                                .font(.largeTitle)
                                .fontWeight(.bold)
                                .foregroundStyle(.white)
                            
                            Text(pages[index].subtitle)
                                .font(.title3)
                                .foregroundStyle(.white.opacity(0.9))
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 40)
                        }
                        .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                
                // Page Indicators
                HStack(spacing: 8) {
                    ForEach(0..<pages.count, id: \.self) { index in
                        Circle()
                            .fill(currentPage == index ? Color.white : Color.white.opacity(0.4))
                            .frame(width: 10, height: 10)
                            .animation(.smooth, value: currentPage)
                    }
                }
                
                Spacer()
                
                // Continue Button
                Button(action: {
                    HapticManager.impact(.medium)
                    if currentPage < pages.count - 1 {
                        withAnimation {
                            currentPage += 1
                        }
                    } else {
                        completeOnboarding()
                    }
                }) {
                    Text(currentPage < pages.count - 1 ? "Continue" : "Get Started")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.white)
                        .foregroundStyle(Color.tacoOrange)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                }
                .padding(.horizontal, 32)
                
                // Skip Button (hidden on last page but space preserved)
                Button("Skip") {
                    completeOnboarding()
                }
                .foregroundStyle(.white.opacity(0.8))
                .opacity(currentPage < pages.count - 1 ? 1 : 0)
                .disabled(currentPage >= pages.count - 1)
                
                Spacer()
                    .frame(height: 40)
            }
        }
    }
    
    func completeOnboarding() {
        UserDefaults.standard.set(true, forKey: "hasSeenOnboarding")
        HapticManager.notification(.success)
        isPresented = false
    }
}

#Preview {
    OnboardingView(isPresented: .constant(true))
}
