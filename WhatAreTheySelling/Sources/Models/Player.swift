
import Foundation

struct Player: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var name: String
    var isActive: Bool = true
    var allTimeScore: Int = 0
}
