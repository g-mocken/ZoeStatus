//
//  ServiceConnection.swift
//  ZoeStatus
//
//  Created by Dr. Guido Mocken on 02.12.18.
//  Copyright © 2018 Dr. Guido Mocken. All rights reserved.
//

import Foundation
import os

public enum PreconditionCommand {
     case now
     case later
     case delete
     case read
 }

public class ServiceConnection {

    let serviceLog = OSLog(subsystem: "com.grm.ZEServices", category: "ZOE")

    var myR: MyR!
    
    public static let shared = ServiceConnection() // Singleton!
    
    public struct Cache {
        public var timestamp: Date? // cache update at this time
        public var charging: Bool?
        public var plugged: Bool?
        public var charge_level: UInt8?
        public var remaining_range: Float?
        public var last_update: UInt64? //TimeInterval
        public var charging_point: String?
        public var remaining_time: Int?
    }
    var cache = Cache()
    
    public func updateCacheTimestamp(){
        cache.timestamp = Date()
     }
    public func getCache()->Cache{
        return cache
    }
    private init(){
        os_log("ServiceConnection log started.", log: serviceLog, type: .default)
    }
    
 
    
    public enum ApiVersion: Int {
        case MyRv1 = 1
        case MyRv2
    }
    
    public var simulation: Bool = false
    public var userName:String?
    public var password:String?
    public var api:ApiVersion?
    
    var vehicleIdentification:String?
    var activationCode: String?
    var token:String? // valid for a certain time, then needs to be renewed. Can be decoded.
    public var tokenExpiry:UInt64?
    var xsrfToken:String? // can be re-used indefinitely, cannot be decoded (?)
    // An additional "refreshToken" is received and sent back a Cookie whenever a "token" is received/sent - apparently this is handled transparently by the framework without any explicit code.
    
    var myR_context: MyR.Context?
    
    let baseURL = "https://www.services.renault-ze.com/api"
    
    
    fileprivate func extractExpiryDate(ofToken:String?)->UInt64? { // token is usually valid for 15min after it was issued
        print ("Analysing token...")
        if let token = ofToken{
            let indexFirstPeriod = token.firstIndex(of: ".") ?? token.startIndex

            let header = String(token[..<indexFirstPeriod]).fromBase64()
            print("Header: \(header!)")
            let indexSecondPeriod = token[token.index(after:indexFirstPeriod)...].firstIndex(of: ".") ?? token.endIndex
            print("Payload: \(String(token[token.index(after:indexFirstPeriod)..<indexSecondPeriod]))")

            if let payload = String(token[token.index(after:indexFirstPeriod)..<indexSecondPeriod]).fromBase64()
            {
                print("Decoded Payload: \(payload)")
                
                struct payloadResult: Codable{
                    let sub: String?
                    let userId: String?
                    let iat: UInt64
                    let exp: UInt64
                }
                
                let decoder = JSONDecoder()
                
                if let payloadData = payload.data(using: .utf8){
                    let result = try? decoder.decode(payloadResult.self, from: payloadData)
                    if let result = result {
                        
                        print("Issued \(result.iat)")
                        print("Expires \(result.exp)")
                        let date = Date()
                        let interval = UInt64(date.timeIntervalSince1970)
                        print("Current \(interval)")
                        
                        
                        // only for debugging also print human readable time and date:
                        if let unixTime = Double(exactly:result.exp) {
                            let date = Date(timeIntervalSince1970: unixTime)
                            let dateFormatter = DateFormatter()
                            let timezone = TimeZone.current.abbreviation() ?? "CET"  // get current TimeZone abbreviation or set to CET
                            dateFormatter.timeZone = TimeZone(abbreviation: timezone) //Set timezone that you want
                            dateFormatter.locale = NSLocale.current
                            dateFormatter.dateFormat = "dd.MM.yyyy HH:mm:ss" //Specify your format that you want
                            let strDate = dateFormatter.string(from: date)
                            print("Expires: \(strDate)")
                        }
                        return result.exp
                    }
                }
            }
        }
        return nil
    }
    
    public func login (callback c:@escaping(Bool)->Void) {
    
        os_log("login", log: serviceLog, type: .default)
        
        if userName == "simulation", password == "simulation"
        {
            simulation = true
        } else {
            simulation = false
        }
        if simulation {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                c(true)
            }
            return
        }
        
        guard (userName != nil && password != nil) else{
            c(false)
            return
        }

        switch api {
        case .MyRv1:
            login_MyR(callback:c, version: .v1)
        case .MyRv2:
            login_MyR(callback:c, version: .v2)
        case .none:
            ()
        }
    }
    
    public func fixMyRContext(){
        if !simulation {
            myR.context = myR_context!
            print ("check: \(myR.context.vehiclesInfo!)")
        }
    }
    
    func login_MyR (callback:@escaping(Bool)->Void, version: MyR.Version) {
        print ("New API login")
        
        myR = MyR(username: userName!, password: password!, version: version)
        myR.handleLoginProcess(onError: {
            DispatchQueue.main.async{callback(false)}
        }, onSuccess: { vin, token, context in
            print("Login MyR successful.")
            self.tokenExpiry = self.extractExpiryDate(ofToken: token)
            self.vehicleIdentification = vin // to avoid crashes, when switching API versions
            self.myR_context = context // store context from parameter at runtime, not at capture time
            // it will be restored from there when it's needed in the callback. It would be cleaner to pass the context back to the callback - however, the callback is passed through several times and accross API versions. TODO when obsolete ZE-API support is dropped anyway.
            DispatchQueue.main.async{
                // watch out: myR.context is captured before the login, so the callback executes with no context
                callback(true)
            }
        }) // later change latter to true
        
    }
        

    
    
    public func renewToken (callback:@escaping(Bool)->Void) {
        os_log("renewToken", log: serviceLog, type: .default)

        
        switch api {
        case .MyRv1, .MyRv2:
            renewToken_MyR(callback:callback)
        case .none:
            ()
        }
    }
    
    public func renewToken_MyR (callback:@escaping(Bool)->Void) {
        callback(false) // cannot renew, just trigger automatic new login
    }



    
    public func batteryState(callback c:@escaping  (Bool, Bool, Bool, UInt8, Float, UInt64, String?, Int?) -> ()) {
        os_log("batteryState", log: serviceLog, type: .default)

        cache.timestamp = Date()
        if simulation {
            print ("batteryState: simulated")
            self.cache.charging=true
            self.cache.plugged=true
            if (self.cache.charge_level == nil || self.cache.charge_level! > 100){
                self.cache.charge_level=50
            } else {
                self.cache.charge_level! += 1
            }

            self.cache.remaining_range=123.4

            if (self.cache.remaining_time == nil ){
                self.cache.last_update=1550874142000
            } else {
                self.cache.last_update! += 30*60
            }

            self.cache.charging_point="ACCELERATED"
            if (self.cache.remaining_time == nil || self.cache.remaining_time! == 0){
                self.cache.remaining_time=345
            } else {
                self.cache.remaining_time! -= 1
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                c(false,
                  self.cache.charging!,
                  self.cache.plugged!,
                  self.cache.charge_level!,
                  self.cache.remaining_range!,
                  self.cache.last_update!,
                  self.cache.charging_point!,
                  self.cache.remaining_time!)
            }
            return
        }
        
        
        switch api {
        case .MyRv1, .MyRv2:
            batteryState_MyR(callback:c)
        case .none:
            ()
        }
    }
    func batteryState_MyR(callback:@escaping  (Bool, Bool, Bool, UInt8, Float, UInt64, String?, Int?) -> ()) {
        
        myR.batteryState(callback:
            {error,charging,plugged,charge_level,remaining_range,last_update,charging_point,remaining_time in
                self.cache.charging=charging
                self.cache.plugged=plugged
                self.cache.charge_level=charge_level
                self.cache.remaining_range=remaining_range
                self.cache.last_update=last_update
                self.cache.charging_point=charging_point
                self.cache.remaining_time=remaining_time
                callback(error,charging,plugged,charge_level,remaining_range,last_update,charging_point,remaining_time)
            }
        )

    }

    
    
    public func isTokenExpired()->Bool {
        let date = Date()
        let now = UInt64(date.timeIntervalSince1970)
        if (  tokenExpiry != nil && tokenExpiry! > now + 60) { // must be valid for at least one more minute
            print("isTokenExpired: Token still valid")
            return false
        } else {
            print("isTokenExpired: Token expired or will expire too soon (or expiry date is nil), must renew")
            return true
        }        
    }
    

    public func precondition(command:PreconditionCommand, date: Date?, callback:@escaping  (Bool, PreconditionCommand, Date?) -> ()) {
        
        os_log("precondition", log: serviceLog, type: .default)

        if simulation {
            print ("precondition: simulated")
            DispatchQueue.main.async {
                callback(false, command, date)
            }
            return
        }
        
#if false
        DispatchQueue.main.async {
            callback(false, command, date)
        }
        return
#endif

        switch api {
        case .MyRv1, .MyRv2:
            precondition_MyR(command: command, date: date, callback:callback)
        case .none:
            ()
        }
    }
    
    public func precondition_MyR(command:PreconditionCommand, date: Date?, callback:@escaping  (Bool, PreconditionCommand, Date?) -> ()) {
        myR.precondition(command: command, date: date, callback: callback)
    }
    

    
    
    
    
    
    public func airConditioningLastState(callback c:@escaping  (Bool, UInt64, String?, String?) -> ()) {

        os_log("airConditioningLastState", log: serviceLog, type: .default)

        if simulation {
            print ("airConditioningLastState: simulated")
            DispatchQueue.main.async {
                c(false,
                         1550874142000,
                         "-",
                         "SUCCESS")
            }
            return
        }
        
        switch api {
               case .MyRv1, .MyRv2:
                airConditioningLastState_MyR(callback:c)
               case .none:
                   ()
               }
    }
    
    public func airConditioningLastState_MyR(callback:@escaping  (Bool, UInt64, String?, String?) -> ()) {
        myR.airConditioningLastState(callback: callback)
    }


    
    
    
    
    public func batteryStateUpdateRequest(callback:@escaping  (Bool) -> ()) {
        if simulation {
            print ("batteryStateUpdateRequest: simulated")
            DispatchQueue.main.async {
                callback(false)
            }
            return
        }
        
        let batteryURL = baseURL + "/vehicle/" + vehicleIdentification! + "/battery"
        
        let tString = ""
        let uploadData = tString.data(using: String.Encoding.utf8)
        
        let url = URL(string: batteryURL)!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token!)", forHTTPHeaderField: "Authorization")
        request.setValue("\(xsrfToken!)", forHTTPHeaderField: "X-XSRF-TOKEN")
        
        let task = URLSession.shared.uploadTask(with: request, from: uploadData) { data, response, error in
            if let error = error {
                //print ("error: \(error)")
                os_log("URLSession error: %{public}s", log: self.serviceLog, type: .error, error.localizedDescription)
                DispatchQueue.main.async {
                    callback(true)
                }
                return
            }
            guard let response2 = response as? HTTPURLResponse,
                (200...299).contains(response2.statusCode) else {
                    print ("server error")
                    print ((response as! HTTPURLResponse).description)
                    DispatchQueue.main.async {
                        callback(true)
                    }
                    return
            }
            // there is no reply to analyze, so just proceed with the callback
            DispatchQueue.main.async {
                callback(false)
            }
        }
        task.resume()
    }
    
    
    
    public func chargeNowRequest(callback:@escaping  (Bool) -> ()) {
        if simulation {
            print ("chargeNowRequest: simulated")
            DispatchQueue.main.async {
                callback(false)
            }
            return
        }
        
        switch api {
        case .MyRv1, .MyRv2:
            chargeNowRequest_MyR(callback:callback)
        case .none:
            ()
        }
    }
    
    public func chargeNowRequest_MyR(callback:@escaping  (Bool) -> ()) {
    
        myR.chargeNowRequest(callback:callback)
        
    }
}
