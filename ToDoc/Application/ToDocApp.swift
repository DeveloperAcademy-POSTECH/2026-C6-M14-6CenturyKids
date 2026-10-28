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
    private let container: DependencyContainer
    private let router = AppRouter()
    /// 알림 센터는 delegate를 약하게 잡으므로 앱이 들고 있습니다.
    private let notificationDelegate: LocalNotificationDelegate

    init() {
        let configuration = SupabaseConfiguration(
            url: URL(string: "https://jsvwsiiqijwrraffvatd.supabase.co")!,
                     publishableKey: "sb_publishable_R6znWnBZPpAjeKFx29gWtg_93oUMsHf"
        )
        
        let container = DependencyContainer(configuration: configuration)
        self.container = container

        // 알림을 눌러 앱이 켜지는 경우도 받으려면 실행이 끝나기 전에 delegate를 정해야 합니다.
        notificationDelegate = LocalNotificationDelegate(router: router)
        UNUserNotificationCenter.current().delegate = notificationDelegate
    }
    
    var body: some Scene {
        WindowGroup {
            #if DEBUG
            if let screen = AuthScreenCaptureView.requestedScreen {
                AuthScreenCaptureView(screen: screen)
            } else {
                ContentView(container: container, router: router)
            }
            #else
            ContentView(container: container, router: router)
            #endif
        }
    }
}
