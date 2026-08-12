import Foundation

/// The bundled exercise library, decoded once.
///
/// `exercises.json` is the sole home for this content — the web app is retired,
/// so there is nothing to sync it to. `tools/validate-content.js` guards it.
struct ExerciseLibrary: Sendable {
    struct Document: Codable, Sendable {
        let version: Int
        let tags: [Tag]
        let exercises: [Exercise]
    }

    static let shared = ExerciseLibrary()

    let all: [Exercise]
    private let byID: [String: Exercise]
    private let byTag: [Tag: [Exercise]]

    private init() {
        let doc = Self.loadDocument()
        all = doc.exercises
        byID = Dictionary(uniqueKeysWithValues: doc.exercises.map { ($0.id, $0) })
        byTag = Dictionary(grouping: doc.exercises, by: \.tag)
    }

    subscript(id: String) -> Exercise? { byID[id] }

    func exercises(tagged tag: Tag) -> [Exercise] { byTag[tag] ?? [] }

    /// Tags are sorted before the pools are concatenated.
    ///
    /// This is load-bearing, not tidiness: callers pass a `Set<Tag>`, and Swift
    /// gives two sets with identical elements no guarantee of identical
    /// iteration order. Feeding an unsorted pool into the plan generator's
    /// seeded shuffle made the "same seed, same session" property quietly false.
    func exercises(taggedAnyOf tags: some Sequence<Tag>) -> [Exercise] {
        tags.sorted().flatMap { exercises(tagged: $0) }
    }

    /// The library is a compile-time asset: if it is missing or malformed the
    /// app has nothing to show, so fail loudly rather than limping along.
    private static func loadDocument() -> Document {
        let bundle = Bundle(for: BundleToken.self)
        let url = bundle.url(forResource: "exercises", withExtension: "json")
            ?? Bundle.main.url(forResource: "exercises", withExtension: "json")
        guard let url else {
            fatalError("exercises.json is missing from the app bundle")
        }
        do {
            return try JSONDecoder().decode(Document.self, from: Data(contentsOf: url))
        } catch {
            fatalError("exercises.json could not be decoded: \(error)")
        }
    }
}

private final class BundleToken {}
