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
    #if DEBUG
    private let authFlow: AuthFlowViewModel?
    #endif
    
    init() {
        let configuration = SupabaseConfiguration(
            url: URL(string: "https://jsvwsiiqijwrraffvatd.supabase.co")!,
                     publishableKey: "sb_publishable_R6znWnBZPpAjeKFx29gWtg_93oUMsHf"
        )
        
        let container = DependencyContainer(configuration: configuration)
        self.container = container
        #if DEBUG
        // 기본 실행에서는 인증 VM을 만들지 않습니다. 홈 화면 개발이 미완성 DB 연결에
        // 막히거나 인증 세션 정리의 영향을 받지 않도록, 명시한 개발 실행에서만 조립합니다.
        // 화면 캡처 인자가 함께 있으면 서버 연결 없는 캡처 경로를 우선합니다.
        if ProcessInfo.processInfo.arguments.contains("--auth-flow"),
           AuthScreenCaptureView.requestedScreen == nil {
            authFlow = container.makeAuthFlow()
        } else {
            authFlow = nil
        }
        #endif
    }
    
    var body: some Scene {
        WindowGroup {
            #if DEBUG
            if let screen = AuthScreenCaptureView.requestedScreen {
                AuthScreenCaptureView(screen: screen)
            } else if let authFlow {
                AuthDevelopmentRootView(authFlow: authFlow)
            } else {
                ContentView()
            }
            #else
            // Release는 개발 인자와 관계없이 기존 홈 진입을 유지합니다.
            ContentView()
            #endif
        }
    }
}
