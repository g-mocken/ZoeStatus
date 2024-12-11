//
//  ZoeStatus_Modern_Widget.swift
//  ZoeStatus Modern Widget
//
//  Created by Guido Mocken on 06.12.24.
//  Copyright © 2024 Dr. Guido Mocken. All rights reserved.
//

import WidgetKit
import SwiftUI
import ZEServices


var levelCache:UInt8?
var remainingRangeCache:Float?
var last_update_cache:UInt64?


struct Provider: TimelineProvider {
    
    let sc=ServiceConnection.shared
    fileprivate func displayMessage(title: String, body: String) {
        print("Alert: \(title) \(body)")
    }

    init(){
        
        print("init")
        let sharedDefaults = UserDefaults(suiteName: "group.com.grm.ZoeStatus");
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
        print("placeholder") // is called at startup ... not shown anywhwere?
        return SimpleEntry(date: Date(), data: dummy, widgetFamily: context.family)

    }

    
    func getSnapshot(in context: Context, completion: @escaping (SimpleEntry) -> ()) {
        
        print("getSnapshot") // preview with dummy data, is shown when adding new widget to homescreen or elsewhere
        let entry = SimpleEntry(date: .now, data: snapshot,  widgetFamily: context.family)
        completion(entry)
    }
    
    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {

        print("getTimeline")

        
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
            let data = BatteryInfo(range: range, level: level, charger: charger, charging:chargingText, plugged: pluggedText, time: time, last_update: update)
            
            var entries: [SimpleEntry] = []
            for offset in stride(from: 0, to: 30, by: 1) { // 30min with steps of 1min
                let entryDate = Calendar.current.date(byAdding: .minute, value: offset, to: currentDate)!
                let entry = SimpleEntry(date: entryDate, data: data, widgetFamily: context.family)
                entries.append(entry)
            }
            
            let timeline = Timeline(entries: entries, policy: .after(Date().addingTimeInterval(29 * 60)) /*.atEnd*/) // new timeline of 30min after 29min
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

        if (sc.tokenExpiry == nil){ // never logged in successfully
        
            sc.login(){(result:Bool, errorMessage:String?)->() in
                if (result){
                    self.sc.batteryState(callback: batteryState(error:charging:plugged:charge_level:remaining_range:last_update:charging_point:remaining_time:battery_temperature:vehicle_id:))

                } else {
                    self.displayMessage(title: "Error", body:"Failed to login to MY.R. services." + " (\(errorMessage!))")
                    batteryState(error:true, charging: false, plugged: false, charge_level:0, remaining_range:0.0, last_update:0, charging_point: "", remaining_time: 0, battery_temperature: 0, vehicle_id:"")
                }
            }
        } else {
            if sc.isTokenExpired() {
                //print("Token expired or will expire too soon (or expiry date is nil), must renew")
                sc.renewToken(){(result:Bool)->() in
                    if result {
                        print("renewed expired token!")
                        self.sc.batteryState(callback: batteryState(error:charging:plugged:charge_level:remaining_range:last_update:charging_point:remaining_time:battery_temperature:vehicle_id:))
                        
                    } else {
                        self.displayMessage(title: "Error", body:"Failed to renew expired token.")
                        self.sc.tokenExpiry = nil // force new login next time
                        print("expired token NOT renewed!")
                        // instead of error, attempt new login right now:
                        self.sc.login(){(result:Bool,errorMessage:String?)->() in
                            if (result){
                                self.sc.batteryState(callback: batteryState(error:charging:plugged:charge_level:remaining_range:last_update:charging_point:remaining_time:battery_temperature:vehicle_id:))

                            } else {
                                self.displayMessage(title: "Error", body:"Failed to login to MY.R. services." + " (\(errorMessage!))")
                            }
                        }
                    }
                }
            } else {
                print("token still valid!")
            
                self.sc.batteryState(callback: batteryState(error:charging:plugged:charge_level:remaining_range:last_update:charging_point:remaining_time:battery_temperature:vehicle_id:))
            }
        }
    }
    
}


struct BatteryInfo {

    let range: String
    let level: String
    let charger: String
    let charging: String
    let plugged: String
    let time: String
    let last_update: String
}

struct SimpleEntry: TimelineEntry {
    let date: Date
    
    let data: BatteryInfo
    
    let widgetFamily: WidgetFamily

}

struct ZoeStatus_Modern_WidgetEntryView : View {
    var entry: Provider.Entry

    var body: some View
    {
        switch entry.widgetFamily {
        case .systemSmall:
            smallWidgetView
        case .systemMedium:
            mediumWidgetView
        case .systemLarge:
            largeWidgetView
        case .systemExtraLarge:
            largeWidgetView
        case .accessoryCircular:
            circularWidgetView
        case .accessoryRectangular:
            rectangularWidgetView
        case .accessoryInline:
            inlineWidgetView
        @unknown default:
            smallWidgetView
        }
  }
    
    
    private var smallWidgetView: some View {
        GeometryReader { geometry in
            let availableWidth = geometry.size.width
            let fontSize = availableWidth * 0.25 // Calculate font size as a fraction of width
            VStack(alignment: .leading, spacing: 10){
                Text("ZOE").font(.system(size: fontSize)).bold()
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity)
                    .multilineTextAlignment(.center)
                //Spacer(minLength: 10)
                Text(entry.data.level).font(.system(size: fontSize)).minimumScaleFactor(0.1).lineLimit(1)
                //Spacer(minLength: 0)
                Text(entry.data.range).font(.system(size: fontSize)).minimumScaleFactor(0.1).lineLimit(1)
            }
        }
    }
    

    private var mediumWidgetView: some View {
        VStack(alignment: .leading, spacing: 5){

            GeometryReader { geometry in
                let availableWidth = geometry.size.width
                let fontSize = availableWidth * 0.06 // Calculate font size as a fraction of width
                VStack(alignment: .leading, spacing: 5){
                    Text("ZOE").font(.system(size: fontSize)).bold()
                        .minimumScaleFactor(0.5)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity)
                        .multilineTextAlignment(.center)
                    Spacer(minLength: 1.0)
                    HStack {
                        Text(entry.data.level)
                            .font(.system(size: fontSize)) // Dynamically scale font
                            .lineLimit(1)
                            //.minimumScaleFactor(0.5)
                        Text(entry.data.range)
                            .font(.system(size: fontSize)) // Same scaling factor
                            .lineLimit(1)
                            //.minimumScaleFactor(0.5)
                    }
                    Spacer(minLength: 1.0)
                    HStack {
                        Text(entry.data.charger)
                            .font(.system(size: fontSize)) // Dynamically scale font
                            .lineLimit(1)
                            //.minimumScaleFactor(0.5)
                        Text(entry.data.time)
                            .font(.system(size: fontSize)) // Same scaling factor
                            .lineLimit(1)
                            //.minimumScaleFactor(0.5)
                        Text(entry.data.plugged)
                            .font(.system(size: fontSize)) // Same scaling factor
                            .lineLimit(1)
                            //.minimumScaleFactor(0.5)
                        Text(entry.data.charging)
                            .font(.system(size: fontSize)) // Same scaling factor
                            .lineLimit(1)
                            //.minimumScaleFactor(0.5)
                    }
                    Spacer(minLength: 1.0)
                    HStack {
                        Text(entry.data.last_update).font(.system(size: fontSize)) // Same scaling factor
                            .lineLimit(1)
                            //.minimumScaleFactor(0.5)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }//.frame(height: 55)
        }
    }


    private var largeWidgetView: some View {
        VStack(alignment: .leading, spacing: 5){

            GeometryReader { geometry in
                let availableWidth = geometry.size.width
                let fontSize = availableWidth * 0.08 // Calculate font size as a fraction of width
                VStack(alignment: .leading, spacing: 5){
                    Text("ZOE").font(.system(size: fontSize)).bold()
                        //.minimumScaleFactor(0.5)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity)
                        .multilineTextAlignment(.center)
                    Spacer(minLength: 1.0)
                    HStack {
                        Text(entry.data.level)
                            .font(.system(size: fontSize)) // Dynamically scale font
                            .lineLimit(1)
                            //.minimumScaleFactor(0.5)
                        Text(entry.data.range)
                            .font(.system(size: fontSize)) // Same scaling factor
                            .lineLimit(1)
                            //.minimumScaleFactor(0.5)
                    }
                    Spacer(minLength: 1.0)
                    HStack {
                        Text(entry.data.charger)
                            .font(.system(size: fontSize)) // Dynamically scale font
                            .lineLimit(1)
                            //.minimumScaleFactor(0.5)
                        Text(entry.data.time)
                            .font(.system(size: fontSize)) // Same scaling factor
                            .lineLimit(1)
                            //.minimumScaleFactor(0.5)
                       
                    }
                    Spacer(minLength: 1.0)
                    HStack {
                        
                        Text(entry.data.plugged)
                            .font(.system(size: fontSize)) // Same scaling factor
                            .lineLimit(1)
                        //.minimumScaleFactor(0.5)
                        Text(entry.data.charging)
                            .font(.system(size: fontSize)) // Same scaling factor
                            .lineLimit(1)
                        //.minimumScaleFactor(0.5)
                    }
                    Spacer(minLength: 1.0)
                    HStack {
                        Text(entry.data.last_update).font(.system(size: fontSize)) // Same scaling factor
                            .lineLimit(1)
                            //.minimumScaleFactor(0.5)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }//.frame(height: 55)
        }
    }

    
    private var circularWidgetView: some View {
        VStack(alignment: .leading, spacing: -2){
            Text("ZOE").font(.system(size: 20)).minimumScaleFactor(0.1).lineLimit(1).frame(maxWidth: .infinity) // Takes the full width
                .multilineTextAlignment(.center) // Centers the text
            Text(entry.data.range).font(.system(size: 48)).minimumScaleFactor(0.1).lineLimit(1).padding(.bottom, 6) // Custom spacing just for this entry
            Text(entry.data.level).font(.system(size: 48)).minimumScaleFactor(0.1).lineLimit(1)
        }
    }
    private var rectangularWidgetView: some View {

            VStack(alignment: .leading, spacing: 5){
                HStack{
                    Text(entry.data.level + "  " + entry.data.range).minimumScaleFactor(0.5).lineLimit(1)
                }
                Text(entry.data.last_update).minimumScaleFactor(0.5).lineLimit(1)
            }
    }
    
    private var inlineWidgetView: some View {
        HStack{
            Text("ZOE:" + entry.data.level + entry.data.range ).minimumScaleFactor(0.5).lineLimit(1) // why do two Text() not work here?
        }
    }
    
}

struct ZoeStatus_Modern_Widget: Widget {
    let kind: String = "ZoeStatus_Modern_Widget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            if #available(iOS 17.0, *) {
                ZoeStatus_Modern_WidgetEntryView(entry: entry)
                    .containerBackground(/*.fill.tertiary, */ for: .widget){
                    Color("Color-ZE")
                    }
            } else {
                ZoeStatus_Modern_WidgetEntryView(entry: entry)
                    .padding()
                    .background()
            }
        }
        .configurationDisplayName("ZOE Status")
        .description("Displays state of charge and remaining range.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge, .systemExtraLarge, .accessoryInline, .accessoryCircular, .accessoryRectangular]) // Support all widget sizes

    }
}


let dummy = BatteryInfo(range: "🛣️ …\u{2009}km", level: "🔋…\u{2009}%", charger: "⛽️ …", charging: "⚡️ ❌", plugged: "🔌 ❌", time: "⏳ …", last_update: "📅 … 🕰 …")
let snapshot = BatteryInfo(range: "🛣️ 300.0\u{2009}km", level: "🔋100\u{2009}%", charger: "⛽️ 0\u{2009}kW", charging: "⚡️ ❌", plugged: "🔌 ✅", time: "⏳ 0 min.", last_update: "📅 01.02.2003 🕰 12:34:56")


#Preview("Small", as: .systemSmall) {
    ZoeStatus_Modern_Widget()
} timeline: {

    // "\u{2009}" = thin space
    SimpleEntry(date: .now, data: snapshot, widgetFamily: .systemSmall)
    SimpleEntry(date: .now, data: dummy, widgetFamily: .systemSmall)
}

#Preview("Medium", as: .systemMedium) {
    ZoeStatus_Modern_Widget()
} timeline: {

    // "\u{2009}" = thin space
    SimpleEntry(date: .now, data: snapshot, widgetFamily: .systemMedium)
    SimpleEntry(date: .now, data: dummy, widgetFamily: .systemMedium)
}
#Preview("Large", as: .systemLarge) {
    ZoeStatus_Modern_Widget()
} timeline: {

    // "\u{2009}" = thin space
    SimpleEntry(date: .now, data: snapshot, widgetFamily: .systemLarge)
    SimpleEntry(date: .now, data: dummy, widgetFamily: .systemLarge)
}

 
#Preview("Extra Large", as: .systemExtraLarge) {
    ZoeStatus_Modern_Widget()
} timeline: {

    // "\u{2009}" = thin space
    SimpleEntry(date: .now, data: snapshot, widgetFamily: .systemExtraLarge)
    SimpleEntry(date: .now, data: dummy, widgetFamily: .systemExtraLarge)
}


#Preview("Lock circular", as: .accessoryCircular) {
    ZoeStatus_Modern_Widget()
} timeline: {

    // "\u{2009}" = thin space
    SimpleEntry(date: .now, data: snapshot, widgetFamily: .accessoryCircular)
    SimpleEntry(date: .now, data: dummy, widgetFamily: .accessoryCircular)
}

 
#Preview("Lock inline", as: .accessoryInline) {
    ZoeStatus_Modern_Widget()
} timeline: {

    // "\u{2009}" = thin space
    SimpleEntry(date: .now, data: snapshot, widgetFamily: .accessoryInline)
    SimpleEntry(date: .now, data: dummy, widgetFamily: .accessoryInline)
}


#Preview("Lock rectangular", as: .accessoryRectangular) {
    ZoeStatus_Modern_Widget()
} timeline: {

    // "\u{2009}" = thin space
    SimpleEntry(date: .now, data: snapshot, widgetFamily: .accessoryRectangular)
    SimpleEntry(date: .now, data: dummy, widgetFamily: .accessoryRectangular)
}
