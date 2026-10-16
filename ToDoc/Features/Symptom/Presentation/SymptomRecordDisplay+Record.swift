//
//  SymptomRecordDisplay+Record.swift
//  ToDoc
//
//  Created by seokho on 10/14/26.
//

#if SWIFT_PACKAGE
import ToDocDomain
#endif
import Foundation

extension SymptomRecordDisplay {
    /// 저장된 증상 기록 → 화면 표시. 없음·모름도 그대로 넘기고, 화면이 presentSymptoms로 있음만 보여 준다 (#76)
    init(record: SymptomRecord) {
        self.init(id: record.id, recordedDate: record.recordedDate, symptoms: record.symptoms.map {
            SymptomEntryDisplay(id: $0.id, symptomType: $0.symptomType, presence: $0.presence, bodyPart: $0.bodyPart,
                                bodySide: $0.bodySide, rawLocationText: $0.rawLocationText, durationMinutes: $0.durationMinutes,
                                occurrenceCount: $0.occurrenceCount, detail: $0.detail)
        })
    }
}
