import Foundation

public struct EnvLoader {
    /// Đọc các biến môi trường từ hệ thống và ghi đè thêm bằng các giá trị từ file .env ở thư mục gốc của project.
    public static func load() -> [String: String] {
        var env: [String: String] = ProcessInfo.processInfo.environment
        
        // Cấu trúc thư mục: .../macos-swiftui-app/Sources/ArtistRevenueMacApp/Core/Utils/EnvLoader.swift
        // Lùi lại 6 cấp để ra tới gốc project
        let projectRoot = URL(fileURLWithPath: #file)
            .deletingLastPathComponent() // Utils
            .deletingLastPathComponent() // Core
            .deletingLastPathComponent() // ArtistRevenueMacApp
            .deletingLastPathComponent() // Sources
            .deletingLastPathComponent() // macos-swiftui-app
            .deletingLastPathComponent() // artist-revenue-management-project
        
        let envURL = projectRoot.appendingPathComponent(".env")
        
        guard let content = try? String(contentsOf: envURL, encoding: .utf8) else {
            return env
        }
        
        let lines = content.components(separatedBy: .newlines)
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty, !trimmed.hasPrefix("#") else { continue }
            
            let parts = trimmed.split(separator: "=", maxSplits: 1).map(String.init)
            if parts.count == 2 {
                let key = parts[0].trimmingCharacters(in: .whitespaces)
                let value = parts[1].trimmingCharacters(in: .whitespaces)
                env[key] = value
            }
        }
        return env
    }
}
