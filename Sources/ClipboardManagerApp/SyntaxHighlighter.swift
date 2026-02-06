import AppKit
import Foundation

struct SyntaxHighlighter {
    static func attributedString(for text: String) -> AttributedString {
        let base = NSMutableAttributedString(string: text, attributes: [
            .font: NSFont.monospacedSystemFont(ofSize: NSFont.systemFontSize, weight: .regular),
            .foregroundColor: NSColor.labelColor
        ])

        apply(regex: #"(?m)^\s*//.*$"#, color: NSColor.systemGreen, to: base)
        apply(regex: #"(?m)^\s*#.*$"#, color: NSColor.systemGreen, to: base)
        apply(regex: #""([^"\\]|\\.)*""#, color: NSColor.systemOrange, to: base)
        apply(regex: #"'([^'\\]|\\.)*'"#, color: NSColor.systemOrange, to: base)
        apply(regex: #"\b(class|struct|enum|func|let|var|if|else|for|while|return|import|switch|case|break|continue|public|private|internal|open|static|final|throw|try|catch|throws|async|await)\b"#,
              color: NSColor.systemPurple,
              to: base)
        apply(regex: #"\b(true|false|nil|null)\b"#, color: NSColor.systemBlue, to: base)
        apply(regex: #"\b([0-9]+(\.[0-9]+)?)\b"#, color: NSColor.systemBlue, to: base)

        return AttributedString(base)
    }

    private static func apply(regex: String, color: NSColor, to attributed: NSMutableAttributedString) {
        guard let expression = try? NSRegularExpression(pattern: regex, options: []) else { return }
        let range = NSRange(location: 0, length: attributed.length)
        expression.enumerateMatches(in: attributed.string, options: [], range: range) { match, _, _ in
            guard let match else { return }
            attributed.addAttribute(.foregroundColor, value: color, range: match.range)
        }
    }
}
