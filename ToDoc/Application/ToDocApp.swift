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
        
        container = DependencyContainer(configuration: configuration)
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
