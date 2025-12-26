import Foundation

struct RobotConfig: Codable, Identifiable, Equatable, Hashable {
    let id: UUID
    var name: String
    var host: String
    var username: String?
    var password: String?
    var useSSL: Bool
    var ignoreCertificateErrors: Bool

    var baseURL: URL? {
        let scheme = useSSL ? "https" : "http"
        return URL(string: "\(scheme)://\(host)")
    }

    init(id: UUID = UUID(), name: String, host: String, username: String? = nil, password: String? = nil, useSSL: Bool = false, ignoreCertificateErrors: Bool = false) {
        self.id = id
        self.name = name
        self.host = host
        self.username = username
        self.password = password
        self.useSSL = useSSL
        self.ignoreCertificateErrors = ignoreCertificateErrors
    }

    // Custom decoder for backward compatibility with existing saved robots
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        host = try container.decode(String.self, forKey: .host)
        username = try container.decodeIfPresent(String.self, forKey: .username)
        password = try container.decodeIfPresent(String.self, forKey: .password)
        useSSL = try container.decodeIfPresent(Bool.self, forKey: .useSSL) ?? false
        ignoreCertificateErrors = try container.decodeIfPresent(Bool.self, forKey: .ignoreCertificateErrors) ?? false
    }
}
