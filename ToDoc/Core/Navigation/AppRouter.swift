//
//  AppRouter.swift
//  ToDoc
//
//  Created by 앤디 on 10/8/26.
//

import Observation

@MainActor
@Observable
final class AppRouter {
    var pendingDeepLink: DeepLink?
    
    func handle(_ deepLink: DeepLink) {
        pendingDeepLink = deepLink
    }
}
