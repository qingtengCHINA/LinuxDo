//
//  LinuxDoApp.swift
//  LinuxDo
//
//  Created by QingTeng on 25/5/26.
//

import SwiftUI

@main
struct LinuxDoApp: App {
    @AppStorage("appearanceMode") private var appearanceMode = 0

    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(appearanceMode == 1 ? .light : appearanceMode == 2 ? .dark : nil)
        }
    }
}