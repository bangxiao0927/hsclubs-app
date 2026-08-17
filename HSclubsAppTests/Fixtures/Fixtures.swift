import Foundation

enum Fixtures {
    private static let directory = URL(fileURLWithPath: #filePath).deletingLastPathComponent()

    static func data(_ name: String) -> Data {
        let url = directory.appendingPathComponent(name)
        return try! Data(contentsOf: url)
    }
}
