//
//  MappingError.swift
//  ToDoc
//
//  Created by 앤디 on 10/13/26.
//

public enum MappingError: Error {
    case invalidBirthday(String)
    case invalidSex(String)
    case invalidCarcinomaType(String)
    case invalidCarcinomaStage(String)
    case incompleteCarcinomaDetail
}
