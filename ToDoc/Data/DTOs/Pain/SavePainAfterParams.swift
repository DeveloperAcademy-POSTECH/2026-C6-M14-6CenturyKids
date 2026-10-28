//
//  SavePainAfterParams.swift
//  ToDoc
//
//  Created by seokho on 10/27/26.
//

import Foundation

struct SavePainAfterParams: Encodable {
    let pId: UUID
    let pPainAfter: Int
}

extension SavePainAfterParams {
    enum CodingKeys: String, CodingKey {
        case pId = "p_id"
        case pPainAfter = "p_pain_after"
    }
}
