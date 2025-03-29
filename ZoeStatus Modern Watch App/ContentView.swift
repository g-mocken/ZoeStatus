//
//  ContentView.swift
//  ZoeStatus Modern Watch Watch App
//
//  Created by Guido Mocken on 26.03.25.
//  Copyright © 2025 Dr. Guido Mocken. All rights reserved.
//

import SwiftUI
import ZEServices_Watchos


struct ContentView: View {
    
    let sc=ServiceConnection.shared
    @StateObject private var sessionDelegate = SessionDelegate()

    @State private var buttonText = "Menue"
    @State private var showActionSheet = false

    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var alertTitle = ""
    @State private var alertButtonTitle = ""
    @State private var alertButtonFunction = {}
    @State var levelString = "🔋 …\u{2009}%"
    @State var rangeString = "🛣️ …\u{2009}km"
    @State var dateString = "📅 …"
    @State var timeString = "🕰 …"
    @State var chargerString = "⛽️ …"
    @State var chargingString = "⚡️ ❌"
    @State var remainingString = "⏳ …"
    @State var pluggedString = "🔌 ❌"
    
    var body: some View {
        ScrollView { // Wrap content in a ScrollView to enable scrolling
            
            VStack(alignment: .leading) { // Align text to the left in the VStack
                Text(levelString)
                Text(rangeString)
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
                
                Text("Scroll up 1!")
                Text("Scroll up 2!")
                Text("Scroll up 3!")
                
                Button(buttonText) {
                    showActionSheet.toggle() // Trigger action sheet
                }
                .buttonStyle(.bordered)
                .actionSheet(isPresented: $showActionSheet) {
                    ActionSheet(
                        title: Text("Choose an Option"),
                        message: Text("Please select an action"),
                        buttons: [
                            .default(Text("􀊞 Request new credentials")) {
                                requestNewCredentialsButtonPressed()
                            },
                            .default(Text("􀅈 Refresh")) {
                                refreshStatus()
                            },
                            .default(Text("􀇦 Trigger A/C ❌")) {
                                buttonText = "Option 1 Selected"
                                call()
                            },
                            .cancel()
                        ]
                    )
                }
            }
            .padding()
        }.onAppear(){
            print("onAppear")
            appear()
        }.alert(alertTitle, isPresented: $showAlert) {
            Button(alertButtonTitle, role: .cancel) {alertButtonFunction()}
        } message: {
            Text(alertMessage)
        }

    }
    
    
    
    
    func appear()->(){
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
        
        displayMessage(title: "Request credentials", body:"Please make sure the iOS app is launched.", button: "Go",
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
        
        showAlert = true
        alertTitle = title
        alertMessage = body
        alertButtonTitle = button
        alertButtonFunction = action
    }

}

#Preview {
    ContentView()
}

func call(){
    print("called!")
}




enum startStop {
    case start, stop
}

var activityCount: Int = 0
func updateActivity(type:startStop){

    switch type {
    case .start:
//        level.setAlpha(0.5)
//        range.setAlpha(0.5)
//        date.setAlpha(0.5)
//        time.setAlpha(0.5)
//        plugged.setAlpha(0.5)
//        charger.setAlpha(0.5)
//        remaining.setAlpha(0.5)
//        charging.setAlpha(0.5)
        activityCount+=1
        break
    case .stop:
        activityCount-=1
        if activityCount<=0 {
            if activityCount<0 {
                activityCount = 0
            }
//            level.setAlpha(1.0)
//            range.setAlpha(1.0)
//            date.setAlpha(1.0)
//            time.setAlpha(1.0)
//            plugged.setAlpha(1.0)
//            charger.setAlpha(1.0)
//            remaining.setAlpha(1.0)
//            charging.setAlpha(1.0)

        }
        break
    }
    print("Activity count = \(activityCount)")
}



