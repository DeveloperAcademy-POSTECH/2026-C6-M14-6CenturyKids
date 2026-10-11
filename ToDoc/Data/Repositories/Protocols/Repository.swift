//
//  Repository.swift
//  ToDoc
//
//  Created by 허지우 on 10/11/26.
//

import Foundation

protocol Repository {
    associatedtype Entity

    func findById(_ id: UUID) async throws -> Entity?
    func deleteById(_ id: UUID) async throws
}
