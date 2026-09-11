import AppKit

@MainActor public protocol DesktopClient: AnyObject {
    var displays: [DisplayInfo] { get }
    func current(on display: DisplayInfo) throws -> WallpaperState
    func set(_ state: WallpaperState, on display: DisplayInfo) throws
}

public struct RecoveryRecord: Codable, Identifiable {
    public var id: String
    public var displayID: String
    public var originalURL: URL
    public var options: WallpaperOptions
    public var generatedURL: URL
    public var settings: VeilSettings
    public var width: CGFloat
    public var height: CGFloat
    public var scale: CGFloat
    public var barHeight: CGFloat
    public var pending: Bool
}

private struct Journal: Codable {
    var version = 1
    var records: [RecoveryRecord] = []
}

/// All wallpaper writes are on the main actor, as required by NSWorkspace.
/// A durable write-ahead journal is saved BEFORE changing the desktop.
@MainActor public final class WallpaperEngine {
    private let client: DesktopClient
    private let directory: URL
    private let journalURL: URL
    private var journal: Journal
    public var records: [RecoveryRecord] { journal.records }
    public var pendingCount: Int { journal.records.filter(\.pending).count }
    public var appliedDisplayIDs: Set<String> = []
    public typealias Renderer = (URL, URL, DisplayInfo, VeilSettings, WallpaperOptions) throws -> Void
    private let render: Renderer

    public init(client: DesktopClient, directory: URL,
                render: @escaping Renderer = WallpaperRenderer.render) throws {
        self.client = client; self.directory = directory; self.render = render
        journalURL = directory.appendingPathComponent("recovery.json")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        if FileManager.default.fileExists(atPath: journalURL.path) {
            do {
                journal = try JSONDecoder().decode(Journal.self, from: Data(contentsOf: journalURL))
                guard journal.version == 1 else { throw VeilError.localized(.errorJournalVersion) }
            } catch {
                // Never overwrite a damaged journal: it may be the only route back to an original.
                throw VeilError.localized(.errorJournalUnreadable, detail: error.localizedDescription)
            }
        } else { journal = Journal() }
    }

    private func save() throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(journal).write(to: journalURL, options: .atomic)
    }
    private func recordIndex(for url: URL) -> Int? {
        journal.records.firstIndex { $0.generatedURL.standardizedFileURL == url.standardizedFileURL }
    }
    private func isOwned(_ url: URL) -> Bool {
        url.deletingLastPathComponent().standardizedFileURL == directory.standardizedFileURL
            && url.lastPathComponent.hasPrefix("veil-")
    }

    /// Reconciles only the current Space on each connected display. Inactive Spaces are
    /// deliberately not manipulated through private APIs; the app calls this on Space changes.
    public func reconcile(enabled: Bool, settings: VeilSettings) -> [WallpaperFailure] {
        var errors: [WallpaperFailure] = []
        appliedDisplayIDs = []
        for display in client.displays {
            do {
                if enabled && display.isIncluded(in: settings.scope) {
                    try apply(on: display, settings: settings)
                    appliedDisplayIDs.insert(display.id)
                } else { try restore(on: display) }
            } catch { errors.append(WallpaperFailure(displayName: display.name, error: error)) }
        }
        return errors
    }

    private func apply(on display: DisplayInfo, settings: VeilSettings) throws {
        let current = try client.current(on: display)
        let previousIndex = recordIndex(for: current.url)
        if let index = previousIndex {
            let record = journal.records[index]
            if record.settings == settings && record.width == display.size.width
                && record.height == display.size.height && record.scale == display.scale
                && record.barHeight == display.barHeight(settings: settings) && record.pending {
                return
            }
        } else if isOwned(current.url) {
            throw VeilError.localized(.errorMissingRecord)
        }
        let original = previousIndex.map {
            WallpaperState(url: journal.records[$0].originalURL, options: journal.records[$0].options)
        } ?? current
        let id = UUID().uuidString
        let generated = directory.appendingPathComponent("veil-\(id).png")
        try render(original.url, generated, display, settings, original.options)
        let record = RecoveryRecord(id: id, displayID: display.id, originalURL: original.url,
                                    options: original.options, generatedURL: generated, settings: settings,
                                    width: display.size.width, height: display.size.height, scale: display.scale,
                                    barHeight: display.barHeight(settings: settings), pending: true)
        journal.records.append(record)
        try save()
        do {
            try client.set(WallpaperState(url: generated, options: .rendered), on: display)
        } catch {
            // Some APIs can apply a change and still report an error. Retain recovery if so.
            if (try? client.current(on: display).url) != generated {
                journal.records[journal.records.count - 1].pending = false
                try save()
            }
            throw error
        }
        if let previousIndex { journal.records[previousIndex].pending = false }
        try save()
    }

    private func restore(on display: DisplayInfo) throws {
        let current = try client.current(on: display)
        guard let index = recordIndex(for: current.url) else { return }
        let record = journal.records[index]
        guard FileManager.default.fileExists(atPath: record.originalURL.path) else {
            throw VeilError.localized(.errorOriginalMissing)
        }
        try client.set(WallpaperState(url: record.originalURL, options: record.options), on: display)
        journal.records[index].pending = false
        try save()
    }
}
