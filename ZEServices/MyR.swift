//
//  MyR.swift
//  MyR Services
//
//  Created by Dr. Guido Mocken on 30.01.20.
//  Copyright © 2020 Dr. Guido Mocken. All rights reserved.
//

import Foundation
import os



class MyR {
    struct ApiKeyResult: Codable {
        var servers: Servers
        struct Servers: Codable {
            var wiredProd: ServerAndKey
            var gigyaProd: ServerAndKey
            struct ServerAndKey: Codable {
                var target: String
                var apikey: String
            }
        }
    }
    
    struct SessionInfo: Codable {
        var sessionInfo: SessionInfo
        struct SessionInfo: Codable {
            var cookieValue: String
        }
    }
    
    
    struct AccountInfo: Codable {
        var data:Data
        struct Data: Codable {
            var personId: String
        }
    }
    
    struct TokenInfo: Codable {
          var id_token:String
    }
    
    
    struct KamereonAccountInfo: Codable {
        var accounts:[Accounts]
        struct Accounts: Codable {
            var accountId: String
        }
    }
    
    struct KamereonTokenInfo: Codable {
        var accessToken:String
        var refreshToken:String
        var idToken:String
    }

    struct VehiclesInfo: Codable {
        var vehicleLinks:[vehicles]
        struct vehicles: Codable {
            var vin: String
            var mileage: Int
        }
    }
    
  
    enum Version {
        case v1
        case v2
        
        var string: String {
            switch self{
            case .v1:
                return "v1"
            case .v2:
                return "v2"
            }
        }
    }
    
    var username: String!
    var password: String!
    var version:Version
    
    init(username u:String, password p:String, version v:Version) {
        username = u
        password = p
        version = v
    }
    
    struct Context{
        var apiKeysAndUrls: ApiKeyResult?
        var sessionInfo: SessionInfo?
        var accountInfo: AccountInfo?
        var tokenInfo: TokenInfo?
        var kamereonAccountInfo: KamereonAccountInfo?
        var kamereonTokenInfo: KamereonTokenInfo?
        var vehiclesInfo: VehiclesInfo?
    }
    var context = Context()
    
    let country = "DE" // GB"
    let language = "de_DE" //en_GB"
    
    let serviceLog = OSLog(subsystem: "com.grm.ZEServices", category: "ZOE-MYR")

    
    func decodeToken(token:String) {
        print("Decoding token:")
        let indexFirstPeriod = token.firstIndex(of: ".") ?? token.startIndex
        let header = String(token[..<indexFirstPeriod]).fromBase64()
        print("Header: \(header!)") // first part
        let indexSecondPeriod = token[token.index(after:indexFirstPeriod)...].firstIndex(of: ".") ?? token.endIndex
        if let payload = String(token[token.index(after:indexFirstPeriod)..<indexSecondPeriod]).fromBase64(){ // second part
            print ("Payload: \(payload)")
        }
        // the third part is the signature of the JSON web token, and not decoded/validated here
    }
    
    
    func handleLoginProcess(onError errorCode:@escaping()->Void, onSuccess actionCode:@escaping(_ vin:String?, _ token:String?, _ context:Context)->Void) {
        
        // Fetch URLs and API keys from a fixed URL
        let endpointUrl = URL(string: "https://renault-wrd-prod-1-euw1-myrapp-one.s3-eu-west-1.amazonaws.com/configuration/android/config_" + language + ".json")!
        let components = URLComponents(url: endpointUrl, resolvingAgainstBaseURL: false)!
        self.fetchJsonDataViaHttp(usingMethod: .GET, withComponents: components, withHeaders: nil) { (result:ApiKeyResult?) -> Void in
            if result != nil {
                
                print("Successfully retrieved targets and api keys:")
                print("Kamereon: \(result!.servers.wiredProd.target), key=\(result!.servers.wiredProd.apikey)")
                print("Gigya: \(result!.servers.gigyaProd.target), key=\(result!.servers.gigyaProd.apikey)")
                
                self.context.apiKeysAndUrls = result // save for later use
                
                // Fetch session key from the previously learned URL using the retreived API key
                let endpointUrl = URL(string: self.context.apiKeysAndUrls!.servers.gigyaProd.target + "/accounts.login")!
                var components = URLComponents(url: endpointUrl, resolvingAgainstBaseURL: false)!
                components.queryItems = [
                    URLQueryItem(name: "apiKey", value: self.context.apiKeysAndUrls!.servers.gigyaProd.apikey),
                    URLQueryItem(name: "loginID", value: self.username),
                    URLQueryItem(name: "password", value: self.password),
                    URLQueryItem(name: "sessionExpiration",value: "900") // try to set it myself, so I know the value
                    // see https://developers.gigya.com/display/GD/accounts.login+REST
                ]
                self.fetchJsonDataViaHttp(usingMethod: .POST, withComponents: components, withHeaders: nil) { (result:SessionInfo?) -> Void in
                    if result != nil {
                        print("Successfully retrieved session key:")
                        print("Cookie value: \(result!.sessionInfo.cookieValue)")
                        
                        self.context.sessionInfo = result // save for later use.
                        // do not know how to decode the cookie.
                        
                        let endpointUrl = URL(string: self.context.apiKeysAndUrls!.servers.gigyaProd.target + "/accounts.getAccountInfo")!
                        var components = URLComponents(url: endpointUrl, resolvingAgainstBaseURL: false)!
                        components.queryItems = [
                            URLQueryItem(name: "login_token", value: self.context.sessionInfo!.sessionInfo.cookieValue),
                            URLQueryItem(name: "apiKey", value: self.context.apiKeysAndUrls!.servers.gigyaProd.apikey),
                        ]
                        
                        // Fetch person ID from the same URL using the retrieved session key
                        self.fetchJsonDataViaHttp(usingMethod: .POST, withComponents: components, withHeaders: nil) { (result:AccountInfo?) -> Void in
                            if result != nil {
                                print("Successfully retrieved account info:")
                                print("person ID: \(result!.data.personId)")
                                
                                self.context.accountInfo = result // save for later use
                                
                                let endpointUrl = URL(string: self.context.apiKeysAndUrls!.servers.gigyaProd.target + "/accounts.getJWT")!
                                var components = URLComponents(url: endpointUrl, resolvingAgainstBaseURL: false)!
                                components.queryItems = [
                                    URLQueryItem(name: "login_token", value: self.context.sessionInfo!.sessionInfo.cookieValue),
                                    URLQueryItem(name: "apiKey", value: self.context.apiKeysAndUrls!.servers.gigyaProd.apikey),
                                    URLQueryItem(name: "fields", value: "data.personId,data.gigyaDataCenter"),
                                    URLQueryItem(name: "expiration", value: "900")
                                ]
                                
                                // Fetch Gigya JWT token from the same URL using the retrieved session key
                                self.fetchJsonDataViaHttp(usingMethod: .POST, withComponents: components, withHeaders: nil) { (result:TokenInfo?) -> Void in
                                    if result != nil {
                                        print("Successfully retrieved Gigya JWT token:")
                                        print("Gigya JWT token:")
                                        self.context.tokenInfo = result // save for later use
                                        self.decodeToken(token:result!.id_token) // "exp" fields contains timestamp 900s in the future
                                        
                                        let endpointUrl = URL(string: self.context.apiKeysAndUrls!.servers.wiredProd.target + "/commerce/v1/persons/"+self.context.accountInfo!.data.personId)!
                                        var components = URLComponents(url: endpointUrl, resolvingAgainstBaseURL: false)!
                                        components.queryItems = [
                                            URLQueryItem(name: "country", value: self.country)
                                        ]
                                        let headers = [
                                            "x-gigya-id_token":self.context.tokenInfo!.id_token,
                                            "apikey":self.context.apiKeysAndUrls!.servers.wiredProd.apikey
                                        ]
                                        // Fetch Kamereon account ID from the person-id dependent URL using the retrieved Gigya JWT token
                                        self.fetchJsonDataViaHttp(usingMethod: .GET, withComponents: components, withHeaders: headers) { (result:KamereonAccountInfo?) -> Void in
                                            if result != nil {
                                                print("Successfully retrieved Kamereon accounts:")
                                                print("Account id 0: \(result!.accounts[0].accountId)")
                                                
                                                self.context.kamereonAccountInfo = result // save for later use
                                                
                                                
                                                let endpointUrl = URL(string: self.context.apiKeysAndUrls!.servers.wiredProd.target + "/commerce/v1/accounts/"+self.context.kamereonAccountInfo!.accounts[0].accountId + "/kamereon/token")!
                                                var components = URLComponents(url: endpointUrl, resolvingAgainstBaseURL: false)!
                                                components.queryItems = [
                                                    URLQueryItem(name: "country", value: self.country)
                                                ]
                                                let headers = [
                                                    "x-gigya-id_token":self.context.tokenInfo!.id_token,
                                                    "apikey":self.context.apiKeysAndUrls!.servers.wiredProd.apikey
                                                ]
                                                // Fetch Kamereon accessToken from the account dependent URL using the retrieved Gigya JWT token
                                                self.fetchJsonDataViaHttp(usingMethod: .GET, withComponents: components, withHeaders: headers) { (result:KamereonTokenInfo?) -> Void in
                                                    if result != nil {
                                                        print("Successfully retrieved Kamereon token:")
                                                        print("accessToken:")
                                                        self.context.kamereonTokenInfo = result // save for later use
                                                        self.decodeToken(token:result!.accessToken) // "expires_in":3600000 = 1h ?
                                                        // not used, just investigating:
//                                                        print("refreshToken:")
//                                                        self.decodeToken(token: result!.refreshToken)
//                                                        print("idToken:")
//                                                        self.decodeToken(token: result!.idToken)

                                                        let endpointUrl = URL(string: self.context.apiKeysAndUrls!.servers.wiredProd.target + "/commerce/v1/accounts/"+self.context.kamereonAccountInfo!.accounts[0].accountId + "/vehicles")!
                                                        var components = URLComponents(url: endpointUrl, resolvingAgainstBaseURL: false)!
                                                        components.queryItems = [
                                                            URLQueryItem(name: "country", value: self.country)
                                                        ]
                                                        let headers = [
                                                            "x-gigya-id_token": self.context.tokenInfo!.id_token,
                                                            "apikey":self.context.apiKeysAndUrls!.servers.wiredProd.apikey,
                                                            "x-kamereon-authorization": "Bearer " + self.context.kamereonTokenInfo!.accessToken
                                                        ]
                                                        // Fetch VIN using the retrieved access token
                                                        self.fetchJsonDataViaHttp(usingMethod: .GET, withComponents: components, withHeaders: headers) { (result:VehiclesInfo?) -> Void in
                                                            if result != nil {
                                                                print("Successfully retrieved Vehicles.")
                                                                print("VIN: \(result!.vehicleLinks[0].vin)")
                                                                print("Mileage: \(result!.vehicleLinks[0].mileage)")
                                                                self.context.vehiclesInfo = result // save for later use
                                                                
                                                                // must explicitly pass results, because the actionCode closure would use older captured values otherwise
                                                                actionCode(result!.vehicleLinks[0].vin, self.context.tokenInfo!.id_token, self.context)
                                                                
                                                            } else {
                                                                errorCode()
                                                            }
                                                        } // end of closure
                                                    } else {
                                                        print("Could not retrieve Kamereon token - try without anyway")
                                                        let endpointUrl = URL(string: self.context.apiKeysAndUrls!.servers.wiredProd.target + "/commerce/v1/accounts/"+self.context.kamereonAccountInfo!.accounts[0].accountId + "/vehicles")!
                                                        var components = URLComponents(url: endpointUrl, resolvingAgainstBaseURL: false)!
                                                        components.queryItems = [
                                                            URLQueryItem(name: "country", value: self.country)
                                                        ]
                                                        let headers = [
                                                            "x-gigya-id_token": self.context.tokenInfo!.id_token,
                                                            "apikey":self.context.apiKeysAndUrls!.servers.wiredProd.apikey
                                                        ]
                                                        // Fetch VIN using the retrieved access token
                                                        self.fetchJsonDataViaHttp(usingMethod: .GET, withComponents: components, withHeaders: headers) { (result:VehiclesInfo?) -> Void in
                                                            if result != nil {
                                                                print("Successfully retrieved Vehicles.")
                                                                print("VIN: \(result!.vehicleLinks[0].vin)")
                                                                print("Mileage: \(result!.vehicleLinks[0].mileage)")
                                                                self.context.vehiclesInfo = result // save for later use
                                                                
                                                                // must explicitly pass results, because the actionCode closure would use older captured values otherwise
                                                                actionCode(result!.vehicleLinks[0].vin, self.context.tokenInfo!.id_token, self.context)
                                                                
                                                            } else {
                                                                errorCode()
                                                            }
                                                        } // end of closure
                                                    }
                                                } // end of closure
                                            } else {
                                                errorCode()
                                            }
                                        } // end of closure
                                    } else {
                                        errorCode()
                                    }
                                } // end of closure
                            } else {
                                errorCode()
                            }
                        } // end of closure
                    } else {
                        errorCode()
                    }
                } // end of closure
            } else {
                errorCode()
            }
        } // end of closure
    }
    
    func getHeaders()->[String:String] {
        if context.kamereonTokenInfo != nil {
            return [
                "x-gigya-id_token": context.tokenInfo!.id_token,
                "apikey": context.apiKeysAndUrls!.servers.wiredProd.apikey,
                "x-kamereon-authorization": "Bearer " + context.kamereonTokenInfo!.accessToken,
                "Content-Type": "application/vnd.api+json"
            ]
        } else {
            return [
                "x-gigya-id_token": context.tokenInfo!.id_token,
                "apikey": context.apiKeysAndUrls!.servers.wiredProd.apikey,
                "Content-Type": "application/vnd.api+json"
            ]
        }
 
    }
    
    func batteryState(callback:@escaping  (Bool, Bool, Bool, UInt8, Float, UInt64, String?, Int?, Int?) -> ()) {
        struct BatteryInfoV2: Codable {
            var data: Data
            struct Data: Codable {
                var type: String
                var id: String
                var attributes: Attributes
                struct Attributes: Codable {
                    var batteryLevel: Int
                    var batteryTemperature: Int?
                    var chargingInstantaneousPower: Float?
                    var batteryAutonomy: Float?
                    var chargingRemainingTime: Int?
                    var plugStatus: Int
                    var timestamp: String
                    var chargingStatus: Float
                    var batteryCapacity: Int?
                    var batteryAvailableEnergy: Int?
                }
            }
        }
        
        /*
            not plugged, not charging:
         {"data":{"type":"Car","id":"...","attributes":{"timestamp":"2020-02-07T19:06:03+01:00","batteryLevel":63,"batteryTemperature":9,"batteryAutonomy":71,"batteryCapacity":0,"batteryAvailableEnergy":0,"plugStatus":0,"chargingStatus":-1.0}}}
         
        
        plugged and charging:
         {"data":{"type":"Car","id":"...","attributes":{"timestamp":"2020-02-07T21:17:35+01:00","batteryLevel":62,"batteryTemperature":9,"batteryAutonomy":70,"batteryCapacity":0,"batteryAvailableEnergy":0,"plugStatus":1,"chargingStatus":1.0}}}
         
         2020-02-07 21:22:04.731187+0100 ZoeStatus[43997:3264106] [ZOE-MYR] raw JSON data: {"data":{"type":"Car","id":"...","attributes":{"timestamp":"2020-02-07T21:21:26+01:00","batteryLevel":63,"batteryTemperature":9,"batteryAutonomy":71,"batteryCapacity":0,"batteryAvailableEnergy":0,"plugStatus":1,"chargingStatus":1.0,"chargingRemainingTime":300,"chargingInstantaneousPower":2300.0}}}

         
         */
        
        struct BatteryInfo: Codable {
            var data: Data
            struct Data: Codable {
                var type: String
                var id: String
                var attributes: Attributes
                struct Attributes: Codable {
                    var batteryLevel: Int
                    var batteryTemperature: Int?
                    var chargePower: Int?
                    var rangeHvacOff: Float?
                    var timeRequiredToFullSlow: Int?
                    var plugStatus: Int
                    var instantaneousPower: Int?
                    var lastUpdateTime: String
                    var chargeStatus: Int
                }
            }
        }
        /*
         Sample Data while slow charging:
         {
         "data":{
         "type":"Car",
         "id":"...",
         "attributes":{
         "batteryLevel":79,
         "batteryTemperature":11,
         "chargePower":1,
         "rangeHvacOff":98,
         "timeRequiredToFullSlow":175,
         "plugStatus":1,
         "instantaneousPower":2200,
         "lastUpdateTime":"2020-01-29T20:14:28+01:00",
         "chargeStatus":1
         }
         }
         }
         
         Sample Data while NOT charging:
         
         {"data":{"type":"Car","id":"...",
         "attributes":{
         "batteryTemperature":14,
         "chargeStatus":-1,
         "batteryLevel":59,
         "rangeHvacOff":78,
         "lastUpdateTime":"2020-01-31T17:39:52+01:00",
         "plugStatus":0}}
         }
         
         
         
         Sample data while plugged, but NOT charging:
         {"data":{"type":"Car","id":"...", "attributes":{"chargeStatus":-1,"batteryTemperature":16,"lastUpdateTime":"2020-02-03T23:24:54+01:00","plugStatus":1,"rangeHvacOff":106,"batteryLevel":81}}}
         
         Sometimes some required fields are missing:
         {"data":{"type":"Car","id":"...",
         "attributes":{"batteryTemperature":16,"chargeStatus":-1,"lastUpdateTime":"2020-02-05T23:54:19+01:00","plugStatus":0}}}
         
         
         */
        print ("\(context.apiKeysAndUrls!)")
        print ("\(context.vehiclesInfo!)")
        let endpointUrl = URL(string: context.apiKeysAndUrls!.servers.wiredProd.target + "/commerce/v1/accounts/" + context.kamereonAccountInfo!.accounts[0].accountId + "/kamereon/kca/car-adapter/" + version.string + "/cars/" + context.vehiclesInfo!.vehicleLinks[0].vin + "/battery-status")!
                
        var components = URLComponents(url: endpointUrl, resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "country", value: self.country)
        ]
        let headers = getHeaders()

        // Fetch info using the retrieved access token
        
        switch version {
        case .v1:
            self.fetchJsonDataViaHttp(usingMethod: .GET, withComponents: components, withHeaders: headers) { (result:BatteryInfo?) -> Void in
                if result != nil {
                    print("Successfully retrieved battery state V1:")
                    print("level: \(result!.data.attributes.batteryLevel)")
                    if (result!.data.attributes.batteryTemperature != nil){
                        print("battery temperature: \(result!.data.attributes.batteryTemperature!)")
                    }
                    var charging_point: String?
                    if let power=result!.data.attributes.chargePower {
                        switch power {
                        case 0:
                            charging_point = "INVALID"
                        case 1:
                            charging_point = "SLOW"
                        case 2:
                            charging_point = "FAST"
                        case 3:
                            charging_point = "ACCELERATED"
                        default:
                            charging_point = "\(power)"
                        }
                    }

                    // overwrite the above with power in kW if it is present
                    if let power=result!.data.attributes.instantaneousPower {
                        charging_point = "\(Float(power)/1000.0) kW"
                    }
                    
                    
                    let dateString = result!.data.attributes.lastUpdateTime // e.g. "2020-01-31T17:39:52+01:00"
                    
                    let dateFormatter = DateFormatter()
                    dateFormatter.locale = NSLocale.current
                    dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZZZZZ"
                    let date = dateFormatter.date(from:dateString)!
                    let unixMs = UInt64(date.timeIntervalSince1970) * 1000
                    print(date)
                    
                    // batteryState(error:charging:plugged:charge_level:remaining_range:last_update:charging_point:remaining_time:)
                    DispatchQueue.main.async{
                        callback(false,
                                 result!.data.attributes.chargeStatus > 0,
                                 result!.data.attributes.plugStatus > 0,
                                 UInt8(result!.data.attributes.batteryLevel),
                                 result!.data.attributes.rangeHvacOff ?? -1.0,
                                 unixMs,
                                 charging_point,
                                 result!.data.attributes.timeRequiredToFullSlow,
                                 result!.data.attributes.batteryTemperature)
                        
                    }
                } else {
                    DispatchQueue.main.async{
                        callback(true,
                                 false,
                                 false,
                                 0,
                                 0.0,
                                 0,
                                 nil,
                                 nil,
                                 nil)
                    }
                }
            }
            
        case .v2:
            self.fetchJsonDataViaHttp(usingMethod: .GET, withComponents: components, withHeaders: headers) { (result:BatteryInfoV2?) -> Void in
                if result != nil {
                    print("Successfully retrieved battery state V2:")
                    print("level: \(result!.data.attributes.batteryLevel)")
                    if (result!.data.attributes.batteryTemperature != nil){
                        print("battery temperature: \(result!.data.attributes.batteryTemperature!)")
                    }
                    var charging_point: String?
                    if let power=result!.data.attributes.chargingInstantaneousPower {
                        switch power {
                        case -10...0:
                            charging_point = "INVALID"
/*
                        case 0.1..<11000.0:
                            charging_point = "SLOW"
                        case 11000.0..<22000.0:
                            charging_point = "FAST"
                        case 22000.0..<100000.0:
                            charging_point = "ACCELERATED"
*/
                        default:
                            charging_point = "\(power/1000.0) kW"
                        }
                    }
                    
                    let dateString = result!.data.attributes.timestamp // e.g. "2020-01-31T17:39:52+01:00"
                    
                    let dateFormatter = DateFormatter()
                    dateFormatter.locale = NSLocale.current
                    dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZZZZZ"
                    let date = dateFormatter.date(from:dateString)!
                    let unixMs = UInt64(date.timeIntervalSince1970) * 1000
                    print(date)
                    
                    // batteryState(error:charging:plugged:charge_level:remaining_range:last_update:charging_point:remaining_time:)
                    DispatchQueue.main.async{
                        callback(false,
                                 result!.data.attributes.chargingStatus == 1.0,
                                 result!.data.attributes.plugStatus > 0,
                                 UInt8(result!.data.attributes.batteryLevel),
                                 result!.data.attributes.batteryAutonomy ?? -1.0,
                                 unixMs,
                                 charging_point,
                                 result!.data.attributes.chargingRemainingTime,
                                 result!.data.attributes.batteryTemperature)
                        
                    }
                } else {
                    DispatchQueue.main.async{
                        callback(true,
                                 false,
                                 false,
                                 0,
                                 0.0,
                                 0,
                                 nil,
                                 nil,
                                 nil)
                    }
                }
            }
        }
    }
    
        
    func cockpitState(callback:@escaping  (Bool, Float?) -> ()) {
        
        
        /*
         
        v1:
        Request: https://api-wired-prod-1-euw1.wrd-aws.com/commerce/v1/accounts/xxxx/kamereon/kca/car-adapter/v1/cars/V.../cockpit?country=DE
        {"data":{"type":"Car","id":"V...","attributes":{"totalMileage":55842}}}

         
        v2:
        Request: https://api-wired-prod-1-euw1.wrd-aws.com/commerce/v1/accounts/xxxx/kamereon/kca/car-adapter/v2/cars/V.../cockpit?country=DE
        {"data":{"type":"Car","id":"V...","attributes":{"totalMileage":55842.21}}}

         */
        
        struct cockpitInfoV1: Codable {
                    var data: Data
                    struct Data: Codable {
                        var type: String
                        var id: String
                        var attributes: Attributes
                        struct Attributes: Codable {
                            var totalMileage: Int
                        }
                    }
                }
        
        struct cockpitInfoV2: Codable {
                var data: Data
                struct Data: Codable {
                    var type: String
                    var id: String
                    var attributes: Attributes
                    struct Attributes: Codable {
                        var totalMileage: Float
                    }
                }
            }
        
            let endpointUrl = URL(string: context.apiKeysAndUrls!.servers.wiredProd.target + "/commerce/v1/accounts/" + context.kamereonAccountInfo!.accounts[0].accountId + "/kamereon/kca/car-adapter/" + version.string + "/cars/" + context.vehiclesInfo!.vehicleLinks[0].vin + "/cockpit")!
                    
            var components = URLComponents(url: endpointUrl, resolvingAgainstBaseURL: false)!
            components.queryItems = [
                URLQueryItem(name: "country", value: self.country)
            ]
            let headers = getHeaders()

            // Fetch info using the retrieved access token
            
            switch version {
            case .v1:
                self.fetchJsonDataViaHttp(usingMethod: .GET, withComponents: components, withHeaders: headers) { (result:cockpitInfoV1?) -> Void in
                    if result != nil {
                        print("Successfully retrieved cockpit state V1:")
                        print("total mileage: \(result!.data.attributes.totalMileage) km")
                        DispatchQueue.main.async{
                            callback(false, Float(result!.data.attributes.totalMileage))
                        }
                    } else {
                        DispatchQueue.main.async{
                            callback(true, nil)
                        }
                    }
                }
                
            case .v2:
                self.fetchJsonDataViaHttp(usingMethod: .GET, withComponents: components, withHeaders: headers) { (result:cockpitInfoV2?) -> Void in
                    if result != nil {
                        print("Successfully retrieved cockpit state V2:")
                        print("total mileage: \(result!.data.attributes.totalMileage) km")

                        DispatchQueue.main.async{
                            callback(false, result!.data.attributes.totalMileage)
                            
                        }
                    } else {
                        DispatchQueue.main.async{
                            callback(true, nil)
                        }
                    }
                }
            }
        }
    
    
    
    
    public func chargeNowRequest(callback:@escaping  (Bool) -> ()) {
        
        let endpointUrl = URL(string: context.apiKeysAndUrls!.servers.wiredProd.target + "/commerce/v1/accounts/" + context.kamereonAccountInfo!.accounts[0].accountId + "/kamereon/kca/car-adapter/" + Version.v1.string + "/cars/" + context.vehiclesInfo!.vehicleLinks[0].vin + "/actions/charging-start")!

        
        struct StartCharging: Codable {
            var data: Data
            struct Data:Codable {
                var type: String
                var id: String?
                var attributes:Attributes
                struct Attributes:Codable {
                    var action:String
                }
            }
        }
           
        let startCharging = StartCharging(data: StartCharging.Data(type: "ChargingStart", attributes: StartCharging.Data.Attributes(action: "start")))
        
        guard let uploadData = try? JSONEncoder().encode(startCharging) else {
            callback(false)
            return
        }
        
        var components = URLComponents(url: endpointUrl, resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "country", value: self.country)
        ]
        let headers = getHeaders()
                 
        // Fetch info using the retrieved access token
        self.fetchJsonDataViaHttp(usingMethod: .POST, withComponents: components, withHeaders: headers, withBody: uploadData) { (result:    StartCharging?) -> Void in
            if result != nil {
                print("Successfully sent request, got: \(result!.data)")
                // batteryState(error:charging:plugged:charge_level:remaining_range:last_update:charging_point:remaining_time:)
                DispatchQueue.main.async{
                    callback(false)
                }
            } else {
                DispatchQueue.main.async{
                    callback(true)
                }
            }
        }
    }
    
    
    
    
    /*
     
     'actions/hvac-start',
     {
        'type': 'HvacStart',
        'attributes‘:{
                'action': 'start' / ‚cancel’
                'targetTemperature': temperature
                'startDateTime‘: "%Y-%m-%dT%H:%M:%SZ"
        }
      }
     
     */
    
    /**
     
        date picker + save :
     preconditionCar(command: .later, date: preconditionRemoteTimer)
        date picker + trash button:
     preconditionCar(command: .delete, date: nil)
        AC now (also shortcut from 3d touch):
     preconditionCar(command: .now, date: nil)
     
        refresh status:
     sc.precondition(command: .read, date: nil, callback: self.preconditionState)


     */
    public func precondition(command:PreconditionCommand, date: Date?, callback:@escaping  (Bool, PreconditionCommand, Date?, Float?) -> ()) {
        
        let endpointUrl:URL
        
        switch command {
        case .read:
            endpointUrl = URL(string: context.apiKeysAndUrls!.servers.wiredProd.target + "/commerce/v1/accounts/" + context.kamereonAccountInfo!.accounts[0].accountId + "/kamereon/kca/car-adapter/" + Version.v1.string + "/cars/" + context.vehiclesInfo!.vehicleLinks[0].vin + "/hvac-status")!

        case .now, .later, .delete:
            endpointUrl = URL(string: context.apiKeysAndUrls!.servers.wiredProd.target + "/commerce/v1/accounts/" + context.kamereonAccountInfo!.accounts[0].accountId + "/kamereon/kca/car-adapter/" + Version.v1.string + "/cars/" + context.vehiclesInfo!.vehicleLinks[0].vin + "/actions/hvac-start")!
        }
        
        
        struct PreconditionInfo: Codable {
            var data: Data
            struct Data: Codable {
                var type: String
                var id: String
                var attributes: Attributes
                struct Attributes: Codable {
                    var hvacStatus: String
                    var externalTemperature: Float
                    var nextHvacStartDate: String?
                }
            }
        }
        
        struct Precondition: Codable {
            var data: Data
            struct Data:Codable {
                var type: String
                var id: String?
                var attributes:Attributes
                struct Attributes:Codable {
                    var action: String
                    var targetTemperature: Float?
                    var startDateTime: String?
                }
            }
        }
        
        let precondition:Precondition?
        
        switch command {
        case .now:
            precondition = Precondition(data: Precondition.Data(type: "HvacStart", attributes: Precondition.Data.Attributes(action: "start", targetTemperature: 21.0)))

        case .later:
            
            // combine time received with today's date:
            let today = Date()
            let finalDate:Date
            if (date!<today){
                // if in the past, add one day
                finalDate = date! + TimeInterval(24*3600)
            } else {
                finalDate = date!
            }
            // date now is the correct time and date.

            let dateFormatter = DateFormatter()
            let timezone = TimeZone.current.abbreviation() ?? "CET"  // get current TimeZone abbreviation or set to CET
            dateFormatter.timeZone = TimeZone(abbreviation: timezone) //Set timezone that you want
            dateFormatter.locale = NSLocale.current
            dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZZZZZ"
            let strDate = dateFormatter.string(from: finalDate)
            
            precondition = Precondition(data: Precondition.Data(type: "HvacStart", attributes: Precondition.Data.Attributes(action: "start", targetTemperature: 21.0, startDateTime: strDate)))
        case .delete:
            precondition = Precondition(data: Precondition.Data(type: "HvacStart", attributes: Precondition.Data.Attributes(action: "cancel")))
        case .read:
            precondition = nil
        }
        
        let uploadData:Data?
        
        if (precondition == nil){ // for .read
            uploadData = nil
        } else {
            uploadData = try? JSONEncoder().encode(precondition)
            if (uploadData == nil) {
                callback(false, command, date, nil)
                return
            } else {
                print(String(data: uploadData!, encoding: .utf8)!)
            }
        }
        
        var components = URLComponents(url: endpointUrl, resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "country", value: self.country)
        ]
        let headers = getHeaders()

        if (command == .read) { // for .read GET status
            self.fetchJsonDataViaHttp(usingMethod: .GET, withComponents: components, withHeaders: headers, withBody: uploadData) { (result:PreconditionInfo?) -> Void in
                if result != nil {
                    print("Successfully sent GET request, got: \(result!.data)")
                    print("External temperature: \(result!.data.attributes.externalTemperature)")
                    let date:Date?
                    if let dateString = result!.data.attributes.nextHvacStartDate {
                        // e.g. "2020-02-03T06:30:00Z"
                        let dateFormatter = DateFormatter()
                        dateFormatter.locale = NSLocale.current
                        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZZZZZ"
                        date = dateFormatter.date(from:dateString)!
                    } else {
                        date = nil
                    }
                    DispatchQueue.main.async{
                        callback(false, command, date, result!.data.attributes.externalTemperature)
                    }
                } else {
                    DispatchQueue.main.async{
                        callback(true, command, date, nil)
                    }
                }
            }
        } else { // all other commands POST action
            self.fetchJsonDataViaHttp(usingMethod: .POST, withComponents: components, withHeaders: headers, withBody: uploadData) { (result:Precondition?) -> Void in
                if result != nil {
                    print("Successfully sent POST request, got: \(result!.data)")
                    // batteryState(error:charging:plugged:charge_level:remaining_range:last_update:charging_point:remaining_time:)
                    DispatchQueue.main.async{
                        callback(false, command, date, nil)
                    }
                } else {
                    DispatchQueue.main.async{
                        callback(true, command, date, nil)
                    }
                }
            }
        }
    }
    
    
    
    
    public func airConditioningLastState(callback:@escaping  (Bool, UInt64, String?, String?) -> ()) {
        
        struct HvacSessions: Codable {
            var data: Data
            struct Data: Codable {
                var type: String
                var id: String
                var attributes: Attributes
                struct Attributes: Codable {
                    var hvacSessions: [HvacSession]
                    struct HvacSession: Codable {
                        var hvacSessionRequestDate: String
                        var hvacSessionStartDate: String
                        var hvacSessionEndStatus: String
                    }
                }
            }
        }
        /*
         {"data":{"type":"Car","id":"...","attributes":{"hvacSessions":[{"hvacSessionRequestDate":"2020-02-03T17:20:05+01:00","hvacSessionStartDate":"2020-02-03T17:26:38+01:00","hvacSessionEndStatus":"ok"},{"hvacSessionRequestDate":"2020-02-03T00:30:48+01:00","hvacSessionStartDate":"2020-02-03T07:29:42+01:00","hvacSessionEndStatus":"error"},{"hvacSessionRequestDate":"2020-02-02T16:25:59+01:00","hvacSessionStartDate":"2020-02-02T16:32:32+01:00","hvacSessionEndStatus":"error"}]}}}
         
         */
        
        let endpointUrl = URL(string: context.apiKeysAndUrls!.servers.wiredProd.target + "/commerce/v1/accounts/" + context.kamereonAccountInfo!.accounts[0].accountId + "/kamereon/kca/car-adapter/" + Version.v1.string + "/cars/" + context.vehiclesInfo!.vehicleLinks[0].vin + "/hvac-sessions")!
        
        let dateFormatter = DateFormatter()
        let timezone = TimeZone.current.abbreviation() ?? "CET"  // get current TimeZone abbreviation or set to CET
        dateFormatter.timeZone = TimeZone(abbreviation: timezone) //Set timezone that you want
        dateFormatter.locale = NSLocale.current
        dateFormatter.dateFormat = "yyyyMMdd"
        let startDate = dateFormatter.string(from: Date()-24*3600*7) // go back one week
        let endDate = dateFormatter.string(from: Date()) // today
        
        var components = URLComponents(url: endpointUrl, resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "start", value: startDate),
            URLQueryItem(name: "end", value: endDate),
            URLQueryItem(name: "country", value: self.country)
        ]
        let headers = getHeaders()

        // Fetch info using the retrieved access token
        self.fetchJsonDataViaHttp(usingMethod: .GET, withComponents: components, withHeaders: headers) { (result:HvacSessions?) -> Void in
            if result != nil {
                print("Successfully retrieved AC sessions: \(result!.data.attributes.hvacSessions.count) sessions")
                //print("level: \(result!.data.attributes.hvacSessions[0])")
                
                if (result!.data.attributes.hvacSessions.count > 0) { // array not empty  - never happens, HTTP 500 instead!
                    print("AC last state: \(result!.data.attributes.hvacSessions[0])")

                    let dateString = result!.data.attributes.hvacSessions[0].hvacSessionStartDate
                    let dateFormatter = DateFormatter()
                    dateFormatter.locale = NSLocale.current
                    dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZZZZZ"
                    let date = dateFormatter.date(from:dateString)!
                    let unixMs = UInt64(date.timeIntervalSince1970) * 1000
                    
                    let status = result!.data.attributes.hvacSessions[0].hvacSessionEndStatus
                    
                    let rStatus:String?
                    switch status {
                    case "error":
                        rStatus = "ERROR"
                    case "ok":
                        rStatus = "SUCCESS"
                    default:
                        rStatus = nil
                    }
                    
                    print("A/C lst state: \(date), \(rStatus ?? "-")")
                    
                    DispatchQueue.main.async {
                        callback(false,
                                 unixMs,
                                 "USER_REQUEST",
                                 rStatus)
                    }
                    
                } else { // array empty, no data
                    DispatchQueue.main.async {
                        callback(false, // no error, but no data
                                 0,
                                 nil,
                                 nil)
                    }
                }
                
            
            } else {
                DispatchQueue.main.async {
                    callback(false, // true = error getting data -> dialog
                             0,
                             nil,
                             nil)
                }
            }
        }
    }
    
    enum HttpMethod {
        case GET
        case POST
        case PUT
        
        var string: String { // computed property
            switch self {
            case .GET:
                return "GET"
            case .PUT:
                return "PUT"
               case .POST:
                return "POST"
               }
           }
    }
    
    func fetchJsonDataViaHttp<T> (usingMethod method:HttpMethod, withComponents components:URLComponents, withHeaders headers:[String:String]?, withBody body: Data?=nil, callback:@escaping(T?)->Void) where T:Decodable {
    
        let query = components.url!.query
        var request = URLRequest(url: components.url!)
        request.httpMethod = method.string
        if (query != nil) && (method == .POST) {
            request.httpBody = Data(query!.utf8) // must not be used for GET
        }
        
        if (body != nil) && (method == .POST) {
            request.httpBody = body
        }
        
        request.allHTTPHeaderFields = headers
        // request.setValue("...", forHTTPHeaderField: "...")

        let task = URLSession.shared.dataTask(with: request){ data, response, error in
            
            os_log("Request: %{public}s", log: self.serviceLog, type: .debug, request.description)
            if (request.httpBody != nil) {os_log("POST-Body: %{public}s", log: self.serviceLog, type: .debug, String(data: request.httpBody!, encoding: .utf8)!)
            }
            if let error = error {
                os_log("URLSession error: %{public}s", log: self.serviceLog, type: .error, error.localizedDescription)
                callback(nil)
                return
            }
            
            guard let resp = response as? HTTPURLResponse,
                (200...299).contains(resp.statusCode) else {
                    os_log("server error, statusCode = %{public}d", log: self.serviceLog, type: .error, (response as? HTTPURLResponse)?.statusCode ?? 0)
                    callback(nil)
                    return
            }
            
            if let jsonData = data {
                //print ("raw JSON data: \(String(data: jsonData, encoding: .utf8)!)")
                os_log("raw JSON data: %{public}s", log: self.serviceLog, type: .debug, String(data: jsonData, encoding: .utf8)!)

                let decoder = JSONDecoder()
                let result = try? decoder.decode(T.self, from: jsonData)
                callback(result)
            } else {
                callback(nil)
            }
        } // task completion handler end
        
        task.resume()
        
    }

}
