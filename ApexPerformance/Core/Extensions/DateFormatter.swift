//
//  DateFormatter.swift
//  ApexPerformance
//
//

import Foundation

extension DateFormatter {
    static let dateWithDots: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "dd.MM.yyyy"
        return f
    }()
    
    static let dateAndTimeWithDots: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "dd.MM.yyyy HH:mm:ss"
        return f
    }()    
    
    // In the app's language, which can change while it runs.
    static var dayName: DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = AppLanguage.locale
        formatter.dateFormat = "EEEE"
        return formatter
    }
}

