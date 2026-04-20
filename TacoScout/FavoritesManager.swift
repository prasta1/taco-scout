import Foundation
import SwiftUI

class FavoritesManager: ObservableObject {
    @Published private(set) var favoriteIDs: Set<String>
    private let favoritesKey = "favoriteTacoIDs"
    
    init() {
        if let saved = UserDefaults.standard.array(forKey: favoritesKey) as? [String] {
            self.favoriteIDs = Set(saved)
        } else {
            self.favoriteIDs = []
        }
    }
    
    func isFavorite(_ taco: TacoLocation) -> Bool {
        favoriteIDs.contains(taco.id)
    }
    
    func toggle(_ taco: TacoLocation) {
        if favoriteIDs.contains(taco.id) {
            favoriteIDs.remove(taco.id)
        } else {
            favoriteIDs.insert(taco.id)
        }
        save()
    }
    
    private func save() {
        UserDefaults.standard.set(Array(favoriteIDs), forKey: favoritesKey)
    }
}
