//
//  ToDocApp.swift
//  ToDoc
//
//  Created by 앤디 on 10/8/26.
//

import SwiftUI
import UserNotifications

@main
struct ToDocApp: App {
    private let analytics: AmplitudeAnalytics
    private let container: DependencyContainer
    private let router = AppRouter()
    private let notificationDelegate: LocalNotificationDelegate
    
    init() {
        let analytics = AmplitudeAnalytics()
        self.analytics = analytics
        let container = DependencyContainer(analytics: analytics)
        self.container = container
        
        notificationDelegate = LocalNotificationDelegate(router: router)
        UNUserNotificationCenter.current().delegate = notificationDelegate

    }
    
    var body: some Scene {
        WindowGroup {
            ContentView(container: container, router: router)

        }
    }
}
