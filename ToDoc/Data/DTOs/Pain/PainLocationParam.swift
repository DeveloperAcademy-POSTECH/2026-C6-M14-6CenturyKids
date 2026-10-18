//
//  PainLocationParam.swift
//  ToDoc
//
//  Created by 앤디 on 10/18/26.
//

struct PainLocationParam: Encodable {
    let part: String
    let side: String
    let view: String
    
    init(bodyLocation: BodyLocation) {
        part = bodyLocation.bodyPart.rawValue
        side = bodyLocation.bodySide.rawValue
        view = bodyLocation.bodyView.rawValue
    }
}
