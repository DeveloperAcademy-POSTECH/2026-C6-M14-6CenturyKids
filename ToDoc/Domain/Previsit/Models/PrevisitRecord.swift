//
//  PrevisitRecord.swift
//  ToDoc
//
//  Created by 앤디 on 10/30/26.
//

import Foundation
#if SWIFT_PACKAGE
import ToDocCoreErrors
#endif

nonisolated public struct PrevisitRecord: Sendable {
    public let id: UUID
    public let patientId: UUID
    public var selectedDate: Date
    public var memo: String?
    public var stateOfMind: StateOfMind
    public let submittedAt: Date
    
    public init(id: UUID, patientId: UUID, selectedDate: Date, memo: String?, stateOfMind: StateOfMind, submittedAt: Date) throws {
        try Self.validateMemo(memo)
        
        self.id = id
        self.patientId = patientId
        self.selectedDate = selectedDate
        self.memo = memo
        self.stateOfMind = stateOfMind
        self.submittedAt = submittedAt
    }
    
    public init(patientId: UUID, selectedDate: Date, memo: String?, stateOfMind: StateOfMind) throws {
        try Self.validateMemo(memo)
        
        try self.init(
            id: UUID(),
            patientId: patientId,
            selectedDate: selectedDate,
            memo: memo,
            stateOfMind: stateOfMind,
            submittedAt: .now
        )
    }
    
    public mutating func updateSelectedDate(_ date: Date) throws {
        guard date <= .now else {
            throw DateValidationError.futureDate
        }

        self.selectedDate = date
    }
    
    public mutating func updateMemo(_ memo: String?) throws {
        try Self.validateMemo(memo)
        
        let trimmed = memo?.trimmingCharacters(in: .whitespacesAndNewlines)
        
        self.memo = (trimmed?.isEmpty == true) ? nil : trimmed
    }
    
    public mutating func updateStateOfMind(_ stateOfMind: StateOfMind) {
        self.stateOfMind = stateOfMind
    }
    
    private static func validateMemo(_ memo: String?) throws {
        guard let memo else { return }

        if memo.count > 200 {
            throw ValidationError.stringTooLong
        }
    }
}
