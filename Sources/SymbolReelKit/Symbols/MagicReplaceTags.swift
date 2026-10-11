import Foundation

/// Lines up the layer tags of two symbols so Magic Replace keeps their shared layers in place.
///
/// Magic Replace matches layers by the tags in a template's `-sfsymbols-layer-tags`. A layer in
/// the target symbol stays in place only when the source symbol carries every tag that names where
/// the layer came from. In `video.slash`, the camera layer is tagged `video video.slash`: `video`
/// is its lineage and `video.slash` the symbol's own tag, which every one of its layers shares.
///
/// When the SF Symbols app adds a slash to a custom symbol, it also tags the base layer with the
/// custom symbol's internal ID, which no other symbol has. Unless the source is that exact custom
/// symbol, the base no longer matches: it shrinks and grows like a plain replace while only the
/// slash animates. Dropping the lineage tags the source lacks, while keeping at least one it has,
/// restores the system behavior.
enum MagicReplaceTags {
    /// The tag list of each style rule in a template, in order.
    static func tagLists(in template: Data) -> [[String]] {
        let text = String(decoding: template, as: UTF8.self)
        return text.matches(of: tagPattern).map { match in
            match.output.1.split(separator: " ").map(String.init)
        }
    }

    /// Rewrites a target template's tags to match a source with the given tags.
    static func reconcile(target template: Data, withSourceTags sourceTags: Set<String>) -> Data {
        let tagLists = tagLists(in: template).filter { !$0.isEmpty }
        guard let first = tagLists.first else { return template }

        // The symbol's own tags are the ones every layer shares.
        let ownTags = tagLists.dropFirst().reduce(Set(first)) { $0.intersection($1) }

        let text = String(decoding: template, as: UTF8.self)
        let reconciled = text.replacing(tagPattern) { match in
            let tags = match.output.1.split(separator: " ").map(String.init)
            let lineage = Set(tags).subtracting(ownTags).filter { !$0.hasPrefix("_") }
            guard !lineage.isDisjoint(with: sourceTags) else { return match.output.0 }

            let kept = tags.filter { !lineage.contains($0) || sourceTags.contains($0) }
            return "-sfsymbols-layer-tags:" + kept.joined(separator: " ")
        }
        return Data(reconciled.utf8)
    }

    nonisolated(unsafe) private static let tagPattern = #/-sfsymbols-layer-tags:([^;}]*)/#
}
