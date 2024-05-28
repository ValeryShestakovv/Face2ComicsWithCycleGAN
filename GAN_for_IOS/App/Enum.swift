import Foundation

enum VideoEffects: String, Identifiable, CaseIterable {
    case comics = "Comics"
    case anime = "Anime"
    case simpson = "Simpson"
    case noise = "Noise"
    
    var id: String { self.rawValue }
}
