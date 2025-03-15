//
//  ServiceConnection.swift
//  ZoeStatus
//
//  Created by Dr. Guido Mocken on 02.12.18.
//  Copyright © 2018 Dr. Guido Mocken. All rights reserved.
//

import Foundation
import os

public enum PreconditionCommand : Sendable{
     case now
     case later
     case delete
     case read
 }

public class ServiceConnection {
    
    let serviceLog = OSLog(subsystem: Bundle.main.bundleIdentifier!, category: "ZE")
    
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
    var cache = Cache() // currently, cache is only used in experimental (disabled) Watch complication code. modern and classic widgets have their own local caching. TODO: use the same cache here everywhere
    
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
        //print ("Analysing token...")
        if let token = ofToken{
            let indexFirstPeriod = token.firstIndex(of: ".") ?? token.startIndex
            
            let header = String(token[..<indexFirstPeriod]).fromBase64()
            os_log("Token Header: %{public}s", log: serviceLog, type: .default, header!)
            
            let indexSecondPeriod = token[token.index(after:indexFirstPeriod)...].firstIndex(of: ".") ?? token.endIndex
            os_log("Token Payload: %{public}s", log: serviceLog, type: .default, String(token[token.index(after:indexFirstPeriod)..<indexSecondPeriod]))
            
            if let payload = String(token[token.index(after:indexFirstPeriod)..<indexSecondPeriod]).fromBase64()
            {
                os_log("Token Decoded Payload: %{public}s", log: serviceLog, type: .default, payload)
                
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
                        
                        let date = Date()
                        let interval = UInt64(date.timeIntervalSince1970)
                        
                        os_log("Token:\n issued:  %u\n expires: %u\n current: %u", log: serviceLog, type: .default, result.iat, result.exp, interval)
                        
                        // only for debugging also print human readable time and date:
                        if let unixTime = Double(exactly:result.exp) {
                            let date = Date(timeIntervalSince1970: unixTime)
                            let dateFormatter = DateFormatter()
                            let timezone = TimeZone.current.abbreviation() ?? "CET"  // get current TimeZone abbreviation or set to CET
                            dateFormatter.timeZone = TimeZone(abbreviation: timezone) //Set timezone that you want
                            dateFormatter.locale = NSLocale.current
                            dateFormatter.dateFormat = "dd.MM.yyyy HH:mm:ss" //Specify your format that you want
                            let strDate = dateFormatter.string(from: date)
                            os_log("Token expires: %{public}s", log: serviceLog, type: .default, strDate)
                        }
                        return result.exp
                    }
                }
            }
        }
        return nil
    }
    
    public func login (callback:@escaping(_ result:Bool, _ errorMessage:String?)->Void) {
        
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
    
    public func loginAsync() async -> (result:Bool, errorMessage:String?){
       
     
        
            return (true, "") // dummy
    
       
    }
    
    
    func login_MyR (callback:@escaping(_ success:Bool, _ context:MyR.Context?, _ errorMessage:String?)->Void, version: MyR.Version) {
        
        os_log("New API login", log: serviceLog, type: .default)
        myR = MyR(username: userName!, password: password!, version: version, kamereon: kamereon!, vehicle: vehicle!)
        
        /*
         myR.handleLoginProcess(onError: { errorMessage in
         DispatchQueue.main.async{callback(false, nil, errorMessage)}
         }, onSuccess: { vin, token, context in
         os_log("Login MyR successful.", log: self.serviceLog, type: .default)
         self.tokenExpiry = self.extractExpiryDate(ofToken: token)
         self.vehicleIdentification = vin // to avoid crashes, when switching API versions
         DispatchQueue.main.async{
         callback(true, context, nil)
         }
         }) // later change latter to true
         */
        
        Task {
            let result = await myR.handleLoginProcessAsync(onError: { errorMessage in
                DispatchQueue.main.async{
                    callback(false, nil, errorMessage)
                }
            })
            
            os_log("Login MyR successful.", log: self.serviceLog, type: .default)
            self.tokenExpiry = self.extractExpiryDate(ofToken: result.token)
            self.vehicleIdentification = result.vin // to avoid crashes, when switching API versions
            
            DispatchQueue.main.async{
                callback(true, result.context, nil)
            }
        }
        
        
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
    
    
    
    
    public func batteryState(callback c:@escaping (_ error:Bool, _ charging:Bool, _ plugged:Bool, _ charge_level:UInt8, _ remaining_range:Float, _ last_update:UInt64, _ charging_point:String?, _ remaining_time:Int?, _ battery_temperature:Int?, _ vehicle_id:String?) -> ()) {
        os_log("batteryState", log: serviceLog, type: .default)
        
        cache.timestamp = Date()
        if simulation {
            //print ("batteryState: simulated")
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
            //batteryState_MyR(callback:c)
            Task {
                let result = await myR.batteryStateAsync()
                cache.charging=result.charging
                cache.plugged=result.plugged
                cache.charge_level=result.charge_level
                cache.remaining_range=result.remaining_range
                cache.last_update=result.last_update
                cache.charging_point=result.charging_point
                cache.remaining_time=result.remaining_time
                cache.battery_temperature=result.battery_temperature
                cache.vehicleId=result.vehicle_id
                DispatchQueue.main.async{
                    c(result.error,
                      result.charging,
                      result.plugged,
                      result.charge_level,
                      result.remaining_range,
                      result.last_update,
                      result.charging_point,
                      result.remaining_time,
                      result.battery_temperature,
                      result.vehicle_id)
                }
            }
            
        case .none:
            ()
        }
    }
    func batteryState_MyR(callback:@escaping (_ error:Bool, _ charging:Bool, _ plugged:Bool, _ charge_level:UInt8, _ remaining_range:Float, _ last_update:UInt64, _ charging_point:String?, _ remaining_time:Int?, _ battery_temperature:Int?, _ vehicle_id:String?) -> ()) {
        
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
    
    
    
    
    public func batteryStateAsync() async -> (error:Bool, charging:Bool, plugged:Bool, charge_level:UInt8, remaining_range:Float, last_update:UInt64, charging_point:String?, remaining_time:Int?, battery_temperature:Int?, vehicle_id:String?){
        os_log("batteryState", log: serviceLog, type: .default)
        
        cache.timestamp = Date()
        if simulation {
            //print ("batteryState: simulated")
            cache.charging=true
            cache.plugged=true
            if (cache.charge_level == nil || cache.charge_level! > 100){
                cache.charge_level=50
            } else {
                cache.charge_level! += 1
            }
            
            cache.remaining_range=123.4
            
            if (cache.remaining_time == nil ){
                cache.last_update=1550874142000
            } else {
                cache.last_update! += 30*60
            }
            
            cache.charging_point="ACCELERATED"
            if (cache.remaining_time == nil || cache.remaining_time! == 0){
                cache.remaining_time=345
            } else {
                cache.remaining_time! -= 1
            }
            
            if (cache.battery_temperature == nil){
                cache.battery_temperature = 30
            }
            if (cache.vehicleId == nil){
                cache.vehicleId = "Simulated Vehicle"
            }
            try? await Task.sleep(nanoseconds:  500_000_000) // .5-second delay
            
            return (false,
                    cache.charging!,
                    cache.plugged!,
                    cache.charge_level!,
                    cache.remaining_range!,
                    cache.last_update!,
                    cache.charging_point!,
                    cache.remaining_time!,
                    cache.battery_temperature!,
                    cache.vehicleId!)
        }
        
        
        switch api {
        case .MyRv1, .MyRv2:
            
            let result = await myR.batteryStateAsync()
            cache.charging=result.charging
            cache.plugged=result.plugged
            cache.charge_level=result.charge_level
            cache.remaining_range=result.remaining_range
            cache.last_update=result.last_update
            cache.charging_point=result.charging_point
            cache.remaining_time=result.remaining_time
            cache.battery_temperature=result.battery_temperature
            cache.vehicleId=result.vehicle_id
            
            return (result.error,
                    result.charging,
                    result.plugged,
                    result.charge_level,
                    result.remaining_range,
                    result.last_update,
                    result.charging_point,
                    result.remaining_time,
                    result.battery_temperature,
                    result.vehicle_id)
            
            
            
        case .none: // dummy return for nil value
            return (false,
                    cache.charging!,
                    cache.plugged!,
                    cache.charge_level!,
                    cache.remaining_range!,
                    cache.last_update!,
                    cache.charging_point!,
                    cache.remaining_time!,
                    cache.battery_temperature!,
                    cache.vehicleId!)
        }
    }
    
    
    public func cockpitState(callback c:@escaping (_ error:Bool, _ total_mileage:Float?) -> ()) {
        os_log("cockpitState", log: serviceLog, type: .default)

        if simulation {
            //print ("cockpitState: simulated")
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
            //cockpitState_MyR(callback:c)
            Task {
                let result = await myR.cockpitStateAsync()
                cache.totalMileage = result.total_mileage
                DispatchQueue.main.async{
                    c(result.error, result.total_mileage)
                }
            }

        case .none:
            ()
        }
    }

    func cockpitState_MyR(callback:@escaping (_ error:Bool, _ total_mileage:Float?) -> ()) {
        myR.cockpitState(callback: {error, total_mileage in
            self.cache.totalMileage = total_mileage
            callback(error,total_mileage)
        })
    }

    public func cockpitStateAsync() async -> (error:Bool, total_mileage:Float?) {
        os_log("cockpitState", log: serviceLog, type: .default)
        
        if simulation {
            //print ("cockpitState: simulated")
            if (self.cache.totalMileage == nil) {
                self.cache.totalMileage = 123000.0
            } else {
                self.cache.totalMileage! += 1.23
            }
            try? await Task.sleep(nanoseconds:  500_000_000) // .5-second delay
            return(error: false,
                   total_mileage: cache.totalMileage!)
            
        }
        
        
        switch api {
        case .MyRv1, .MyRv2:
            let result = await myR.cockpitStateAsync()
            cache.totalMileage = result.total_mileage
            
            return (error: result.error,
                    total_mileage: result.total_mileage)
            
            
            
        case .none: // dummy
            return(error: false,
                   total_mileage: cache.totalMileage!)
        }
    }

    
    
    
    public func isTokenExpired()->Bool {
        let date = Date()
        let now = UInt64(date.timeIntervalSince1970)
        if (  tokenExpiry != nil && tokenExpiry! > now + 60) { // must be valid for at least one more minute
            os_log("isTokenExpired: Token still valid for %d seconds", log: serviceLog, type: .default, tokenExpiry! - now)
            return false
        } else {
            os_log("isTokenExpired: Token expired or will expire too soon (or expiry date is nil), must renew", log: serviceLog, type: .default)
            return true
        }        
    }
    

    public func precondition(command:PreconditionCommand, date: Date?, callback:@escaping (_ error: Bool, _ command:PreconditionCommand, _ date: Date?, _ externalTemperature: Float? ) -> ()) {
        
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
            //precondition_MyR(command: command, date: date, callback:callback)
            Task {
                let result = await myR.preconditionAsync(command: command, date: date)
                DispatchQueue.main.async{
                    callback(result.error, result.command, result.date, result.externalTemperature)
                }
            }

        case .none:
            ()
        }
    }
    
    public func precondition_MyR(command:PreconditionCommand, date: Date?, callback:@escaping  (_ error: Bool, _ command:PreconditionCommand, _ date: Date?, _ externalTemperature: Float? ) -> ()) {
        myR.precondition(command: command, date: date, callback: callback)
    }
    

    
    public func preconditionAsync(command:PreconditionCommand, date: Date?) async ->  (error: Bool, command:PreconditionCommand, date: Date?, externalTemperature: Float? ) {
        
        os_log("precondition", log: serviceLog, type: .default)
        
        if simulation {
            print ("precondition: simulated")
            return (error:false,
                    command:command,
                    date:date,
                    externalTemperature:12.3)
        }
        
#if false
        DispatchQueue.main.async {
            callback(false, command, date)
        }
        return
#endif

        switch api {
        case .MyRv1, .MyRv2:

            let result = await myR.preconditionAsync(command: command, date: date)
            return (error:result.error,
                    command:result.command,
                    date:result.date,
                    externalTemperature:result.externalTemperature)

        case .none: // dummy
            return (error:false,
                    command:command,
                    date:date,
                    externalTemperature:12.3)
        }
    }

    
    
    
    public func airConditioningLastState(callback c:@escaping  (_ error: Bool, _ date:UInt64, _ type:String?, _ result:String?) -> ()) {
        
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
            // airConditioningLastState_MyR(callback:c)
            Task {
                let result = await myR.airConditioningLastStateAsync()
                DispatchQueue.main.async{
                    c(result.error, result.date, result.type, result.result)
                }
            }

            
        case .none:
            ()
        }
    }
    
    public func airConditioningLastState_MyR(callback:@escaping  (_ error: Bool, _ date:UInt64, _ type:String?, _ result:String?) -> ()) {
        myR.airConditioningLastState(callback: callback)
    }

    public func airConditioningLastStateAsync() async -> (error: Bool, date:UInt64, type:String?, result:String?){
        
        os_log("airConditioningLastState", log: serviceLog, type: .default)
        
        if simulation {
            print ("airConditioningLastState: simulated")
            return (error: false,
                    date: 1550874142000,
                    type: "-",
                    result: "SUCCESS")
             
        }
        
        switch api {
        case .MyRv1, .MyRv2:
            let result = await myR.airConditioningLastStateAsync()
            return (error: result.error,
                    date: result.date,
                    type: result.type,
                    result: result.result)

            
        case .none: // dummy
            return (error: false,
                    date: 1550874142000,
                    type: "-",
                    result: "SUCCESS")

        }
    }

    
    
    
    public func chargeNowRequest(callback:@escaping  (_ error: Bool) -> ()) {
        if simulation {
            print ("chargeNowRequest: simulated")
            DispatchQueue.main.async {
                callback(false)
            }
            return
        }
        
        switch api {
        case .MyRv1, .MyRv2:
            // chargeNowRequest_MyR(callback:callback)
            Task {
                let result = await myR.chargeNowRequestAsync()
                DispatchQueue.main.async{
                    callback(result)
                }
            }
        case .none:
            ()
        }
    }
    
    public func chargeNowRequest_MyR(callback:@escaping  (_ error: Bool) -> ()) {
    
        myR.chargeNowRequest(callback:callback)
        
    }
}
