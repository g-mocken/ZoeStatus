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
        public var battery_temperature: Int?
        public var totalMileage: Float?
        public var vehicleId: String?
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
    
    public enum Units: Int {
        case Metric = 1
        case Imperial
    }
    
    public let kmPerMile = Float(1.609344)

    public var simulation: Bool = false
    
    public var userName:String?
    public var password:String?
    public var kamereon:String?
    
    public var api:ApiVersion?
    public var units:Units?
    public var vehicle:Int?
    
    var vehicleIdentification:String?
    var activationCode: String?
    public var tokenExpiry:UInt64?
    
    
    
    
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
    
    public func login (callback:@escaping(Bool, String?)->Void) {
    
        os_log("login", log: serviceLog, type: .default)
        
        if userName == "simulation", password == "simulation"
        {
            simulation = true
        } else {
            simulation = false
        }
        if simulation {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                callback(true, nil)
            }
            return
        }
        
        guard (userName != nil && password != nil) else{
            callback(false, "username/password missing")
            return
        }

        let storeContextThenRunCallback = { (success:Bool, context:MyR.Context?, errorMessage:String?)->() in
            if (success) {
                self.myR.context = context!
                print ("check: \(self.myR.context.vehiclesInfo!)")
            }
            callback(success, errorMessage)
        }
        
        switch api {
        case .MyRv1:
            login_MyR(callback:storeContextThenRunCallback, version: .v1)
        case .MyRv2:
            login_MyR(callback:storeContextThenRunCallback, version: .v2)
        case .none:
            ()
        }
    }
    
    
    func login_MyR (callback:@escaping(Bool, MyR.Context?, String?)->Void, version: MyR.Version) {
        print ("New API login")
        
        myR = MyR(username: userName!, password: password!, version: version, kamereon: kamereon!, vehicle: vehicle!)
        myR.handleLoginProcess(onError: { errorMessage in
            DispatchQueue.main.async{callback(false, nil, errorMessage)}
        }, onSuccess: { vin, token, context in
            print("Login MyR successful.")
            self.tokenExpiry = self.extractExpiryDate(ofToken: token)
            self.vehicleIdentification = vin // to avoid crashes, when switching API versions
            DispatchQueue.main.async{
                callback(true, context, nil)
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



    
    public func batteryState(callback c:@escaping  (Bool, Bool, Bool, UInt8, Float, UInt64, String?, Int?, Int?, String?) -> ()) {
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

            if (self.cache.battery_temperature == nil){
                self.cache.battery_temperature = 30
            }
            if (self.cache.vehicleId == nil){
                self.cache.vehicleId = "Simulated Vehicle"
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                c(false,
                  self.cache.charging!,
                  self.cache.plugged!,
                  self.cache.charge_level!,
                  self.cache.remaining_range!,
                  self.cache.last_update!,
                  self.cache.charging_point!,
                  self.cache.remaining_time!,
                  self.cache.battery_temperature!,
                  self.cache.vehicleId!)
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
    func batteryState_MyR(callback:@escaping  (Bool, Bool, Bool, UInt8, Float, UInt64, String?, Int?, Int?, String?) -> ()) {
        
        myR.batteryState(callback:
            {error,charging,plugged,charge_level,remaining_range,last_update,charging_point,remaining_time, battery_temperature, vehicle_id in
                self.cache.charging=charging
                self.cache.plugged=plugged
                self.cache.charge_level=charge_level
                self.cache.remaining_range=remaining_range
                self.cache.last_update=last_update
                self.cache.charging_point=charging_point
                self.cache.remaining_time=remaining_time
                self.cache.battery_temperature=battery_temperature
                self.cache.vehicleId=vehicle_id
                callback(error,charging,plugged,charge_level,remaining_range,last_update,charging_point,remaining_time,battery_temperature,vehicle_id)
            }
        )
    }
    
    
    
    
    public func cockpitState(callback c:@escaping  (Bool, Float?) -> ()) {
        os_log("cockpitState", log: serviceLog, type: .default)

        if simulation {
            print ("cockpitState: simulated")
            if (self.cache.totalMileage == nil) {
                self.cache.totalMileage = 123000.0
            } else {
                self.cache.totalMileage! += 1.23
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                c(false,
                  self.cache.totalMileage!)
            }
            return
        }
        
        
        switch api {
        case .MyRv1, .MyRv2:
            cockpitState_MyR(callback:c)
        case .none:
            ()
        }
    }

    func cockpitState_MyR(callback:@escaping  (Bool, Float?) -> ()) {
        myR.cockpitState(callback: {error, total_mileage in
            self.cache.totalMileage = total_mileage
            callback(error,total_mileage)
        })
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
    

    public func precondition(command:PreconditionCommand, date: Date?, callback:@escaping  (Bool, PreconditionCommand, Date?, Float?) -> ()) {
        
        os_log("precondition", log: serviceLog, type: .default)

        if simulation {
            print ("precondition: simulated")
            DispatchQueue.main.async {
                callback(false, command, date, 12.3)
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
    
    public func precondition_MyR(command:PreconditionCommand, date: Date?, callback:@escaping  (Bool, PreconditionCommand, Date?, Float?) -> ()) {
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
