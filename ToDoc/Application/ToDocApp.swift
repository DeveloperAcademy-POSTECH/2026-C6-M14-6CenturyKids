//
//  ToDocApp.swift
//  ToDoc
//
//  Created by 앤디 on 10/8/26.
//

import SwiftUI

@main
struct ToDocApp: App {
    private let container: DependencyContainer
    
    init() {
        let configuration = SupabaseConfiguration(
            url: URL(string: "https://jsvwsiiqijwrraffvatd.supabase.co")!,
                     publishableKey: "sb_publishable_R6znWnBZPpAjeKFx29gWtg_93oUMsHf"
        )
        
        let container = DependencyContainer(configuration: configuration)
        self.container = container
        // 앱이 꺼진 채 알림을 눌렀거나 병원에 들어가 iOS가 앱을 깨웠을 때도 받도록 화면보다 먼저 연결한다
        container.localNotifications.becomeDelegate()
        container.hospitalArrivalService.start()
    }
    
    var body: some Scene {
        WindowGroup {
            #if DEBUG
            if let screen = AuthScreenCaptureView.requestedScreen {
                AuthScreenCaptureView(screen: screen)
            } else {
                ContentView(container: container)
            }
            #else
            ContentView(container: container)
            #endif
        }
    }
}
