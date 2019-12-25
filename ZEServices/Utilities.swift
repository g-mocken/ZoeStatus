//
//  Utilities.swift
//  ZoeStatus
//
//  Created by Dr. Guido Mocken on 16.11.19.
//  Copyright © 2019 Dr. Guido Mocken. All rights reserved.
//

import Foundation

extension String { // taken from https://stackoverflow.com/a/35360697/1149188
    
    func fromBase64() -> String? {
        var base64 = self
        let r = base64.count % 4 // if padding is missing, add as many "=" as needed to make the decoder happy
        if r != 0 {
            for _ in 0 ... 3-r {
                base64 += "="
            }
        }
        
        guard let data = Data(base64Encoded: base64) else {
            return nil
        }
        
        return String(data: data, encoding: .utf8)
    }
    
    func toBase64() -> String {
        return Data(self.utf8).base64EncodedString()
    }
}

public func timestampToDateString(timestamp: UInt64?) -> String{
    var strDate = "📅 … 🕰 …"
    
    if timestamp != nil {
        if let unixTime = Double(exactly:timestamp!/1000) {
            let date = Date(timeIntervalSince1970: unixTime)
            let dateFormatter = DateFormatter()
            let timezone = TimeZone.current.abbreviation() ?? "CET"  // get current TimeZone abbreviation or set to CET
            dateFormatter.timeZone = TimeZone(abbreviation: timezone) //Set timezone that you want
            dateFormatter.locale = NSLocale.current
            dateFormatter.dateFormat = "📅 dd.MM.yyyy 🕰 HH:mm:ss" //Specify your format that you want
            strDate = dateFormatter.string(from: date)
        }
    }
    return strDate
}


public func timestampToDateOnlyString(timestamp: UInt64?) -> String{
    var strDate = "📅 …"
    
    if timestamp != nil {
        if let unixTime = Double(exactly:timestamp!/1000) {
            let date = Date(timeIntervalSince1970: unixTime)
            let dateFormatter = DateFormatter()
            let timezone = TimeZone.current.abbreviation() ?? "CET"  // get current TimeZone abbreviation or set to CET
            dateFormatter.timeZone = TimeZone(abbreviation: timezone) //Set timezone that you want
            dateFormatter.locale = NSLocale.current
            dateFormatter.dateFormat = "📅 dd.MM.yyyy" //Specify your format that you want
            strDate = dateFormatter.string(from: date)
        }
    }
    return strDate
}

public func timestampToDateOnlyNoYearString(timestamp: UInt64?) -> String{
    var strDate = "📅 …"
    
    if timestamp != nil {
        if let unixTime = Double(exactly:timestamp!/1000) {
            let date = Date(timeIntervalSince1970: unixTime)
            let dateFormatter = DateFormatter()
            let timezone = TimeZone.current.abbreviation() ?? "CET"  // get current TimeZone abbreviation or set to CET
            dateFormatter.timeZone = TimeZone(abbreviation: timezone) //Set timezone that you want
            dateFormatter.locale = NSLocale.current
            dateFormatter.dateFormat = "📅 dd.MM." //Specify your format that you want
            strDate = dateFormatter.string(from: date)
        }
    }
    return strDate
}

public func timestampToTimeOnlyString(timestamp: UInt64?) -> String{
    var strDate = "🕰 …"
    
    if timestamp != nil {
        if let unixTime = Double(exactly:timestamp!/1000) {
            let date = Date(timeIntervalSince1970: unixTime)
            let dateFormatter = DateFormatter()
            let timezone = TimeZone.current.abbreviation() ?? "CET"  // get current TimeZone abbreviation or set to CET
            dateFormatter.timeZone = TimeZone(abbreviation: timezone) //Set timezone that you want
            dateFormatter.locale = NSLocale.current
            dateFormatter.dateFormat = "🕰 HH:mm:ss" //Specify your format that you want
            strDate = dateFormatter.string(from: date)
        }
    }
    return strDate
}



public func timestampToTimeOnlyNoSecondsString(timestamp: UInt64?) -> String{
    var strDate = "🕰 …"
    
    if timestamp != nil {
        if let unixTime = Double(exactly:timestamp!/1000) {
            let date = Date(timeIntervalSince1970: unixTime)
            let dateFormatter = DateFormatter()
            let timezone = TimeZone.current.abbreviation() ?? "CET"  // get current TimeZone abbreviation or set to CET
            dateFormatter.timeZone = TimeZone(abbreviation: timezone) //Set timezone that you want
            dateFormatter.locale = NSLocale.current
            dateFormatter.dateFormat = "🕰 HH:mm" //Specify your format that you want
            strDate = dateFormatter.string(from: date)
        }
    }
    return strDate
}


public func dateToTimeString(date: Date) -> String{
    var strDate = "undefined"
    
    let dateFormatter = DateFormatter()
    let timezone = TimeZone.current.abbreviation() ?? "CET"  // get current TimeZone abbreviation or set to CET
    dateFormatter.timeZone = TimeZone(abbreviation: timezone) //Set timezone that you want
    dateFormatter.locale = NSLocale.current
    dateFormatter.dateFormat = "⏰ HH:mm" //Specify your format that you want
    strDate = dateFormatter.string(from: date)
    
    return strDate
}


 public func chargingPointToChargerString(_ plugged: Bool, _ charging_point: String?) -> (String) {
    
    var text = "⛽️ …"
    
    if plugged, (charging_point != nil) {
        
        switch (charging_point!) {
        case "INVALID":
            text = "⛽️ " + "❌"
            break;
        case "SLOW":
            text = "⛽️ " + "🐌"
            break;
        case "FAST":
            text = "⛽️ " + "✈️"
            break;
        case "ACCELERATED":
            text = "⛽️ " + "🚀"
            break;
        default:
            text = "⛽️ " + charging_point! // in case an unknown value appears, print the raw text instead of an icon
            break;
        }
    }
    return text
}


 public func remainingTimeToRemainingString(_ charging: Bool, _ remaining_time: Int?) -> (String) {
    
    var text = "⏳ …"
    
    if charging, (remaining_time != nil) {
        text = String(format: "⏳ %d min.", remaining_time!)
    }
    return text
}


 public func remainingTimeToRemainingShortString(_ charging: Bool, _ remaining_time: Int?) -> (String) {
    
    var text = "⏳ …"
    
    if charging, (remaining_time != nil) {
        text = String(format: "⏳ %d '", remaining_time!)
    }
    return text
}
