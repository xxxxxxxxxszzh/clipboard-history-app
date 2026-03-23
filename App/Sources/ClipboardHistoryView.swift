import SwiftUI

struct ClipboardHistoryView: View {
    @EnvironmentObject private var store: ClipboardHistoryStore

    var body: some View {
        VStack(spacing: 16) {
            header
            statsBar
            searchBar
            content
        }
        .padding(18)
        .frame(minWidth: 980, minHeight: 640)
        .background(
            LinearGradient(
                colors: [
                    Color(red: 0.96, green: 0.93, blue: 0.88),
                    Color(red: 0.90, green: 0.94, blue: 0.91)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Clipboard History")
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                Text("Menu bar clipboard manager with text, images, auto cleanup, and a global hotkey.")
                    .foregroundStyle(.secondary)
                Text("Hotkey: \(store.hotKeyDisplay)")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color(red: 0.55, green: 0.30, blue: 0.18))
            }

            Spacer()

            HStack(spacing: 10) {
                Button("Copy Selected") {
                    if let selected = store.selectedItem {
                        store.copy(selected)
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(Color(red: 0.82, green: 0.43, blue: 0.20))

                Button("Clear Unpinned") {
                    store.clearUnpinned()
                }
                .buttonStyle(.bordered)
            }
        }
    }

    private var statsBar: some View {
        HStack(spacing: 12) {
            StatCapsule(title: "Items", value: "\(store.stats.itemCount) / \(store.stats.maxItems)")
            StatCapsule(title: "Disk", value: "\(store.formattedDiskUsage()) / \(store.formattedDiskLimit())")
            StatCapsule(title: "Memory", value: store.formattedMemoryUsage())
            StatCapsule(title: "Pinned", value: "\(store.stats.pinnedCount)")
            StatCapsule(title: "Text", value: "\(store.stats.textCount)")
            StatCapsule(title: "Images", value: "\(store.stats.imageCount)")
            Spacer(minLength: 0)
        }
    }

    private var searchBar: some View {
        TextField("Search history", text: $store.searchText)
            .textFieldStyle(.roundedBorder)
            .font(.system(size: 14, weight: .medium, design: .rounded))
    }

    private var content: some View {
        HSplitView {
            historyList
                .frame(minWidth: 360, idealWidth: 420)
            detailPanel
                .frame(minWidth: 420)
        }
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private var historyList: some View {
        List(selection: $store.selectedItemID) {
            ForEach(store.filteredItems) { item in
                ClipboardListRow(item: item)
                    .tag(item.id)
                    .environmentObject(store)
                    .listRowInsets(EdgeInsets(top: 10, leading: 12, bottom: 10, trailing: 12))
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
            }
        }
        .scrollContentBackground(.hidden)
        .listStyle(.plain)
        .background(.white.opacity(0.60))
    }

    private var detailPanel: some View {
        ClipboardDetailView(item: store.selectedItem)
            .environmentObject(store)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(.white.opacity(0.75))
    }
}

private struct ClipboardListRow: View {
    @EnvironmentObject private var store: ClipboardHistoryStore
    let item: ClipboardHistoryItem

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            if item.kind == .image {
                ThumbnailView(item: item)
                    .frame(width: 78, height: 58)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Text(item.title)
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .lineLimit(1)
                    if item.isPinned {
                        Text("Pinned")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color(red: 0.20, green: 0.42, blue: 0.32).opacity(0.14))
                            .clipShape(Capsule())
                    }
                }

                Text(item.subtitle)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)

                if item.kind == .text {
                    Text(item.textContent ?? "")
                        .font(.system(size: 12, weight: .regular, design: .monospaced))
                        .foregroundStyle(.primary.opacity(0.78))
                        .lineLimit(2)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(12)
        .background(.white.opacity(0.85))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .contextMenu {
            Button(item.isPinned ? "Unpin" : "Pin") {
                store.togglePin(item)
            }
            Button("Copy") {
                store.copy(item)
            }
            Button("Delete") {
                store.delete(item)
            }
        }
        .onTapGesture(count: 2) {
            store.copy(item)
        }
    }
}

private struct ClipboardDetailView: View {
    @EnvironmentObject private var store: ClipboardHistoryStore
    let item: ClipboardHistoryItem?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let item {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(item.title)
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                        Text(item.subtitle)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    HStack(spacing: 8) {
                        Button(item.isPinned ? "Unpin" : "Pin") {
                            store.togglePin(item)
                        }
                        .buttonStyle(.bordered)

                        Button("Copy") {
                            store.copy(item)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(Color(red: 0.82, green: 0.43, blue: 0.20))
                    }
                }

                if item.kind == .image {
                    ImagePreview(item: item)
                } else {
                    ScrollView {
                        Text(item.textContent ?? "")
                            .font(.system(size: 14, weight: .regular, design: .monospaced))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(16)
                    }
                    .background(.white.opacity(0.85))
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                }
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Nothing selected")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                    Text("Use the global hotkey or copy some text or an image to start building your history.")
                        .foregroundStyle(.secondary)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(22)
    }
}

private struct ThumbnailView: View {
    @EnvironmentObject private var store: ClipboardHistoryStore
    let item: ClipboardHistoryItem

    var body: some View {
        Group {
            if let url = store.thumbnailURL(for: item),
               let image = NSImage(contentsOf: url) {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.black.opacity(0.07))
                    Image(systemName: "photo")
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

private struct ImagePreview: View {
    @EnvironmentObject private var store: ClipboardHistoryStore
    let item: ClipboardHistoryItem

    var body: some View {
        Group {
            if let url = store.originalURL(for: item),
               let image = NSImage(contentsOf: url) {
                GeometryReader { proxy in
                    VStack {
                        Spacer(minLength: 0)
                        Image(nsImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: proxy.size.width, maxHeight: proxy.size.height)
                        Spacer(minLength: 0)
                    }
                }
                .background(.white.opacity(0.85))
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            } else {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.black.opacity(0.06))
                    .overlay {
                        Text("Preview unavailable")
                            .foregroundStyle(.secondary)
                    }
            }
        }
    }
}

private struct StatCapsule: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title.uppercased())
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(.white.opacity(0.75))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}
