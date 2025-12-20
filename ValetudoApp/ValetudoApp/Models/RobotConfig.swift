import Foundation

struct RobotConfig: Codable, Identifiable, Equatable, Hashable {
    let id: UUID
    var name: String
    var host: String
    var username: String?
    var password: String?

    var baseURL: URL? {
        URL(string: "http://\(host)")
    }

    init(id: UUID = UUID(), name: String, host: String, username: String? = nil, password: String? = nil) {
        self.id = id
        self.name = name
        self.host = host
        self.username = username
        self.password = password
    }
}
