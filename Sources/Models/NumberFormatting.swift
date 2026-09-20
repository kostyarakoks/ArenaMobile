import Foundation

/// Native counterpart of resources/js/format.js's `fmtCompact` on the web app — "756", "1,7K",
/// "2,4M"-style compact formatting for resource amounts. Added because the header's resource
/// badges were showing raw integers (e.g. "12480"), which run far wider than the reference art's
/// compact numbers and were the main reason the row needed horizontal scrolling to fit
/// (reported: "надо коректировать размер шрифта, что бы все ресурсы влазили без прокрутки").
/// Russian-locale comma decimal separator to match the web default (`locale = 'ru'`); the app has
/// no locale switching today, so this mirrors that rather than reading a stored preference.
func fmtCompact(_ n: Int) -> String {
    let abs = abs(n)

    if abs >= 1_000_000 {
        return trimmed(Double(n) / 1_000_000) + "M"
    }
    if abs >= 1_000 {
        return trimmed(Double(n) / 1_000) + "K"
    }

    let formatter = NumberFormatter()
    formatter.numberStyle = .decimal
    formatter.groupingSeparator = " "
    formatter.decimalSeparator = ","
    return formatter.string(from: NSNumber(value: n)) ?? "\(n)"
}

private func trimmed(_ value: Double) -> String {
    var s = String(format: "%.1f", value)
    if s.hasSuffix(".0") {
        s = String(s.dropLast(2))
    }
    return s.replacingOccurrences(of: ".", with: ",")
}
