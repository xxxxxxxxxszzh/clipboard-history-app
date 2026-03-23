import AppKit
import Combine
import CryptoKit
import Darwin.Mach
import Foundation

struct ClipboardUsageStats {
    var itemCount: Int = 0
    var maxItems: Int = 500
    var diskBytes: Int64 = 0
    var maxDiskBytes: Int64 = 1_000_000_000
    var memoryBytes: UInt64 = 0
    var pinnedCount: Int = 0
    var textCount: Int = 0
    var imageCount: Int = 0
}

@MainActor
final class ClipboardHistoryStore: ObservableObject {
    @Published private(set) var items: [ClipboardHistoryItem] = []
    @Published var searchText = ""
    @Published var selectedItemID: UUID?
    @Published private(set) var stats = ClipboardUsageStats()

    let hotKeyDisplay = "Command + Shift + V"

    private let pasteboard = NSPasteboard.general
    private let maxItems = 500
    private let maxDiskBytes: Int64 = 1_000_000_000
    private var lastChangeCount = NSPasteboard.general.changeCount
    private var timer: Timer?
    private let fileManager = FileManager.default

    private lazy var appDirectory: URL = {
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let directory = appSupport.appendingPathComponent("ClipboardHistoryApp", isDirectory: true)
        try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }()

    private lazy var originalsDirectory: URL = {
        let directory = appDirectory.appendingPathComponent("images", isDirectory: true)
        try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }()

    private lazy var thumbnailsDirectory: URL = {
        let directory = appDirectory.appendingPathComponent("thumbs", isDirectory: true)
        try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }()

    private lazy var storageURL: URL = {
        appDirectory.appendingPathComponent("history.json")
    }()

    init() {
        load()
        enforceCleanupIfNeeded()
        refreshStats()
        startMonitoring()
    }

    var filteredItems: [ClipboardHistoryItem] {
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return items }
        return items.filter { item in
            item.title.localizedCaseInsensitiveContains(trimmed) ||
            (item.textContent?.localizedCaseInsensitiveContains(trimmed) ?? false)
        }
    }

    var selectedItem: ClipboardHistoryItem? {
        guard let selectedItemID else { return filteredItems.first ?? items.first }
        return items.first { $0.id == selectedItemID }
    }

    func startMonitoring() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.8, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.pollClipboard()
                self?.refreshStats()
            }
        }
        if let timer {
            RunLoop.main.add(timer, forMode: .common)
        }
    }

    func copy(_ item: ClipboardHistoryItem) {
        pasteboard.clearContents()

        switch item.kind {
        case .text:
            pasteboard.setString(item.textContent ?? "", forType: .string)
        case .image:
            guard let originalURL = originalURL(for: item),
                  let image = NSImage(contentsOf: originalURL) else { return }
            pasteboard.writeObjects([image])
        }

        lastChangeCount = pasteboard.changeCount
        touch(item.id)
    }

    func item(for id: UUID) -> ClipboardHistoryItem? {
        items.first { $0.id == id }
    }

    func thumbnailURL(for item: ClipboardHistoryItem) -> URL? {
        guard let relativePath = item.thumbnailRelativePath else { return nil }
        return appDirectory.appendingPathComponent(relativePath)
    }

    func originalURL(for item: ClipboardHistoryItem) -> URL? {
        guard let relativePath = item.originalRelativePath else { return nil }
        return appDirectory.appendingPathComponent(relativePath)
    }

    func delete(_ item: ClipboardHistoryItem) {
        deleteFiles(for: item)
        items.removeAll { $0.id == item.id }
        normalizeSelection()
        persistAndRefresh()
    }

    func clearUnpinned() {
        let removedItems = items.filter { !$0.isPinned }
        removedItems.forEach(deleteFiles(for:))
        items.removeAll { !$0.isPinned }
        normalizeSelection()
        persistAndRefresh()
    }

    func togglePin(_ item: ClipboardHistoryItem) {
        guard let index = items.firstIndex(where: { $0.id == item.id }) else { return }
        items[index].isPinned.toggle()
        reorderPinnedFirst()
        persistAndRefresh()
    }

    func selectNextRecent() {
        guard !filteredItems.isEmpty else { return }
        let target = filteredItems[0]
        selectedItemID = target.id
    }

    func recentItems(limit: Int) -> [ClipboardHistoryItem] {
        Array(items.prefix(limit))
    }

    func formattedDiskUsage() -> String {
        ByteCountFormatter.string(fromByteCount: stats.diskBytes, countStyle: .file)
    }

    func formattedDiskLimit() -> String {
        ByteCountFormatter.string(fromByteCount: stats.maxDiskBytes, countStyle: .file)
    }

    func formattedMemoryUsage() -> String {
        ByteCountFormatter.string(fromByteCount: Int64(stats.memoryBytes), countStyle: .memory)
    }

    private func pollClipboard() {
        guard pasteboard.changeCount != lastChangeCount else { return }
        lastChangeCount = pasteboard.changeCount

        if let text = pasteboard.string(forType: .string) {
            captureText(text)
            return
        }

        if let image = pasteboard.readObjects(forClasses: [NSImage.self], options: nil)?.first as? NSImage {
            captureImage(image)
        }
    }

    private func captureText(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let fingerprint = SHA256.hash(data: Data(trimmed.utf8)).hexString
        if let index = items.firstIndex(where: { $0.kind == .text && $0.fingerprint == fingerprint }) {
            items[index].createdAt = .now
            moveItemToFrontKeepingPin(index: index)
        } else {
            let item = ClipboardHistoryItem(
                kind: .text,
                textContent: text,
                fingerprint: fingerprint
            )
            items.insert(item, at: firstUnpinnedIndex())
            selectedItemID = item.id
        }

        reorderPinnedFirst()
        enforceCleanupIfNeeded()
        persistAndRefresh()
    }

    private func captureImage(_ image: NSImage) {
        guard let pngData = image.pngData() else { return }
        let fingerprint = SHA256.hash(data: pngData).hexString

        if let index = items.firstIndex(where: { $0.kind == .image && $0.fingerprint == fingerprint }) {
            items[index].createdAt = .now
            moveItemToFrontKeepingPin(index: index)
            reorderPinnedFirst()
            persistAndRefresh()
            return
        }

        let folderName = Self.dayFormatter.string(from: .now)
        let originalDirectory = originalsDirectory.appendingPathComponent(folderName, isDirectory: true)
        let thumbnailDirectory = thumbnailsDirectory.appendingPathComponent(folderName, isDirectory: true)

        try? fileManager.createDirectory(at: originalDirectory, withIntermediateDirectories: true)
        try? fileManager.createDirectory(at: thumbnailDirectory, withIntermediateDirectories: true)

        let imageFileName = "\(UUID().uuidString).png"
        let thumbFileName = "\(UUID().uuidString)-thumb.jpg"
        let originalURL = originalDirectory.appendingPathComponent(imageFileName)
        let thumbnailURL = thumbnailDirectory.appendingPathComponent(thumbFileName)

        do {
            try pngData.write(to: originalURL, options: .atomic)
            try createThumbnail(from: image, at: thumbnailURL)

            let metadata = ClipboardImageMetadata(
                width: Int(image.size.width),
                height: Int(image.size.height),
                fileSizeBytes: Int64(pngData.count)
            )

            let item = ClipboardHistoryItem(
                kind: .image,
                originalRelativePath: relativePath(for: originalURL),
                thumbnailRelativePath: relativePath(for: thumbnailURL),
                imageMetadata: metadata,
                fingerprint: fingerprint
            )

            items.insert(item, at: firstUnpinnedIndex())
            selectedItemID = item.id
            reorderPinnedFirst()
            enforceCleanupIfNeeded()
            persistAndRefresh()
        } catch {
            try? fileManager.removeItem(at: originalURL)
            try? fileManager.removeItem(at: thumbnailURL)
        }
    }

    private func touch(_ itemID: UUID) {
        guard let index = items.firstIndex(where: { $0.id == itemID }) else { return }
        items[index].createdAt = .now
        moveItemToFrontKeepingPin(index: index)
        reorderPinnedFirst()
        persistAndRefresh()
    }

    private func moveItemToFrontKeepingPin(index: Int) {
        let item = items.remove(at: index)
        let targetIndex = item.isPinned ? 0 : firstUnpinnedIndex()
        items.insert(item, at: targetIndex)
        selectedItemID = item.id
    }

    private func firstUnpinnedIndex() -> Int {
        items.prefix { $0.isPinned }.count
    }

    private func reorderPinnedFirst() {
        let pinned = items.filter(\.isPinned).sorted { $0.createdAt > $1.createdAt }
        let others = items.filter { !$0.isPinned }.sorted { $0.createdAt > $1.createdAt }
        items = pinned + others
        normalizeSelection()
    }

    private func normalizeSelection() {
        if let selectedItemID, items.contains(where: { $0.id == selectedItemID }) {
            return
        }
        selectedItemID = filteredItems.first?.id ?? items.first?.id
    }

    private func enforceCleanupIfNeeded() {
        reorderPinnedFirst()

        while items.count > maxItems {
            guard let removalIndex = items.lastIndex(where: { !$0.isPinned }) else { break }
            let removed = items.remove(at: removalIndex)
            deleteFiles(for: removed)
        }

        var diskBytes = directorySize(at: appDirectory)
        while diskBytes > maxDiskBytes {
            guard let removalIndex = items.lastIndex(where: { !$0.isPinned }) else { break }
            let removed = items.remove(at: removalIndex)
            deleteFiles(for: removed)
            diskBytes = directorySize(at: appDirectory)
        }
    }

    private func deleteFiles(for item: ClipboardHistoryItem) {
        if let originalURL = originalURL(for: item) {
            try? fileManager.removeItem(at: originalURL)
        }
        if let thumbnailURL = thumbnailURL(for: item) {
            try? fileManager.removeItem(at: thumbnailURL)
        }
    }

    private func load() {
        guard let data = try? Data(contentsOf: storageURL) else { return }
        guard let decoded = try? JSONDecoder().decode([ClipboardHistoryItem].self, from: data) else { return }
        items = decoded
        reorderPinnedFirst()
    }

    private func persistAndRefresh() {
        save()
        refreshStats()
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(items) else { return }
        try? data.write(to: storageURL, options: .atomic)
    }

    private func refreshStats() {
        stats = ClipboardUsageStats(
            itemCount: items.count,
            maxItems: maxItems,
            diskBytes: directorySize(at: appDirectory),
            maxDiskBytes: maxDiskBytes,
            memoryBytes: Self.memoryFootprintBytes(),
            pinnedCount: items.filter(\.isPinned).count,
            textCount: items.filter { $0.kind == .text }.count,
            imageCount: items.filter { $0.kind == .image }.count
        )
    }

    private func relativePath(for url: URL) -> String {
        url.path.replacingOccurrences(of: appDirectory.path + "/", with: "")
    }

    private func createThumbnail(from image: NSImage, at url: URL) throws {
        let maxSide: CGFloat = 240
        let sourceSize = image.size
        let scale = min(maxSide / max(sourceSize.width, 1), maxSide / max(sourceSize.height, 1), 1)
        let targetSize = NSSize(width: max(sourceSize.width * scale, 1), height: max(sourceSize.height * scale, 1))

        let thumbnail = NSImage(size: targetSize)
        thumbnail.lockFocus()
        NSGraphicsContext.current?.imageInterpolation = .high
        image.draw(in: NSRect(origin: .zero, size: targetSize))
        thumbnail.unlockFocus()

        guard let tiffData = thumbnail.tiffRepresentation,
              let imageRep = NSBitmapImageRep(data: tiffData),
              let jpegData = imageRep.representation(using: .jpeg, properties: [.compressionFactor: 0.72]) else {
            throw CocoaError(.fileWriteUnknown)
        }

        try jpegData.write(to: url, options: .atomic)
    }

    private func directorySize(at url: URL) -> Int64 {
        guard let enumerator = fileManager.enumerator(
            at: url,
            includingPropertiesForKeys: [.isRegularFileKey, .fileAllocatedSizeKey, .totalFileAllocatedSizeKey],
            options: [.skipsHiddenFiles]
        ) else {
            return 0
        }

        var total: Int64 = 0
        for case let fileURL as URL in enumerator {
            guard let values = try? fileURL.resourceValues(forKeys: [.isRegularFileKey, .fileAllocatedSizeKey, .totalFileAllocatedSizeKey]),
                  values.isRegularFile == true else {
                continue
            }
            total += Int64(values.totalFileAllocatedSize ?? values.fileAllocatedSize ?? 0)
        }
        return total
    }

    static func memoryFootprintBytes() -> UInt64 {
        var info = mach_task_basic_info_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info_data_t>.stride / MemoryLayout<natural_t>.stride)
        let result = withUnsafeMutablePointer(to: &info) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }

        guard result == KERN_SUCCESS else { return 0 }
        return UInt64(info.resident_size)
    }

    private static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
}

private extension SHA256Digest {
    var hexString: String {
        map { String(format: "%02x", $0) }.joined()
    }
}

private extension NSImage {
    func pngData() -> Data? {
        guard let tiffData = tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData) else {
            return nil
        }
        return bitmap.representation(using: .png, properties: [:])
    }
}
