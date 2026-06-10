import Foundation

struct DocumentParser {
    private let deadlineKeywords = [
        "due", "deadline", "expires", "expire", "before", "renewal", "pay by",
        "截止", "到期", "缴费", "付款", "续费", "之前"
    ]

    private let eventKeywords = [
        "appointment", "booking", "reservation", "visit", "meeting", "event",
        "预约", "会议", "活动", "就诊", "航班", "入住"
    ]

    func parse(_ text: String, defaultCurrencyCode: String = "USD") -> ParsedDocumentDraft {
        let cleanText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let title = extractTitle(from: cleanText)
        let money = extractAmountAndCurrency(from: cleanText, defaultCurrencyCode: defaultCurrencyCode)
        let dates = extractDates(from: cleanText)
        let contact = extractContact(from: cleanText)
        let category = inferCategory(from: cleanText)
        let dueDate = dates.first(where: \.isDeadline)?.date
        let eventDate = dates.first(where: { !$0.isDeadline })?.date
        let displayDate = dueDate ?? eventDate
        let reminderDate = displayDate.flatMap { Calendar.current.date(byAdding: .day, value: -1, to: $0) }
        let confidence = scoreConfidence(title: title, amount: money.amount, displayDate: displayDate, contact: contact)

        return ParsedDocumentDraft(
            title: title,
            category: category,
            amount: money.amount,
            currencyCode: money.currencyCode,
            eventDate: eventDate,
            dueDate: dueDate,
            reminderDate: reminderDate,
            phoneNumber: contact.phone,
            emailAddress: contact.email,
            location: nil,
            rawText: text,
            confidence: confidence,
            notes: ""
        )
    }

    private func extractTitle(from text: String) -> String? {
        let lines = text
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        guard let line = lines.first else { return nil }
        return String(line.prefix(80))
    }

    private func extractAmountAndCurrency(from text: String, defaultCurrencyCode: String) -> (amount: Decimal?, currencyCode: String?) {
        let keywordPattern = #"(?i)(total|amount|due|balance|price|fee|cost|合计|金额|应付|费用|缴费)[^0-9$¥€£]{0,16}([$¥€£])?\s*([0-9]+(?:,[0-9]{3})*(?:\.[0-9]{1,2})?)"#
        if let match = firstMatch(pattern: keywordPattern, in: text), match.groups.count >= 3 {
            let symbol = match.groups[1]
            let amountText = match.groups[2]
            return (parseDecimal(amountText), currencyCode(fromSymbol: symbol) ?? extractCurrencyCode(from: text) ?? defaultCurrencyCode)
        }

        let symbolPattern = #"([$¥€£])\s*([0-9]+(?:,[0-9]{3})*(?:\.[0-9]{1,2})?)"#
        if let match = firstMatch(pattern: symbolPattern, in: text), match.groups.count >= 2 {
            let symbol = match.groups[0]
            let amountText = match.groups[1]
            return (parseDecimal(amountText), currencyCode(fromSymbol: symbol) ?? defaultCurrencyCode)
        }

        return (nil, extractCurrencyCode(from: text) ?? defaultCurrencyCode)
    }

    private func parseDecimal(_ text: String) -> Decimal? {
        Decimal(string: text.replacingOccurrences(of: ",", with: ""))
    }

    private func currencyCode(fromSymbol symbol: String?) -> String? {
        switch symbol {
        case "$": return "USD"
        case "¥": return "CNY"
        case "€": return "EUR"
        case "£": return "GBP"
        default: return nil
        }
    }

    private func extractCurrencyCode(from text: String) -> String? {
        let pattern = #"\b(USD|CNY|RMB|EUR|GBP|JPY|HKD|AUD|CAD)\b"#
        guard let match = firstMatch(pattern: pattern, in: text) else { return nil }
        let code = match.groups.first?.uppercased()
        return code == "RMB" ? "CNY" : code
    }

    private struct DateCandidate {
        let date: Date
        let isDeadline: Bool
    }

    private func extractDates(from text: String) -> [DateCandidate] {
        var candidates: [(date: Date, range: NSRange)] = []
        candidates.append(contentsOf: datesMatching(
            pattern: #"\b(20\d{2})[-/.](\d{1,2})[-/.](\d{1,2})\b"#,
            text: text,
            order: [.year, .month, .day]
        ))
        candidates.append(contentsOf: datesMatching(
            pattern: #"\b(\d{1,2})[-/](\d{1,2})[-/](20\d{2})\b"#,
            text: text,
            order: [.month, .day, .year]
        ))
        candidates.append(contentsOf: datesMatching(
            pattern: #"(20\d{2})年\s*(\d{1,2})月\s*(\d{1,2})日?"#,
            text: text,
            order: [.year, .month, .day]
        ))

        return candidates
            .sorted { $0.range.location < $1.range.location }
            .map { candidate in
                let context = surroundingText(for: candidate.range, in: text).lowercased()
                return DateCandidate(
                    date: candidate.date,
                    isDeadline: deadlineKeywords.contains { context.contains($0.lowercased()) }
                )
            }
    }

    private enum DatePart {
        case year
        case month
        case day
    }

    private func datesMatching(pattern: String, text: String, order: [DatePart]) -> [(date: Date, range: NSRange)] {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let nsText = text as NSString
        let matches = regex.matches(in: text, range: NSRange(location: 0, length: nsText.length))

        return matches.compactMap { match in
            guard match.numberOfRanges >= 4 else { return nil }
            var year = 0
            var month = 0
            var day = 0

            for index in 0..<order.count {
                let value = nsText.substring(with: match.range(at: index + 1))
                switch order[index] {
                case .year: year = Int(value) ?? 0
                case .month: month = Int(value) ?? 0
                case .day: day = Int(value) ?? 0
                }
            }

            var components = DateComponents()
            components.calendar = Calendar(identifier: .gregorian)
            components.year = year
            components.month = month
            components.day = day
            guard let date = components.date else { return nil }
            return (date, match.range)
        }
    }

    private func surroundingText(for range: NSRange, in text: String) -> String {
        let nsText = text as NSString
        let start = max(0, range.location - 32)
        let end = min(nsText.length, range.location + range.length + 32)
        return nsText.substring(with: NSRange(location: start, length: end - start))
    }

    private func extractContact(from text: String) -> (phone: String?, email: String?) {
        let emailPattern = #"[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}"#
        let phonePattern = #"(?<!\d)(?:\+?\d[\d\s-]{7,}\d)(?!\d)"#
        let email = firstMatch(pattern: emailPattern, in: text, options: [.caseInsensitive])?.value
        let phone = firstMatch(pattern: phonePattern, in: text)?.value
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "-", with: "")
        return (phone, email)
    }

    private func inferCategory(from text: String) -> DocumentCategory {
        let lower = text.lowercased()
        if containsAny(lower, ["school", "tuition", "class", "student", "学校", "学费", "课程", "学生"]) {
            return .school
        }
        if containsAny(lower, ["hospital", "clinic", "doctor", "dental", "medical", "医院", "门诊", "就诊", "体检"]) {
            return .medical
        }
        if containsAny(lower, ["appointment", "reservation", "booking", "预约", "预订"]) {
            return .appointment
        }
        if containsAny(lower, ["receipt", "paid", "invoice", "发票", "收据", "已付"]) {
            return .receipt
        }
        if containsAny(lower, ["warranty", "guarantee", "保修", "质保"]) {
            return .warranty
        }
        if containsAny(lower, ["contract", "agreement", "合同", "协议"]) {
            return .contract
        }
        if containsAny(lower, ["flight", "hotel", "train", "ticket", "航班", "酒店", "火车", "机票"]) {
            return .travel
        }
        if containsAny(lower, ["bill", "payment", "due", "amount", "fee", "账单", "缴费", "费用", "应付"]) {
            return .bill
        }
        if containsAny(lower, ["notice", "deadline", "通知", "截止"]) {
            return .notice
        }
        return .other
    }

    private func containsAny(_ text: String, _ keywords: [String]) -> Bool {
        keywords.contains { text.contains($0.lowercased()) }
    }

    private func scoreConfidence(
        title: String?,
        amount: Decimal?,
        displayDate: Date?,
        contact: (phone: String?, email: String?)
    ) -> ParseConfidence {
        var score = 0
        if title?.isEmpty == false { score += 1 }
        if amount != nil { score += 1 }
        if displayDate != nil { score += 1 }
        if contact.phone != nil || contact.email != nil { score += 1 }

        if score >= 3, amount != nil || displayDate != nil {
            return .high
        }
        if score >= 2 {
            return .medium
        }
        return .low
    }

    private struct RegexMatch {
        let value: String
        let groups: [String]
    }

    private func firstMatch(
        pattern: String,
        in text: String,
        options: NSRegularExpression.Options = []
    ) -> RegexMatch? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: options) else { return nil }
        let nsText = text as NSString
        guard let match = regex.firstMatch(in: text, range: NSRange(location: 0, length: nsText.length)) else { return nil }
        let value = nsText.substring(with: match.range)
        let groups = (1..<match.numberOfRanges).map { index -> String in
            let range = match.range(at: index)
            guard range.location != NSNotFound else { return "" }
            return nsText.substring(with: range)
        }
        return RegexMatch(value: value, groups: groups)
    }
}
