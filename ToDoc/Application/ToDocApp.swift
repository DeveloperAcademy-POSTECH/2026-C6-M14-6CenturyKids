//
//  ToDocApp.swift
//  ToDoc
//
//  Created by 앤디 on 10/8/26.
//

import SwiftUI
import UserNotifications

import KakaoSDKAuth
import KakaoSDKCommon

@main
struct ToDocApp: App {
    private let container: DependencyContainer
    private let router = AppRouter()
    private let notificationDelegate: LocalNotificationDelegate
    
    init() {
        guard let supabaseURL = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_URL") as? String,
              let supabasePublishableKey = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_ANON_KEY") as? String,
              let kakaoAppKey = Bundle.main.object(forInfoDictionaryKey: "KAKAO_NATIVE_APP_KEY") as? String else {
            fatalError("Info.plist 또는 Secrets.xcconfig 설정이 누락되었습니다.")
        }
        
        let configuration = SupabaseConfiguration(
            url: URL(string: supabaseURL)!,
            publishableKey: supabasePublishableKey
        )
        
        KakaoSDK.initSDK(appKey: kakaoAppKey)
        
        
        let container = DependencyContainer(configuration: configuration)
        self.container = container
        
        notificationDelegate = LocalNotificationDelegate(router: router)
        UNUserNotificationCenter.current().delegate = notificationDelegate
        container.hospitalArrivalService.start()
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView(container: container, router: router)
        }
    }
}
