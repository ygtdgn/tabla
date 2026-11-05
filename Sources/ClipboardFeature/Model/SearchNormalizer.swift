import Foundation

public enum SearchNormalizer {
    public static func normalize(_ s: String) -> String {
        let tr = Locale(identifier: "tr_TR")
        return s.lowercased(with: tr)
            .folding(options: .diacriticInsensitive, locale: tr)
            .replacingOccurrences(of: "ı", with: "i")
    }
}
