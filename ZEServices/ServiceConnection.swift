//
//  ServiceConnection.swift
//  ZoeStatus
//
//  Created by Dr. Guido Mocken on 02.12.18.
//  Copyright © 2018 Dr. Guido Mocken. All rights reserved.
//

import Foundation
import os



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
    
    public enum PreconditionCommand {
        case now
        case later
        case delete
        case read
    }
    
    public enum ApiVersion: Int {
        case ZE = 0
        case MyRv1
        case MyRv2
    }
    
    public var simulation: Bool = false
    public var userName:String?
    public var password:String?
    public var api_version:ApiVersion?
    
    var vehicleIdentification:String?
    var activationCode: String?
    var token:String? // valid for a certain time, then needs to be renewed. Can be decoded.
    public var tokenExpiry:UInt64?
    var xsrfToken:String? // can be re-used indefinitely, cannot be decoded (?)
    // An additional "refreshToken" is received and sent back a Cookie whenever a "token" is received/sent - apparently this is handled transparently by the framework without any explicit code.
    
   let baseURL = "https://www.services.renault-ze.com/api"
    
    
    fileprivate func extractExpiryDate(ofToken:String?)->UInt64? { // token is usually valid for 15min after it was issued
        print ("Analysing token:")
        if let token = ofToken{
            let indexFirstPeriod = token.firstIndex(of: ".") ?? token.startIndex

            let header = String(token[..<indexFirstPeriod]).fromBase64()
            print("Header: \(header!)")
            let indexSecondPeriod = token[token.index(after:indexFirstPeriod)...].firstIndex(of: ".") ?? token.endIndex
            print("Payload: \(String(token[token.index(after:indexFirstPeriod)..<indexSecondPeriod]))")

            if let payload = String(token[token.index(after:indexFirstPeriod)..<indexSecondPeriod]).fromBase64()
            {
                print("Payload: \(payload)")
                
                struct payloadResult: Codable{
                    let sub: String
                    let userId: String
                    let iat: UInt64
                    let exp: UInt64
                }
                
                let decoder = JSONDecoder()
                
                if let payloadData = payload.data(using: .utf8){
                    let result = try? decoder.decode(payloadResult.self, from: payloadData)
                    if let result = result {
                        
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

        switch api_version {
        case .ZE:
            login_ZE(callback:c)
        case .MyRv1, .MyRv2:
            login_MyR(callback:c)
        case .none:
            ()
        }
    }
    
    func login_MyR (callback:@escaping(Bool)->Void) {
        print ("New API login")
        myR = MyR(username: userName!, password: password!)
        myR.handleLoginProcess(onError: {DispatchQueue.main.async{callback(false)}}, onSuccess: {DispatchQueue.main.async{callback(true)}}) // later change latter to true
    }
        
    func login_ZE (callback:@escaping(Bool)->Void) {
        struct Credentials: Codable {
                     let username: String
                     let password: String
                 }
      
        let credentials = Credentials(username: userName!,
                                      password: password!)
        guard let uploadData = try? JSONEncoder().encode(credentials) else {
            callback(false)
            return
        }
        
        //print("login - Sending: "+String(decoding: uploadData, as: UTF8.self))
        os_log("Sending login credentials: %s", log: self.serviceLog, type: .default, String(decoding: uploadData, as: UTF8.self))

        let loginURL = baseURL + "/user/login"
        let url = URL(string: loginURL)!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let task = URLSession.shared.uploadTask(with: request, from: uploadData) { data, response, error in
            if let error = error {
                //print ("URLSession error: \(error)")
                os_log("URLSession error: %{public}s", log: self.serviceLog, type: .error, error.localizedDescription)
                DispatchQueue.main.async {
                    callback(false)
                }
                return
            }
            guard let resp = response as? HTTPURLResponse,
                (200...299).contains(resp.statusCode) else {
                    //print ("server error")
                    os_log("server error, statusCode = %{public}d", log: self.serviceLog, type: .error, (response as? HTTPURLResponse)?.statusCode ?? 0)
                    DispatchQueue.main.async {
                        callback(false)
                    }
                    return
            }
            if let mimeType = resp.mimeType,
                mimeType == "application/json",
                let data = data,
                let dataString = String(data: data, encoding: .utf8) {
                print ("got login data: \(dataString)")
                
                struct loginResult: Codable {
                    var token: String
                    var xsrfToken: String
                    var user: User
                    struct User: Codable {
                        var id: String
                        var locale: String
                        var country: String
                        var timezone: String
                        var email: String
                        var first_name: String
                        var last_name: String
                        var phone_number: String
                        var vehicle_details: Vehicle_Details
                        struct Vehicle_Details: Codable {
                            var timezone: String
                            var VIN: String
                            var activation_code: String
                            var phone_number: String
                        }
                        var scopes:[String]
                        var active_account: String
                        var associated_vehicles:[Associated_Vehicles]
                        struct Associated_Vehicles: Codable {
                            var VIN: String
                            var activation_code: String
                            var user_id: String
                        }
                        var gdc_uid: String
                    }
                }
                
                do{
                    let decoder = JSONDecoder()
                    let result = try decoder.decode(loginResult.self, from: data)
                    
                    /*
                    print("Number of vehicles: " + String(format: "%d", result.user.associated_vehicles.count))
                    var i=0
                    for vehicle in result.user.associated_vehicles{
                        print("\(i):"+vehicle.VIN)
                        i+=1;
                    }
                    */
                    
                    self.vehicleIdentification = result.user.vehicle_details.VIN
                    self.activationCode = result.user.vehicle_details.activation_code
                    self.xsrfToken = result.xsrfToken
                    self.token = result.token
                    self.tokenExpiry = self.extractExpiryDate(ofToken: self.token)
                    
                    
                    DispatchQueue.main.async {
                        callback(true)
                    }
                } catch {
                    print (error)
                    DispatchQueue.main.async {
                        callback(false)
                    }
                }
            }
        }
        task.resume()
    }
    
    
    public func renewToken (callback:@escaping(Bool)->Void) {
        os_log("renewToken", log: serviceLog, type: .default)

        struct Refresh: Codable {
            let token: String
        }
        guard (userName != nil && password != nil) else{
            callback(false)
            return
        }
        let refresh = Refresh(token: token!)
        guard let uploadData = try? JSONEncoder().encode(refresh) else {
            callback(false)
            return
        }
        
        //        print(String(data: uploadData, encoding: .utf8)!)
        print("renew - Sending: "+String(decoding: uploadData, as: UTF8.self))
        
        let refreshURL = baseURL + "/user/token/refresh"
        let url = URL(string: refreshURL)!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token!)", forHTTPHeaderField: "Authorization")
        request.setValue("\(xsrfToken!)", forHTTPHeaderField: "X-XSRF-TOKEN")


        
        let task = URLSession.shared.uploadTask(with: request, from: uploadData) { data, response, error in
            if let error = error {
                //print ("error: \(error)")
                os_log("URLSession error: %{public}s", log: self.serviceLog, type: .error, error.localizedDescription)
                DispatchQueue.main.async {
                    callback(false)
                }
                return
            }
            guard let resp = response as? HTTPURLResponse,
                (200...299).contains(resp.statusCode) else {
                    //print ("server error")
                    os_log("server error, statusCode = %{public}d", log: self.serviceLog, type: .error, (response as? HTTPURLResponse)?.statusCode ?? 0)
                    DispatchQueue.main.async {
                        callback(false)
                    }
                    return
            }
            if let mimeType = resp.mimeType,
                mimeType == "application/json",
                let data = data,
                let dataString = String(data: data, encoding: .utf8) {
                print ("got renew token data: \(dataString)")
                
                
                struct refreshResult: Codable {
                    var token: String
                }
                
                do{
                    let decoder = JSONDecoder()
                    let result = try decoder.decode(refreshResult.self, from: data)
                    
                    self.token = result.token
                    self.tokenExpiry = self.extractExpiryDate(ofToken: self.token)

                    DispatchQueue.main.async {
                        callback(true)
                    }
                    
                    
                } catch {
                    print (error)
                }
            }
        }
        task.resume()
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

            self.cache.remaining_range=234.5

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
        
        
        switch api_version {
        case .ZE:
            batteryState_ZE(callback:c)
        case .MyRv1, .MyRv2:
            batteryState_MyR(callback:c)
        case .none:
            ()
        }
    }
    func batteryState_MyR(callback:@escaping  (Bool, Bool, Bool, UInt8, Float, UInt64, String?, Int?) -> ()) {
     
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {

        callback(true,
                 false,
                 false,
                 0,
                 0.0,
                 0,
                 nil,
                 nil)
            
        }

    }
    func batteryState_ZE(callback:@escaping  (Bool, Bool, Bool, UInt8, Float, UInt64, String?, Int?) -> ()) {

        let batteryURL = baseURL + "/vehicle/" + vehicleIdentification! + "/battery"
        
        let tString = ""
        let uploadData = tString.data(using: String.Encoding.utf8)
        
        let url = URL(string: batteryURL)!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token!)", forHTTPHeaderField: "Authorization")
        request.setValue("\(xsrfToken!)", forHTTPHeaderField: "X-XSRF-TOKEN")
        
        let task = URLSession.shared.uploadTask(with: request, from: uploadData) { data, response, error in
            if let error = error {
                //print ("error: \(error)")
                os_log("URLSession error: %{public}s", log: self.serviceLog, type: .error, error.localizedDescription)
                DispatchQueue.main.async {
                    callback(true,
                             false,
                             false,
                             0,
                             0.0,
                             0,
                             nil,
                             nil)
                }
                return
            }
            guard let resp = response as? HTTPURLResponse,
                (200...299).contains(resp.statusCode) else {
                    //print ("server error")
                    os_log("server error, statusCode = %{public}d", log: self.serviceLog, type: .error, (response as? HTTPURLResponse)?.statusCode ?? 0)

                    DispatchQueue.main.async {
                        callback(true,
                                 false,
                                 false,
                                 0,
                                 0.0,
                                 0,
                                 nil,
                                 nil)
                    }
                    return
            }
            if let mimeType = resp.mimeType,
                mimeType == "application/json",
                let data = data,
                let dataString = String(data: data, encoding: .utf8) {
                print ("got battery state data: \(dataString)")
                
                struct batteryStatusAlways: Codable{
                    var charging: Bool
                    var plugged: Bool
                    var charge_level: UInt8
                    var remaining_range: Float
                    var last_update: UInt64 //TimeInterval
                }
                struct batteryStatusPlugged: Codable{
                    var charging: Bool
                    var plugged: Bool
                    var charge_level: UInt8
                    var remaining_range: Float
                    var last_update: UInt64 //TimeInterval
                    var charging_point: String
                }
                struct batteryStatusPluggedAndCharging: Codable{
                    var charging: Bool
                    var plugged: Bool
                    var charge_level: UInt8
                    var remaining_range: Float
                    var last_update: UInt64 //TimeInterval
                    var charging_point: String
                    var remaining_time: Int
                }
                /*
                 The remaining_range is in Kilometres.
                 The last_update is a Unix timestamp.
                 
                 The charging_point is available only when plugged is true.
                 The remaining_time is available only when charging is true. The remaining_time is in minutes.
                 */
                
                let decoder = JSONDecoder()
                if let resultAlways = try? decoder.decode(batteryStatusAlways.self, from: data){
                    if resultAlways.plugged {
                        if let resultPlugged = try? decoder.decode(batteryStatusPlugged.self, from: data){
                            if  resultPlugged.charging {
                                if let resultPluggedAndCharging = try? decoder.decode(batteryStatusPluggedAndCharging.self, from: data)
                                { // plugged and charging
                                    
                                    self.cache.charging=resultPluggedAndCharging.charging
                                    self.cache.plugged=resultPluggedAndCharging.plugged
                                    self.cache.charge_level=resultPluggedAndCharging.charge_level
                                    self.cache.remaining_range=resultPluggedAndCharging.remaining_range
                                    self.cache.last_update=resultPluggedAndCharging.last_update
                                    self.cache.charging_point=resultPluggedAndCharging.charging_point
                                    self.cache.remaining_time=resultPluggedAndCharging.remaining_time

                                    DispatchQueue.main.async {
                                        callback(false,
                                                 resultPluggedAndCharging.charging,
                                                 resultPluggedAndCharging.plugged,
                                                 resultPluggedAndCharging.charge_level,
                                                 resultPluggedAndCharging.remaining_range,
                                                 resultPluggedAndCharging.last_update,
                                                 resultPluggedAndCharging.charging_point,
                                                 resultPluggedAndCharging.remaining_time)
                                    }
                                } else {
                                    // error: resultPluggedAndCharging == nil
                                    print ("unexpected server response (resultPluggedAndCharging == nil)")
                                    DispatchQueue.main.async {
                                        callback(true,
                                                 false,
                                                 false,
                                                 0,
                                                 0.0,
                                                 0,
                                                 nil,
                                                 nil)
                                    }
                                }
                            } else { // not charging
                                
                                self.cache.charging=resultPlugged.charging
                                self.cache.plugged=resultPlugged.plugged
                                self.cache.charge_level=resultPlugged.charge_level
                                self.cache.remaining_range=resultPlugged.remaining_range
                                self.cache.last_update=resultPlugged.last_update
                                self.cache.charging_point=resultPlugged.charging_point
                                self.cache.remaining_time=nil
                                
                                DispatchQueue.main.async {
                                    callback(false,
                                             resultPlugged.charging,
                                             resultPlugged.plugged,
                                             resultPlugged.charge_level,
                                             resultPlugged.remaining_range,
                                             resultPlugged.last_update,
                                             resultPlugged.charging_point,
                                             nil)
                                }
                            }
                        } else {
                            // error: resultPlugged == nil
                            print ("unexpected server response (resultPlugged == nil)")
                            DispatchQueue.main.async {
                                callback(true,
                                         false,
                                         false,
                                         0,
                                         0.0,
                                         0,
                                         nil,
                                         nil)
                            }
                        }
                    } else { // not plugged
                        
                        self.cache.charging=resultAlways.charging
                        self.cache.plugged=resultAlways.plugged
                        self.cache.charge_level=resultAlways.charge_level
                        self.cache.remaining_range=resultAlways.remaining_range
                        self.cache.last_update=resultAlways.last_update
                        self.cache.charging_point=nil
                        self.cache.remaining_time=nil

                        DispatchQueue.main.async {
                            callback(false,
                                     resultAlways.charging,
                                     resultAlways.plugged,
                                     resultAlways.charge_level,
                                     resultAlways.remaining_range,
                                     resultAlways.last_update,
                                     nil,
                                     nil)
                            
                        }
                    }
                } else { // error: resultAlways == nil
                    // e.g. {"charging":false,"plugged":false,"charge_level":0,"last_update":1546456962000}
                    print ("unexpected server response (resultAlways == nil)")
                    DispatchQueue.main.async {
                        callback(true,
                                 false,
                                 false,
                                 0,
                                 0.0,
                                 0,
                                 nil,
                                 nil)
                    }
                }
            } else {
                print ("unexpected server response")
                DispatchQueue.main.async {
                    callback(true,
                             false,
                             false,
                             0,
                             0.0,
                             0,
                             nil,
                             nil)
                }
            }
        }
        task.resume()
    }
    
    public func isTokenExpired()->Bool {
        let date = Date()
        let now = UInt64(date.timeIntervalSince1970)
        if (  tokenExpiry != nil && tokenExpiry! > now + 60) { // must be valid for at least one more minute
            print("Token still valid")
            return false
        } else {
            print("Token expired or will expire too soon (or expiry date is nil), must renew")
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

        switch api_version {
              case .ZE:
                precondition_ZE(command: command, date: date, callback:callback)
              case .MyRv1, .MyRv2:
                precondition_MyR(command: command, date: date, callback:callback)
              case .none:
                  ()
              }
    }
    
    public func precondition_MyR(command:PreconditionCommand, date: Date?, callback:@escaping  (Bool, PreconditionCommand, Date?) -> ()) {
        DispatchQueue.main.async {
            callback(false, command, date)
        }
    }
    
    public func precondition_ZE(command:PreconditionCommand, date: Date?, callback:@escaping  (Bool, PreconditionCommand, Date?) -> ()) {

        let preconditionURL = baseURL + "/vehicle/" + vehicleIdentification! + "/air-conditioning"
        let preconditionWithTimerURL = baseURL + "/vehicle/" + vehicleIdentification! + "/air-conditioning/scheduler"
        
        var strDate = ""
        var tString = ""
        var url:URL
        var httpMethod: String?
   
        switch command {
        case .now:
            url = URL(string: preconditionURL)!
            httpMethod = "POST"
        case .later:
            if (date != nil){
                let dateFormatter = DateFormatter()
                let timezone = TimeZone.current.abbreviation() ?? "CET"  // get current TimeZone abbreviation or set to CET
                dateFormatter.timeZone = TimeZone(abbreviation: timezone) //Set timezone that you want
                dateFormatter.locale = NSLocale.current
                dateFormatter.dateFormat = "HHmm"
                strDate = dateFormatter.string(from: date!)
                tString = "{\"start\":\"\(strDate)\"}"
            }
            url = URL(string: preconditionWithTimerURL)!
            httpMethod = "POST"

        case .delete:
            url = URL(string: preconditionWithTimerURL)!
            httpMethod = "DELETE"

        case .read:
            url = URL(string: preconditionWithTimerURL)!
            httpMethod = "GET"

        }
        
        let uploadData = tString.data(using: String.Encoding.utf8)
        
        var request = URLRequest(url: url)
        request.httpMethod = httpMethod
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token!)", forHTTPHeaderField: "Authorization")
        request.setValue("\(xsrfToken!)", forHTTPHeaderField: "X-XSRF-TOKEN")

        let task = URLSession.shared.uploadTask(with: request, from: uploadData) { data, response, error in
            if let error = error {
                //print ("error: \(error)")
                os_log("URLSession error: %{public}s", log: self.serviceLog, type: .error, error.localizedDescription)
                DispatchQueue.main.async {
                    callback(true, command, nil)
                }
                return
            }
            guard let response2 = response as? HTTPURLResponse,
                (200...299).contains(response2.statusCode) else {
                    //print ("server error")
                    //print ((response as! HTTPURLResponse).description)
                    os_log("server error, statusCode = %{public}d", log: self.serviceLog, type: .error, (response as? HTTPURLResponse)?.statusCode ?? 0)

                    DispatchQueue.main.async {
                        callback(true, command, nil)
                    }
                    return
                    
                    
                    /*
                     If called too often:
                     
                     server error
                     <NSHTTPURLResponse: 0x2827f9a20> { URL: https://www.services.renault-ze.com/api/vehicle/xxx/air-conditioning } { Status Code: 503, Headers {
                     "Access-Control-Allow-Credentials" =     (
                     true
                     );
                     "Access-Control-Allow-Headers" =     (
                     "x-requested-with, content-type, accept, authorization, x-xsrf-token, if-modified-since"
                     );
                     "Access-Control-Allow-Methods" =     (
                     "POST, PUT, GET, OPTIONS, DELETE"
                     );
                     "Access-Control-Allow-Origin" =     (
                     "https://services.renault-ze.com"
                     );
                     "Access-Control-Max-Age" =     (
                     3600
                     );
                     Connection =     (
                     close
                     );
                     "Content-Encoding" =     (
                     gzip
                     );
                     "Content-Type" =     (
                     "application/json;charset=UTF-8"
                     );
                     Date =     (
                     "Tue, 25 Dec 2018 14:02:02 GMT"
                     );
                     Server =     (
                     Apache
                     );
                     "Transfer-Encoding" =     (
                     Identity
                     );
                     Vary =     (
                     "Accept-Encoding"
                     );
                     "X-Application-Context" =     (
                     "application:prod"
                     );
                     "X-Frame-Options" =     (
                     SAMEORIGIN
                     );
                     } }
                     
                     
                     */
            }
            
            switch command {
            case .read:
                
                // analyse response
                if let mimeType = response2.mimeType,
                    mimeType == "application/json",
                    let data = data,
                    let dataString = String(data: data, encoding: .utf8) {
                    print ("got ac timer data: \(dataString)")
                    // got ac timer data: {"next_start":"1313"}
                    // got ac timer data: {"next_start":"0804"}
                    
                    
                    struct acTimerStatus: Codable{
                        var next_start: String
                    }
                    
                    let decoder = JSONDecoder()
                    if let result = try? decoder.decode(acTimerStatus.self, from: data){
                        print ("acTimerStatus: \(result.next_start)")
                        
                        // combine time received with today's date:
                        let today = Date()
                        let dateFormatter2 = DateFormatter()
                        dateFormatter2.dateFormat = "dd.MM.yyyy "
                        let strDateOnly = dateFormatter2.string(from: today)
                        
                        let dateFormatter = DateFormatter()
                        dateFormatter.dateFormat = "dd.MM.yyyy HHmm"
                        if var date = dateFormatter.date(from: strDateOnly+result.next_start)
                        {
                            if (date<today){
                                // if in the past, add one day
                                date += TimeInterval(24*3600)
                            }
                            
                            // date now is the correct time and date.
                            
                            // only to check:
                            let dateFormatter3 = DateFormatter()
                            dateFormatter3.dateFormat = "dd.MM.yyyy HH:mm:ss"
                            let strDate = dateFormatter3.string(from: date)
                            print("Date for next A/C timer: \(strDate)")
                            DispatchQueue.main.async {
                                callback(false, command, date)
                            }
                        }
                        
                    } else {
                        print ("unexpected server response (result for acTimerStatus == nil)")
                        DispatchQueue.main.async {
                            callback(true, command, nil)
                        }
                        
                    }
                    
                } else {
                    
                        /*
                         If the A/C timer was not set (or deleted):
                         Status Code: 204 (meaning: NO CONTENT)
                         In this case, no decodable data is returned (data!.count == 0), and mimeType = "text/html"
                         */
                        if response2.statusCode == 204
                        {
                            print ("error 204 server response")
                            print("Date for next A/C timer: NOT SET")
                            DispatchQueue.main.async {
                                callback(false, command, nil)
                            }
                        } else {
                            print ("unexpected server response")
                            DispatchQueue.main.async {
                                callback(true, command, nil)
                            }
                        }
                }
                
            default:
                // there is no reply to analyze, so just proceed with the callback
                DispatchQueue.main.async {
                    callback(false, command, date) // no error
                }

            }
        }
        task.resume()
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
        
        switch api_version {
               case .ZE:
                airConditioningLastState_ZE(callback:c)
               case .MyRv1, .MyRv2:
                airConditioningLastState_MyR(callback:c)
               case .none:
                   ()
               }
    }
    
    public func airConditioningLastState_MyR(callback:@escaping  (Bool, UInt64, String?, String?) -> ()) {
        DispatchQueue.main.async {
            callback(false,
                     1550874142000,
                     "-",
                     "SUCCESS")
        }
    }

    public func airConditioningLastState_ZE(callback:@escaping  (Bool, UInt64, String?, String?) -> ()) {

        let acLastURL = baseURL + "/vehicle/" + vehicleIdentification! + "/air-conditioning/last"
        
        let tString = ""
        let uploadData = tString.data(using: String.Encoding.utf8)
        
        let url = URL(string: acLastURL)!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token!)", forHTTPHeaderField: "Authorization")
        request.setValue("\(xsrfToken!)", forHTTPHeaderField: "X-XSRF-TOKEN")
        
        let task = URLSession.shared.uploadTask(with: request, from: uploadData) { data, response, error in
            if let error = error {
                //print ("error: \(error)")
                os_log("URLSession error: %{public}s", log: self.serviceLog, type: .error, error.localizedDescription)
                DispatchQueue.main.async {
                    callback(true,
                             0,
                             nil,
                             nil)
                }
                return
            }
            guard let resp = response as? HTTPURLResponse,
                (200...299).contains(resp.statusCode) else {
                    //print ("server error")
                    os_log("server error, statusCode = %{public}d", log: self.serviceLog, type: .error, (response as? HTTPURLResponse)?.statusCode ?? 0)
                    DispatchQueue.main.async {
                        callback(true,
                                 0,
                                 nil,
                                 nil)
                    }
                    return
            }
            
            if let mimeType = resp.mimeType,
                mimeType == "application/json",
                let data = data,
                let dataString = String(data: data, encoding: .utf8) {
                print ("got ac last data: \(dataString)")
                
                struct acLastStatus: Codable{
                    var date: UInt64 //TimeInterval
                    var type: String
                    var result: String
                }
                
                /*
                 
                 {"date":1545747446000,"type":"USER_REQUEST","result":"ERROR"}
                 
                 The last_update is a Unix timestamp in ms
                 
                 */
                
                let decoder = JSONDecoder()
                if let result = try? decoder.decode(acLastStatus.self, from: data){
                    DispatchQueue.main.async {
                        callback(false,
                                 result.date,
                                 result.type,
                                 result.result)
                        
                    }
                } else {
                    //print ("unexpected server response (result for acLastStatus == nil)")
                    os_log("unexpected server response (result for acLastStatus == nil)", log: self.serviceLog, type: .default)

                    DispatchQueue.main.async {
                        callback(true,
                                 0,
                                 nil,
                                 nil)
                    }
                }
            } else {
                
                /*
                 If the A/C was not used for a while, the server will forget the last usage and return:
                 Status Code: 204 (meaning: NO CONTENT)
                 In this case, no decodable data is returned (data!.count == 0), and mimeType = "text/html"
                 */
                if resp.statusCode == 204
                {
                    //print ("error 204 server response")
                    os_log("error 204 server response", log: self.serviceLog, type: .default)

                    DispatchQueue.main.async {
                        callback(false,
                                 0,
                                 nil,
                                 nil)
                    }
                } else {
                    print ("unexpected server response")
                    DispatchQueue.main.async {
                        callback(true,
                                 0,
                                 nil,
                                 nil)
                    }
                }
            }
        }
        task.resume()
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
        
        let batteryURL = baseURL + "/vehicle/" + vehicleIdentification! + "/charge"
        
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
}
