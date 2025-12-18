import Foundation

struct RobotMap: Codable {
    let size: MapSize?
    let pixelSize: Int?
    let layers: [MapLayer]?
    let entities: [MapEntity]?
}

struct MapSize: Codable {
    let x: Int
    let y: Int
}

struct MapLayer: Codable {
    let `__class`: String?
    let type: String?
    let pixels: [Int]?
    let compressedPixels: [Int]?
    let metaData: LayerMetaData?
    let dimensions: LayerDimensions?

    enum CodingKeys: String, CodingKey {
        case `__class`, type, pixels, compressedPixels, metaData, dimensions
    }

    /// Returns decompressed pixels - Valetudo uses run-length encoding
    /// Format: [x1, y1, count1, x2, y2, count2, ...]
    /// Each entry means: starting at (x,y), draw 'count' pixels horizontally
    var decompressedPixels: [Int] {
        // If regular pixels exist, use them
        if let pixels = pixels, !pixels.isEmpty {
            return pixels
        }

        // Otherwise decompress
        guard let compressed = compressedPixels, !compressed.isEmpty else {
            return []
        }

        var result: [Int] = []
        var i = 0

        while i < compressed.count - 2 {
            let x = compressed[i]
            let y = compressed[i + 1]
            let count = compressed[i + 2]

            // Generate pixels for this run
            for offset in 0..<count {
                result.append(x + offset)
                result.append(y)
            }

            i += 3
        }

        return result
    }
}

struct LayerMetaData: Codable {
    let segmentId: String?
    let name: String?
    let active: Bool?
}

struct LayerDimensions: Codable {
    let x: DimensionRange?
    let y: DimensionRange?
}

struct DimensionRange: Codable {
    let min: Int?
    let max: Int?
    let mid: Int?
}

struct MapEntity: Codable {
    let `__class`: String?
    let type: String?
    let points: [Int]?
    let metaData: EntityMetaData?

    enum CodingKeys: String, CodingKey {
        case `__class`, type, points, metaData
    }
}

struct EntityMetaData: Codable {
    let angle: Int?
}

// MARK: - Map Layer Types
enum MapLayerType: String {
    case floor, wall, segment
}

// MARK: - Map Entity Types
enum MapEntityType: String {
    case robotPosition = "robot_position"
    case chargerLocation = "charger_location"
    case path
    case predictedPath = "predicted_path"
    case virtualWall = "virtual_wall"
    case noGoArea = "no_go_area"
    case noMopArea = "no_mop_area"
    case goToTarget = "go_to_target"
    case activeZone = "active_zone"
}
