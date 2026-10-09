//
//  ContentView.swift
//  ToDoc
//
//  Created by 앤디 on 10/8/26.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            Tab("홈", systemImage: "house") {
                NavigationStack {
                    HomeView()
                }
            }

            Tab("기록확인", systemImage: "list.bullet.rectangle") {
                NavigationStack {
                    RecordsView()
                }
            }

            Tab("설정", systemImage: "gearshape") {
                NavigationStack {
                    SettingsView()
                }
            }
        }
    }
}

#Preview {
    ContentView()
}
