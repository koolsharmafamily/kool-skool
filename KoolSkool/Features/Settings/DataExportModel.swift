import Foundation
import Observation

@MainActor
@Observable
final class DataExportModel {

    enum State: Equatable, Sendable {
        case idle
        case preparing
        case ready(url: URL, summary: [ExportDocument.Line])
        case failed(String)
    }

    private let repositories: any RepositoryProvider
    private let clock: any DateProvider

    private(set) var state: State = .idle
    /// Off until switched on. Health-adjacent data only leaves the app when the
    /// person it belongs to says so.
    private(set) var includeHealthAdjacent = false

    init(repositories: any RepositoryProvider, clock: any DateProvider) {
        self.repositories = repositories
        self.clock = clock
    }

    /// A file prepared under one choice must never be shared under the other,
    /// so changing it throws the prepared file away.
    ///
    /// A method rather than a `didSet`, because property observers on an
    /// `@Observable` stored property are not dependable.
    func setIncludeHealthAdjacent(_ include: Bool) {
        guard include != includeHealthAdjacent else { return }
        includeHealthAdjacent = include
        state = .idle
    }

    func prepare() async {
        let includes = includeHealthAdjacent
        state = .preparing

        do {
            let document = try await DataExporter.document(from: repositories, includeHealthAdjacent: includes, clock: clock)
            let data = try DataExporter.encode(document)
            let url = try DataExporter.write(data, named: DataExporter.fileName(exportedAt: document.exportedAt, clock: clock))

            // Discarded if the choice changed while the file was being built.
            guard includes == includeHealthAdjacent else {
                state = .idle
                return
            }
            state = .ready(url: url, summary: document.summary)
        } catch {
            state = .failed(error.localizedDescription)
        }
    }
}
