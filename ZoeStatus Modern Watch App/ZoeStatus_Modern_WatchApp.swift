//
//  ZoeStatus_Modern_WatchApp.swift
//  ZoeStatus Modern Watch Watch App
//
//  Created by Guido Mocken on 26.03.25.
//  Copyright © 2025 Dr. Guido Mocken. All rights reserved.
//

import SwiftUI
//import WatchKit
//import ClockKit

@main
struct ZoeStatus_Modern_Watch_Watch_AppApp: App {
    
 //   @WKExtensionDelegateAdaptor(ExtensionDelegate.self) var extensionDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

//
//class ExtensionDelegate: NSObject, WKExtensionDelegate {
//    func applicationDidFinishLaunching() {
//        // Ensure complications update
//        CLKComplicationServer.sharedInstance().reloadComplicationDescriptors()
//    }
//}
