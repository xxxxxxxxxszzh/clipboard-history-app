import Foundation

enum ClipboardItemKind: String, Codable {
    case text
    case image
}

struct ClipboardImageMetadata: Codable, Equatable {
    var width: Int
    var height: Int
    var fileSizeBytes: Int64
}

struct ClipboardHistoryItem: Identifiable, Codable, Equatable {
    let id: UUID
    var kind: ClipboardItemKind
    var textContent: String?
    var originalRelativePath: String?
    var thumbnailRelativePath: String?
    var imageMetadata: ClipboardImageMetadata?
    var fingerprint: String
    var createdAt: Date
    var isPinned: Bool

    init(
        id: UUID = UUID(),
        kind: ClipboardItemKind,
        textContent: String? = nil,
        originalRelativePath: String? = nil,
        thumbnailRelativePath: String? = nil,
        imageMetadata: ClipboardImageMetadata? = nil,
        fingerprint: String,
        createdAt: Date = .now,
        isPinned: Bool = false
    ) {
        self.id = id
        self.kind = kind
        self.textContent = textContent
        self.originalRelativePath = originalRelativePath
        self.thumbnailRelativePath = thumbnailRelativePath
        self.imageMetadata = imageMetadata
        self.fingerprint = fingerprint
        self.createdAt = createdAt
        self.isPinned = isPinned
    }

    var title: String {
        switch kind {
        case .text:
            let normalized = (textContent ?? "")
                .replacingOccurrences(of: "\r\n", with: "\n")
                .replacingOccurrences(of: "\r", with: "\n")
                .split(separator: "\n", omittingEmptySubsequences: false)
                .joined(separator: " ")
                .trimmingCharacters(in: .whitespacesAndNewlines)

            return normalized.isEmpty ? "(empty text)" : String(normalized.prefix(90))
        case .image:
            if let metadata = imageMetadata {
                return "Image \(metadata.width)x\(metadata.height)"
            }
            return "Image"
        }
    }

    var subtitle: String {
        switch kind {
        case .text:
            let count = textContent?.count ?? 0
            return "\(count) characters"
        case .image:
            guard let metadata = imageMetadata else { return "Image item" }
            return ByteCountFormatter.string(fromByteCount: metadata.fileSizeBytes, countStyle: .file)
        }
    }
}
