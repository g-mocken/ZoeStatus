//
//  MyR.swift
//  ZEServices
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
    }

    struct VehiclesInfo: Codable {
           var vehicleLinks:[vehicles]
           struct vehicles: Codable {
               var vin: String
           }
       }
    
    struct BatteryInfo: Codable {
        var data: CarInfo
        struct CarInfo: Codable {
            var type: String
            var id: String
            var attributes: Attributes
            struct Attributes: Codable {
                var batteryLevel: Int
                var batteryTemperature: Int
                var chargePower: Int?
                var rangeHvacOff: Float
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

     

     */
    
    var username: String!
    var password: String!
    
    init(username u:String, password p:String) {
        username = u
        password = p
    }
    
    var apiKeysAndUrls: ApiKeyResult?
    var sessionInfo: SessionInfo?
    var accountInfo: AccountInfo?
    var tokenInfo: TokenInfo?
    var kamereonAccountInfo: KamereonAccountInfo?
    var kamereonTokenInfo: KamereonTokenInfo?
    var vehiclesInfo: VehiclesInfo?
    
    let serviceLog = OSLog(subsystem: "com.grm.ZEServices", category: "ZOE")

    
    func handleLoginProcess(onError errorCode:@escaping()->Void, onSuccess actionCode:@escaping()->Void) {

        // Fetch URLs and API keys from a fixed URL
        let endpointUrl = URL(string: "https://renault-wrd-prod-1-euw1-myrapp-one.s3-eu-west-1.amazonaws.com/configuration/android/config_en_GB.json")!
        let components = URLComponents(url: endpointUrl, resolvingAgainstBaseURL: false)!
        self.fetchJsonDataViaHttp(usingMethod: .GET, withComponents: components, withHeaders: nil) { (result:ApiKeyResult?) -> Void in
            if result != nil {
                
                print("Successfully retrieved targets and api keys:")
                print("Kamereon: \(result!.servers.wiredProd.target), key=\(result!.servers.wiredProd.apikey)")
                print("Gigya: \(result!.servers.gigyaProd.target), key=\(result!.servers.gigyaProd.apikey)")

                self.apiKeysAndUrls = result // save for later use

                // Fetch session key from the previously learned URL using the retreived API key
                let endpointUrl = URL(string: self.apiKeysAndUrls!.servers.gigyaProd.target + "/accounts.login")!
                var components = URLComponents(url: endpointUrl, resolvingAgainstBaseURL: false)!
                components.queryItems = [
                    URLQueryItem(name: "apiKey", value: self.apiKeysAndUrls!.servers.gigyaProd.apikey),
                    URLQueryItem(name: "loginID", value: self.username),
                    URLQueryItem(name: "password", value: self.password)
                ]
                self.fetchJsonDataViaHttp(usingMethod: .POST, withComponents: components, withHeaders: nil) { (result:SessionInfo?) -> Void in
                    if result != nil {
                        print("Successfully retrieved session key:")
                        print("Cookie value: \(result!.sessionInfo.cookieValue)")
                        
                        self.sessionInfo = result // save for later use
                        
                        let endpointUrl = URL(string: self.apiKeysAndUrls!.servers.gigyaProd.target + "/accounts.getAccountInfo")!
                        var components = URLComponents(url: endpointUrl, resolvingAgainstBaseURL: false)!
                        components.queryItems = [
                            URLQueryItem(name: "oauth_token", value: self.sessionInfo!.sessionInfo.cookieValue)
                        ]

                        // Fetch person ID from the same URL using the retrieved session key
                        self.fetchJsonDataViaHttp(usingMethod: .POST, withComponents: components, withHeaders: nil) { (result:AccountInfo?) -> Void in
                            if result != nil {
                                print("Successfully retrieved account info:")
                                print("person ID: \(result!.data.personId)")

                                self.accountInfo = result // save for later use
                                
                                let endpointUrl = URL(string: self.apiKeysAndUrls!.servers.gigyaProd.target + "/accounts.getJWT")!
                                var components = URLComponents(url: endpointUrl, resolvingAgainstBaseURL: false)!
                                components.queryItems = [
                                    URLQueryItem(name: "oauth_token", value: self.sessionInfo!.sessionInfo.cookieValue),
                                    URLQueryItem(name: "fields", value: "data.personId,data.gigyaDataCenter"),
                                    URLQueryItem(name: "expiration", value: "900")
                                ]
                                
                                // Fetch Gigya JWT token from the same URL using the retrieved session key
                                self.fetchJsonDataViaHttp(usingMethod: .POST, withComponents: components, withHeaders: nil) { (result:TokenInfo?) -> Void in
                                    if result != nil {
                                        print("Successfully retrieved Gigya JWT token:")
                                        print("Gigya JWT token: \(result!.id_token)")
                                        
                                        self.tokenInfo = result // save for later use
                                        
                                        
                                        let endpointUrl = URL(string: self.apiKeysAndUrls!.servers.wiredProd.target + "/commerce/v1/persons/"+self.accountInfo!.data.personId)!
                                        var components = URLComponents(url: endpointUrl, resolvingAgainstBaseURL: false)!
                                        components.queryItems = [
                                            URLQueryItem(name: "country", value: "DE")
                                        ]
                                        let headers = [
                                            "x-gigya-id_token":self.tokenInfo!.id_token,
                                            "apikey":self.apiKeysAndUrls!.servers.wiredProd.apikey
                                        ]
                                        // Fetch Kaereon account ID from the same URL using the retrieved Gigya JWT token
                                        self.fetchJsonDataViaHttp(usingMethod: .GET, withComponents: components, withHeaders: headers) { (result:KamereonAccountInfo?) -> Void in
                                            if result != nil {
                                                print("Successfully retrieved Kamereon accounts:")
                                                print("Account id 0: \(result!.accounts[0].accountId)")
                                                
                                                self.kamereonAccountInfo = result // save for later use
                                                
                                                
                                                let endpointUrl = URL(string: self.apiKeysAndUrls!.servers.wiredProd.target + "/commerce/v1/accounts/"+self.kamereonAccountInfo!.accounts[0].accountId + "/kamereon/token")!
                                                var components = URLComponents(url: endpointUrl, resolvingAgainstBaseURL: false)!
                                                components.queryItems = [
                                                    URLQueryItem(name: "country", value: "DE")
                                                ]
                                                let headers = [
                                                    "x-gigya-id_token":self.tokenInfo!.id_token,
                                                    "apikey":self.apiKeysAndUrls!.servers.wiredProd.apikey
                                                ]
                                                // Fetch Kaereon account ID from the same URL using the retrieved Gigya JWT token
                                                self.fetchJsonDataViaHttp(usingMethod: .GET, withComponents: components, withHeaders: headers) { (result:KamereonTokenInfo?) -> Void in
                                                    if result != nil {
                                                        print("Successfully retrieved Kamereon token:")
                                                        print("accessToken: \(result!.accessToken)")
                                                        
                                                        self.kamereonTokenInfo = result // save for later use
                                                        
                                                        
                                                        let endpointUrl = URL(string: self.apiKeysAndUrls!.servers.wiredProd.target + "/commerce/v1/accounts/"+self.kamereonAccountInfo!.accounts[0].accountId + "/vehicles")!
                                                        var components = URLComponents(url: endpointUrl, resolvingAgainstBaseURL: false)!
                                                        components.queryItems = [
                                                            URLQueryItem(name: "country", value: "DE")
                                                        ]
                                                        let headers = [
                                                            "x-gigya-id_token":self.tokenInfo!.id_token,
                                                            "apikey":self.apiKeysAndUrls!.servers.wiredProd.apikey,
                                                            "x-kamereon-authorization": "Bearer " + self.kamereonTokenInfo!.accessToken
                                                        ]
                                                        // Fetch VIN using the retrieved access token
                                                        self.fetchJsonDataViaHttp(usingMethod: .GET, withComponents: components, withHeaders: headers) { (result:VehiclesInfo?) -> Void in
                                                            if result != nil {
                                                                print("Successfully retrieved Vehicles:")
                                                                print("VIN: \(result!.vehicleLinks[0].vin)")
                                                                
                                                                self.vehiclesInfo = result // save for later use
                                                                
                                                                
                                                                
                                                                
                                                                actionCode()
                                                                
                                                                
                                                                
                                                            }   else {
                                                                errorCode()
                                                            }
                                                        }
                                                        
                                                        
                                                        
                                                        
                                                    }   else {
                                                        errorCode()
                                                    }
                                                }
                                                
                                                
                                                
                                                
                                            }   else {
                                                errorCode()
                                            }
                                        }
                                        
                                        
                                        
                                        
                                        
                                    }   else {
                                        errorCode()
                                    }
                                }
                            }  else {
                                errorCode()
                            }
                        }
                    }
                    else {
                        errorCode()
                    }
                }
            } else {
                errorCode()
            }
        }
    }
    
    
    
    func batteryState(callback:@escaping  (Bool, Bool, Bool, UInt8, Float, UInt64, String?, Int?) -> ()) {
        
        let endpointUrl = URL(string: self.apiKeysAndUrls!.servers.wiredProd.target + "/commerce/v1/accounts/kmr/remote-services/car-adapter/v1/cars/" + vehiclesInfo!.vehicleLinks[0].vin + "/battery-status")!
        var components = URLComponents(url: endpointUrl, resolvingAgainstBaseURL: false)!
        components.queryItems = nil
        let headers = [
            "x-gigya-id_token":self.tokenInfo!.id_token,
            "apikey":self.apiKeysAndUrls!.servers.wiredProd.apikey,
            "x-kamereon-authorization": "Bearer " + self.kamereonTokenInfo!.accessToken
        ]
        // Fetch info using the retrieved access token
        self.fetchJsonDataViaHttp(usingMethod: .GET, withComponents: components, withHeaders: headers) { (result:BatteryInfo?) -> Void in
            if result != nil {
                print("Successfully retrieved battery state:")
                print("level: \(result!.data.attributes.batteryLevel)")
                print("temperature: \(result!.data.attributes.batteryTemperature)")
                
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
                
                
                let dateString = result!.data.attributes.lastUpdateTime // e.g. "2020-01-31T17:39:52+01:00"

                let dateFormatter = DateFormatter()
                dateFormatter.locale = NSLocale.current
                dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZZZZZ"
                let date = dateFormatter.date(from:dateString)!
                let unixMs = UInt64(date.timeIntervalSince1970) * 1000
                print(date)
                
                
 //               batteryState(error:charging:plugged:charge_level:remaining_range:last_update:charging_point:remaining_time:)
                DispatchQueue.main.async{
                    callback(false,
                             result!.data.attributes.chargeStatus > 0,
                             result!.data.attributes.plugStatus > 0,
                             UInt8(result!.data.attributes.batteryLevel),
                             result!.data.attributes.rangeHvacOff,
                             unixMs,
                             charging_point,
                             result!.data.attributes.timeRequiredToFullSlow)
                    
                }
                
                
            }   else {
                DispatchQueue.main.async{
                    callback(true,
                             false,
                             false,
                             0,
                             0.0,
                             0,
                             nil,
                             nil)
                    
                }            }
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
    
    func fetchJsonDataViaHttp<T> (usingMethod method:HttpMethod, withComponents components:URLComponents, withHeaders headers:[String:String]?, callback:@escaping(T?)->Void) where T:Decodable {
    
        let query = components.url!.query
        var request = URLRequest(url: components.url!)
        request.httpMethod = method.string
        if (query != nil) && (method == .POST) {
            request.httpBody = Data(query!.utf8) // must not be used for GET
        }
        request.allHTTPHeaderFields = headers
        // request.setValue("...", forHTTPHeaderField: "...")

        let task = URLSession.shared.dataTask(with: request){ data, response, error in
            
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
                let dataString = String(data: jsonData, encoding: .utf8)
                print ("raw JSON data: \(dataString!)")

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
