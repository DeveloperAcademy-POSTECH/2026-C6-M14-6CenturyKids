//
//  DateOnlyFormatter.swift
//  ToDoc
//
//  Created by 앤디 on 10/14/26.
//

import Foundation

enum DateOnlyFormatter {
    static func string(from date: Date) -> String {
        makeFormatter().string(from: date)
    }

    static func date(from string: String) -> Date? {
        makeFormatter().date(from: string)
    }

    private static func makeFormatter() -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.isLenient = false
        return formatter
    }
}
