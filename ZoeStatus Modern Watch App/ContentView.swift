//
//  ContentView.swift
//  ZoeStatus Modern Watch Watch App
//
//  Created by Guido Mocken on 26.03.25.
//  Copyright © 2025 Dr. Guido Mocken. All rights reserved.
//

import SwiftUI
import ZEServices_Watchos
import WidgetKit

struct CustomActionSheetView: View {
    @Binding var showSheet: Bool
    
    let onRefresh: () -> Void
    let onTriggerAirConditioning: () -> Void
    let onRequestNewCredentials: () -> Void
    
    var body: some View {
        ScrollView { // Wrap content in a ScrollView to enable scrolling
            
            VStack(spacing: 12) {
                Button(action: {
                    onRefresh()
                    showSheet = false // set to false only after the action, because displayMessage() in action depends on it
                }) {
                    HStack {
                        Text(" ")
                        Image(systemName: "arrow.clockwise")
                        Spacer()
                        Text("Refresh   ")
                    }
                }
                
                Button(action: {
                    // Perform edit
                    onTriggerAirConditioning()
                    showSheet = false // set to false only after the action, because displayMessage() in action depends on it
                }) {
                    HStack {
                        Text(" ")
                        Image(systemName: "wind.snow")
                        Spacer()
                        Text("Trigger A/C   ")
                    }
                }
                
                Button(action: {
                    onRequestNewCredentials()
                    showSheet = false // set to false only after the action, because displayMessage() in action depends on it
                }) {
                    HStack {
                        Text(" ")
                        Image(systemName: "repeat")
                        Spacer()
                        Text("Transfer credentials   ")
                    }
                }
                
            }
            .padding()
        }
    }
}

struct ContentView: View {
    
    let sc=ServiceConnection.shared
    @StateObject private var sessionDelegate = SessionDelegate()
    @StateObject private var alertManager = AlertManager.shared

    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var alertTitle = ""
    @State private var alertButtonTitle = ""
    @State private var alertButtonFunction = {}
    @State private var levelString = "🔋 …\u{2009}%"
    @State private var rangeString = "🛣️ …\u{2009}km"
    @State private var dateString = "📅 …"
    @State private var timeString = "🕰 …"
    @State private var chargerString = "⛽️ …"
    @State private var chargingString = "⚡️ ❌"
    @State private var remainingString = "⏳ …"
    @State private var pluggedString = "🔌 ❌"
    @State private var activityState = false

    @State private var showSheet = false
    @State private var triggerAlertAfterSheetOrAlert = false

    
    var body: some View {
        ZStack {
            GeometryReader { geometry in
                let availableWidth = geometry.size.width
                let fontSize = availableWidth * 0.25 // Calculate font size as a fraction of width
                
                ScrollView { // Wrap content in a ScrollView to enable scrolling
                    
                    VStack(alignment: .leading) { // Align text to the left in the VStack
                        
                        Text(levelString).font(.system(size: fontSize))
                            .minimumScaleFactor(0.5)
                            .lineLimit(1)
                        Text(rangeString).font(.system(size: fontSize))
                            .minimumScaleFactor(0.5)
                            .lineLimit(1)
                        Text(dateString)
                        Text(timeString)
                        HStack {
                            Text(chargerString)
                            Text(chargingString)
                        }
                        HStack {
                            Text(remainingString)
                            Text(pluggedString)
                        }
                        
                        Spacer().frame(height: 20) // Adds 20 points of vertical space

                        VStack {
                            Button("• • •") {
                                showSheet = true
                            }
                        }
                        .sheet(isPresented: $showSheet) {
                            CustomActionSheetView(showSheet: $showSheet, onRefresh: refreshStatus, onTriggerAirConditioning: triggerAirConditioning, onRequestNewCredentials: requestNewCredentialsButtonPressed)
                        }
                    }
                    .padding()
                    .onLongPressGesture {
                        print("long press")
                        showSheet = true
                    }
                    
                    
                                        
                }
                .disabled(activityState)
                .onAppear(){
                    print("onAppear")
                    appear()
                }
                .onChange(of: showAlert) { newValue in
                    if !newValue // when alert is gone
                    {
                        if triggerAlertAfterSheetOrAlert {
                            triggerAlertAfterSheetOrAlert = false
                            showAlert = true
                        }
                    }
                }.onChange(of: showSheet) { newValue in
                    if !newValue // when sheet is gone
                    {
                        if triggerAlertAfterSheetOrAlert {
                            triggerAlertAfterSheetOrAlert = false
                            showAlert = true
                        }
                    }
                }.alert(alertTitle, isPresented: $showAlert) {
                    Button(alertButtonTitle, role: .cancel) {alertButtonFunction()}
                } message: {
                    Text(alertMessage)
                }.alert(alertManager.title, isPresented: $alertManager.showAlert) {
                    Button(alertManager.buttonTitle, role: .cancel) {alertManager.buttonFunction()}
                } message: {
                    Text(alertManager.message)
                }
            }
            
            if activityState {
                ZStack {
                    Color.black.opacity(0.5) // Dimmed background
                        .ignoresSafeArea()
                    
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                        .scaleEffect(1.5) // Make it larger
                        .foregroundColor(.white)
                }
                .transition(.opacity)
            }
        }

    }
    
    
    
    @State private var firstRun = true
    func appear()->(){
        print("Appear")

        if firstRun { // necessary, because this method is called whenever the main screen re-appears
            firstRun = false
            print("First start")
            refreshStatus()
            
        }

        var level: UInt8?
        var range: Float?
        var dateTime: UInt64?
        var plugged: Bool?
        var chargingPoint: String?
        var remainingTime: Int?
        var charging: Bool?
        
        let cache = sc.getCache()
        
        level = cache.charge_level
        range = cache.remaining_range
        dateTime = cache.last_update
        plugged = cache.plugged
        chargingPoint = cache.charging_point
        charging = cache.charging
        remainingTime = cache.remaining_time
        
        levelString = (level != nil ? String(format: "🔋%3d %%", level!) : "🔋…")
        //        let levelShortString = (level != nil ? String(format: "%3d", level!) : "…")
        rangeString = (range != nil ? String(format: "🛣️ %3.0f km", range!.rounded()) : "🛣️ …")
        dateString = timestampToDateOnlyString(timestamp: dateTime)
        timeString = timestampToTimeOnlyString(timestamp: dateTime)
        chargerString = chargingPointToChargerString(plugged ?? false, chargingPoint)
        remainingString = remainingTimeToRemainingString(charging ?? false, remainingTime)
        pluggedString = (plugged != nil ? (plugged! ? "🔌 ✅" : "🔌 ❌") : "🔌 …")
        chargingString = (charging != nil ? (charging! ? "⚡️ ✅" : "⚡️ ❌") : "⚡️ …")

    }

    
    
    func batteryState(error: Bool, charging:Bool, plugged:Bool, charge_level:UInt8, remaining_range:Float, last_update:UInt64, charging_point:String?, remaining_time:Int?,battery_temperature:Int?,vehicle_id:String?)->(){
            
            if (error){
                displayMessage(title: "Error", body: "Could not obtain battery state.")
                
            } else {
                        
                levelString = String(format: "🔋%3d %%", charge_level)
                if (remaining_range >= 0.0){
                    if (sc.units == .Metric){
                        rangeString = String(format: "🛣️ %3.0f km", remaining_range.rounded())
                    } else {
                        rangeString = String(format: "🛣️ %3.0f mi", (remaining_range/sc.kmPerMile).rounded())
                    }

                    
                } else {
                    rangeString = String(format: "🛣️ …")
                }
                dateString = timestampToDateOnlyString(timestamp: last_update)
                timeString = timestampToTimeOnlyString(timestamp: last_update)
                chargerString = chargingPointToChargerString(plugged, charging_point)
                remainingString = remainingTimeToRemainingString(charging,remaining_time)
                pluggedString = (plugged ? "🔌 ✅" : "🔌 ❌")
                chargingString = (charging ? "⚡️ ✅" : "⚡️ ❌")
            }
            updateActivity(type:.stop)
        }
    
    
    
    func refreshStatus()->(){
        print("Refresh!")
        if #available(watchOS 10.0, *) {
            print("reload timelines triggered")

            WidgetCenter.shared.reloadAllTimelines()
        }

        if ((sc.userName == nil) || (sc.password == nil) || (sc.units == nil) ||  (sc.api == nil) ){
            displayMessage(title: "Error", body:"No user credentials present.", action: {requestNewCredentialsButtonPressed()})
        } else {
            Task {
                if await handleLoginAsync() {
                    updateActivity(type:.start)
                    let bs = await sc.batteryStateAsync()
                    batteryState(error: bs.error, charging: bs.charging, plugged: bs.plugged, charge_level: bs.charge_level, remaining_range: bs.remaining_range, last_update: bs.last_update, charging_point: bs.charging_point, remaining_time: bs.remaining_time, battery_temperature: bs.battery_temperature, vehicle_id: bs.vehicle_id)
                    // updateActivity(type:.stop)
                }
            }
        }
    }
        
    func requestNewCredentialsButtonPressed() {
        
        displayMessage(title: "Transfer credentials from iPhone", body:"Please make sure the iOS app is launched.", button: "Go",
                       action: {
            if (sessionDelegate.session.activationState == .activated) {
                if sessionDelegate.session.isReachable{
                    sessionDelegate.session.sendMessage(sessionDelegate.msg, replyHandler: sessionDelegate.replyHandler, errorHandler: sessionDelegate.errorHandler)
                } else {
                    displayMessage(title: "Error", body: "iPhone is not reachable.")
                }
            }
        })
        
    }
    
    func triggerAirConditioning() {
        
        print("A/C trigger!")
        if ((sc.userName == nil) || (sc.password == nil)){
            displayMessage(title: "Error", body:"No user credentials present.", action: {requestNewCredentialsButtonPressed()})
        } else {
            // async variant
            Task {
                if await handleLoginAsync() {
                    updateActivity(type: .start)
                    _ = await sc.preconditionAsync (command: .read, date: nil)
                    updateActivity(type:.stop)
                }
            }
        }
    }
    
    func handleLoginAsync() async -> Bool {
        
        if (sc.tokenExpiry == nil){ // never logged in successfully
            
            updateActivity(type:.start)
            let r = await sc.loginAsync()
            updateActivity(type:.stop)
            
            if (r.result){
                return true
            } else {
                displayMessage(title: "Error", body:"Failed to login to MY.R. services."  + " (\(r.errorMessage!))")
                return false
            }
        } else {
            if sc.isTokenExpired() {
                //print("Token expired or will expire too soon (or expiry date is nil), must renew")
                updateActivity(type:.start)
                let result = await sc.renewTokenAsync()
                updateActivity(type:.stop)
                
                if result {
                    print("renewed expired token!")
                    return true
                } else {
                    //displayMessage(title: "Error", body:"Failed to renew expired token.")
                    sc.tokenExpiry = nil // force new login next time
                    print("expired token NOT renewed!")

                    updateActivity(type:.start)
                    let r = await sc.loginAsync()
                    updateActivity(type:.stop)
                    
                    if (r.result){
                        return true
                    } else {
                        displayMessage(title: "Error", body:"Failed to renew expired token and to login to MY.R. services." + " (\(r.errorMessage!))")
                        return false
                    }
                }
            } else {
                print("token still valid!")
                return true
            }
        }
    }
    func displayMessage(title: String, body: String, button: String = "Dismiss",action:  @escaping  (() -> Void) = {}) {
        print("\(title): \(body)")
        if showSheet || showAlert {
            triggerAlertAfterSheetOrAlert = true
        } else {
            showAlert = true
            triggerAlertAfterSheetOrAlert = false
        }
        alertTitle = title
        alertMessage = body
        alertButtonTitle = button
        alertButtonFunction = action
    }

    
    enum startStop {
        case start, stop
    }

    @State var activityCount: Int = 0
    func updateActivity(type:startStop){

        switch type {
        case .start:
            activityState = true
            activityCount+=1
            break
        case .stop:
            activityCount-=1
            if activityCount<=0 {
                if activityCount<0 {
                    activityCount = 0
                }
                activityState = false
            }
            break
        }
        print("Activity count = \(activityCount)")
    }

}

#Preview {
    ContentView()
}





