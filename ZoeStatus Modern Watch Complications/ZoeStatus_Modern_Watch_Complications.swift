//
//  ZoeStatus_Modern_Watch_Complications.swift
//  ZoeStatus Modern Watch Complications
//
//  Created by Guido Mocken on 01.05.25.
//  Copyright © 2025 Dr. Guido Mocken. All rights reserved.
//

import WidgetKit
import SwiftUI
import ZEServices_Watchos


var levelCache:UInt8?
var remainingRangeCache:Float?
var last_update_cache:UInt64?


struct Provider: TimelineProvider {
    
    let sc=ServiceConnection.shared
    fileprivate func displayMessage(title: String, body: String) {
        print("Alert: \(title) \(body)")
    }

    init(){
        // known problem: when settings change -> must somehow restart the complication extensions to reload the shared settings
        print("init")
        let sharedDefaults = UserDefaults(suiteName: "group.com.grm.ZoeStatusWatch");
        sharedDefaults?.synchronize()
        let userName = sharedDefaults?.string(forKey:"userName")
        let password = sharedDefaults?.string(forKey:"password")
        // let api = sharedDefaults?.integer(forKey: "api")
        let units = sharedDefaults?.integer(forKey: "units")
        let kamereon = sharedDefaults?.string(forKey: "kamereon")
        let vehicle = sharedDefaults?.integer(forKey: "vehicle")
        // print("\(userName) \(password)")

        sc.userName = userName
        sc.password = password
        sc.api = ServiceConnection.ApiVersion(rawValue: 1 /*api!*/) // dummy value 1, which is ignored
        /* Renault is no longer using a consistent version, i.e. battery state only works as v2 and cockpit as v1. */
        sc.units = ServiceConnection.Units(rawValue: units!)
        sc.kamereon = kamereon
        sc.vehicle = vehicle
        
        if sc.userName == "simulation", sc.password == "simulation"
        {
            sc.simulation = true
        } else {
            sc.simulation = false
        }
    }
    
    
    func placeholder(in context: Context) -> SimpleEntry {
        print("placeholder for family \(context.family)") // is called at startup ... not shown anywhere?
        return SimpleEntry(date: Date(), data: dummy, widgetFamily: context.family)
    }

    func getSnapshot(in context: Context, completion: @escaping (SimpleEntry) -> ()) {
        print("getSnapshot") // preview with dummy data, is shown when adding new widget to homescreen or elsewhere
        let entry = SimpleEntry(date: .now, data: snapshot,  widgetFamily: context.family)
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
        
        
        print("getTimeline for family: \(context.family)")

        
        // local wrapper for batteryState
        func batteryState(error: Bool, charging:Bool, plugged:Bool, charge_level:UInt8, remaining_range:Float, last_update:UInt64, charging_point:String?, remaining_time:Int?, battery_temperature:Int?, vehicle_id:String?)->(){
                        
            let range:String
            let level:String
            let charger:String
            let update:String
            let chargingText: String
            let pluggedText: String
            let time: String

            if (error){
                displayMessage(title: "Error", body: "Could not obtain battery state.")
                range = "🛣️ …\u{2009}km"
                level = "🔋 …\u{2009}%"
                charger = "⛽️ …"
                update = "📅 … 🕰 …"
                time = "⏳ …"
                pluggedText = "🔌 ❌"
                chargingText = "⚡️ ❌"

            } else {
                
                level = String(format: "🔋%3d%%", charge_level)
                levelCache = charge_level
                if (remaining_range >= 0.0){
                    
                    if (sc.units == .Metric){
                        range = String(format: "🛣️ %3.0f km", remaining_range.rounded())
                    } else {
                        range = String(format: "🛣️ %3.0f mi", (remaining_range/sc.kmPerMile).rounded())
                    }
                    
                    
                } else {
                    range = String(format: "🛣️ …")
                }
                remainingRangeCache = remaining_range

                update = timestampToDateString(timestamp: last_update)
                last_update_cache = last_update
                
                if plugged, charging_point != nil {
                    charger = "⛽️ " + charging_point!
                } else {
                    charger = "⛽️ …"
                }

                if charging, remaining_time != nil {
                    time = String(format: "⏳ %d min.", remaining_time!)
                } else {
                    time = "⏳ …"
                }
                
                pluggedText = plugged ? "🔌 ✅" : "🔌 ❌"
                chargingText = charging ? "⚡️ ✅" : "⚡️ ❌"

            }

            
          

            
            let currentDate = Date()
            let data = BatteryInfo(range: range, level: level, charger: charger, charging:chargingText, plugged: pluggedText, time: time, last_update: update, percent: Int(charge_level))
            
            let last = Date(timeIntervalSince1970: Double(last_update/1000))

            var entries: [SimpleEntry] = []
            for offset in stride(from: 0, to: 15, by: 1) { // 15min with steps of 1min, all the same value (this could be extrapolated if the charge/consumption rate was known)
                let entryDate = Calendar.current.date(byAdding: .minute, value: offset, to: currentDate)!
                let entry = SimpleEntry(date: entryDate, data: data, widgetFamily: context.family)
                entries.append(entry)
            }
            
            var nextUpdate =   last.addingTimeInterval(15 * 60 + 5)
            
            if nextUpdate < Date() { // if it would lie in the past, use current date as reference
                nextUpdate = Date().addingTimeInterval(15 * 60 + 5)
            }
            
            // new timeline 15min and 5s after last update from the car (5s extra to be safe and not fetch old values again)
            print("next update of timeline after \(nextUpdate)")

            let timeline = Timeline(entries: entries, policy: .after(nextUpdate) /*.atEnd*/)
            completion(timeline)
            
        }

        
        let sharedDefaults = UserDefaults(suiteName: "group.com.grm.ZoeStatus");
        sharedDefaults?.synchronize()
        let newVehicle = sharedDefaults?.integer(forKey: "vehicle")
        if (sc.vehicle != newVehicle){
            sc.vehicle = newVehicle
            print("Never started before or vehicle was switched, forcing new login")
            sc.tokenExpiry = nil
        }


        
        // async variant
        Task {
            if (sc.tokenExpiry == nil){ // never logged in successfully
                
                let r = await sc.loginAsync()
                if (r.result){
                    let bs = await sc.batteryStateAsync()
                    batteryState(error: bs.error, charging: bs.charging, plugged: bs.plugged, charge_level: bs.charge_level, remaining_range: bs.remaining_range, last_update: bs.last_update, charging_point: bs.charging_point, remaining_time: bs.remaining_time, battery_temperature: bs.battery_temperature, vehicle_id: bs.vehicle_id)
                } else {
                    self.displayMessage(title: "Error", body:"Failed to login to MY.R. services." + " (\(r.errorMessage!))")
                    batteryState(error:true, charging: false, plugged: false, charge_level:0, remaining_range:0.0, last_update:0, charging_point: "", remaining_time: 0, battery_temperature: 0, vehicle_id:"")
                }
                
            } else {
                if sc.isTokenExpired() {
                    //print("Token expired or will expire too soon (or expiry date is nil), must renew")
                    let result = await sc.renewTokenAsync()
                    if result {
                        print("renewed expired token!")
                        let bs = await sc.batteryStateAsync()
                        batteryState(error: bs.error, charging: bs.charging, plugged: bs.plugged, charge_level: bs.charge_level, remaining_range: bs.remaining_range, last_update: bs.last_update, charging_point: bs.charging_point, remaining_time: bs.remaining_time, battery_temperature: bs.battery_temperature, vehicle_id: bs.vehicle_id)
                    } else {
                        self.displayMessage(title: "Error", body:"Failed to renew expired token.")
                        self.sc.tokenExpiry = nil // force new login next time
                        print("expired token NOT renewed!")
                        // instead of error, attempt new login right now:
                        let r = await sc.loginAsync()
                        if (r.result){
                            let bs = await sc.batteryStateAsync()
                            batteryState(error: bs.error, charging: bs.charging, plugged: bs.plugged, charge_level: bs.charge_level, remaining_range: bs.remaining_range, last_update: bs.last_update, charging_point: bs.charging_point, remaining_time: bs.remaining_time, battery_temperature: bs.battery_temperature, vehicle_id: bs.vehicle_id)

                        } else {
                            self.displayMessage(title: "Error", body:"Failed to login to MY.R. services." + " (\(r.errorMessage!))")
                        }
                    }
                    
                } else {
                    print("token still valid!")
                    
                    let bs = await sc.batteryStateAsync()
                    batteryState(error: bs.error, charging: bs.charging, plugged: bs.plugged, charge_level: bs.charge_level, remaining_range: bs.remaining_range, last_update: bs.last_update, charging_point: bs.charging_point, remaining_time: bs.remaining_time, battery_temperature: bs.battery_temperature, vehicle_id: bs.vehicle_id)
                }
            }
            
        }
        
        
    }

//    func relevances() async -> WidgetRelevances<Void> {
//        // Generate a list containing the contexts this widget is relevant in.
//    }
}



struct BatteryInfo {

    let range: String
    let level: String
    let charger: String
    let charging: String
    let plugged: String
    let time: String
    let last_update: String
    let percent: Int
}


struct SimpleEntry: TimelineEntry {
    let date: Date
    let data: BatteryInfo
    let widgetFamily: WidgetFamily

}



struct ZoeStatus_Modern_Watch_ComplicationsEntryView : View {
    var entry: Provider.Entry

    var body: some View
    {
        switch entry.widgetFamily {
        case .accessoryRectangular:
            accessoryRectangularView
        case .accessoryCorner:
            accessoryCornerView
        case .accessoryCircular:
            accessoryCircularView
        case .accessoryInline:
            accessoryInlineView
        @unknown default:
            accessoryRectangularView
        }
  }
    private var accessoryRectangularView: some View {
        VStack(alignment: .leading, spacing: 5){
            HStack{
                Text(entry.data.level + "  " + entry.data.range).minimumScaleFactor(0.5).lineLimit(1)
            }
            Text(entry.data.last_update).minimumScaleFactor(0.5).lineLimit(1)
        }
    }
    private var accessoryInlineView: some View {
        VStack {
            HStack{
                Text(entry.data.level + "   " + entry.data.range ).minimumScaleFactor(0.5).lineLimit(1) // why do two Text() not work here?
            }
        }
    }
    
    private var accessoryCircularView: some View {
        VStack {
            VStack{
                Gauge(value: Float(entry.data.percent), in: 0.0 ... 100.0) {
                    Text("ZOE")
                } currentValueLabel: {
                    // Optional: show percent if desired
                    Text( entry.data.percent < 0 ? "…" : "\(entry.data.percent)%")
                }
                .gaugeStyle(.accessoryCircular)
                .tint(entry.data.percent < 0 ? .gray : (entry.data.percent > 10 ? .green : .red) )
            }
        }
    }
    
    
    private var accessoryCornerView: some View {
        //Text("ZOE")
        Text( "\(entry.data.level)").minimumScaleFactor(0.5).lineLimit(1)
            .widgetLabel {
                Gauge(value: Float(entry.data.percent), in: 0.0 ... 100.0) {
                    Text("\(entry.data.percent)%")
                } currentValueLabel: {
                    Text("\(entry.data.percent)%")
                }.gaugeStyle(.accessoryLinearCapacity)
                    .tint(entry.data.percent < 0 ? .gray : (entry.data.percent > 10 ? .green : .red) )
                //ProgressView(value: Float(entry.data.percent), total: 100){Text("\(entry.data.percent)%")}}
            }
    }

}

@main
struct ZoeStatus_Modern_Watch_Complications: Widget {
    let kind: String = "ZoeStatus_Modern_Watch_Complications"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            if #available(watchOS 10.0, *) {
                ZoeStatus_Modern_Watch_ComplicationsEntryView(entry: entry)
                    .containerBackground(.fill.tertiary, for: .widget)
            } else {
                ZoeStatus_Modern_Watch_ComplicationsEntryView(entry: entry)
                    .padding()
                    .background()
            }
        }
        .configurationDisplayName("ZOE Status")
        .description("Displays state of charge and remaining range.")
        .supportedFamilies([.accessoryInline, .accessoryCircular, .accessoryRectangular, .accessoryCorner]) // Support all widget sizes

    }
}



let dummy = BatteryInfo(range: "🛣️ …\u{2009}km", level: "🔋…\u{2009}%", charger: "⛽️ …", charging: "⚡️ ❌", plugged: "🔌 ❌", time: "⏳ …", last_update: "📅 … 🕰 …", percent: -1)
let snapshot = BatteryInfo(range: "🛣️ 300.0\u{2009}km", level: "🔋100\u{2009}%", charger: "⛽️ 0\u{2009}kW", charging: "⚡️ ❌", plugged: "🔌 ✅", time: "⏳ 0 min.", last_update: "📅 01.02.2003 🕰 12:34:56", percent: 100)


#Preview("Rectangular", as: .accessoryRectangular) {
    ZoeStatus_Modern_Watch_Complications()
} timeline: {
    SimpleEntry(date: .now, data: snapshot, widgetFamily: .accessoryRectangular)
    SimpleEntry(date: .now, data: dummy, widgetFamily: .accessoryRectangular)
}


#Preview("Inline", as: .accessoryInline) {
    ZoeStatus_Modern_Watch_Complications()
} timeline: {
    SimpleEntry(date: .now, data: snapshot, widgetFamily: .accessoryInline)
    SimpleEntry(date: .now, data: dummy, widgetFamily: .accessoryInline)
}


#Preview("Circular", as: .accessoryCircular) {
    ZoeStatus_Modern_Watch_Complications()
} timeline: {
    SimpleEntry(date: .now, data: snapshot, widgetFamily: .accessoryCircular)
    SimpleEntry(date: .now, data: dummy, widgetFamily: .accessoryCircular)
}


#Preview("Corner", as: .accessoryCorner) {
    ZoeStatus_Modern_Watch_Complications()
} timeline: {
    SimpleEntry(date: .now, data: snapshot, widgetFamily: .accessoryCorner)
    SimpleEntry(date: .now, data: dummy, widgetFamily: .accessoryCorner)
}
