//
//  Type_BotApp.swift
//  Type Bot
//
//  Created by Ryder Thomas on 1/9/26.
//

import SwiftUI
import ApplicationServices

@main
struct Type_BotApp: App {
    init() {
        let promptKey = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        let options = [promptKey: true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
