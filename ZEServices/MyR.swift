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
    
    var username: String!
    var password: String!
    
    init(username u:String, password p:String) {
        username = u
        password = p
    }
    
    var apiKeysAndUrls: ApiKeyResult?
    var sessionInfo: SessionInfo?
    var accountInfo: AccountInfo?
    
    let serviceLog = OSLog(subsystem: "com.grm.ZEServices", category: "ZOE")

    
    func handleLoginProcess(onError errorCode:@escaping()->Void, onSuccess actionCode:@escaping()->Void) {

        /// Fetch URLs and API keys from a fixed URL
        let endpointUrl = URL(string: "https://renault-wrd-prod-1-euw1-myrapp-one.s3-eu-west-1.amazonaws.com/configuration/android/config_en_GB.json")!
        let components = URLComponents(url: endpointUrl, resolvingAgainstBaseURL: false)!
        self.getAnyInfo(.GET, components) { (result:ApiKeyResult?) -> Void in
            if result != nil {
                
                print("Successfully retrieved targets and api keys:")
                print("Kamereon: \(result!.servers.wiredProd.target), key=\(result!.servers.wiredProd.apikey)")
                print("Gigya: \(result!.servers.gigyaProd.target), key=\(result!.servers.gigyaProd.apikey)")

                self.apiKeysAndUrls = result

                // continue: call next step func, with next closure
                
                let endpointUrl = URL(string: self.apiKeysAndUrls!.servers.gigyaProd.target + "/accounts.login")!
                var components = URLComponents(url: endpointUrl, resolvingAgainstBaseURL: false)!
                components.queryItems = [
                    URLQueryItem(name: "apiKey", value: self.apiKeysAndUrls!.servers.gigyaProd.apikey),
                    URLQueryItem(name: "loginID", value: self.username),
                    URLQueryItem(name: "password", value: self.password)
                ]
                self.getAnyInfo(.POST, components) { (result:SessionInfo?) -> Void in
                    if result != nil {
                        print("Successfully retrieved session key:")
                        print("Cookie value: \(result!.sessionInfo.cookieValue)")
                        
                        self.sessionInfo = result
                        
                        let endpointUrl = URL(string: self.apiKeysAndUrls!.servers.gigyaProd.target + "/accounts.getAccountInfo")!
                        var components = URLComponents(url: endpointUrl, resolvingAgainstBaseURL: false)!
                        components.queryItems = [
                            URLQueryItem(name: "oauth_token", value: self.sessionInfo!.sessionInfo.cookieValue)
                        ]

                        self.getAnyInfo(.POST, components) { (result:AccountInfo?) -> Void in
                            if result != nil {
                                print("Successfully retrieved account info:")
                                print("person ID: \(result!.data.personId)")
                                actionCode()
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
    
    func getAnyInfo<T> (_ method:HttpMethod, _ components:URLComponents, callback:@escaping(T?)->Void) where T:Decodable {
    
        let query = components.url!.query
        var request = URLRequest(url: components.url!)
        request.httpMethod = method.string
        if query != nil { // not used for GET
            request.httpBody = Data(query!.utf8)
        }
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
                //let dataString = String(data: jsonData, encoding: .utf8)
                //print ("got raw data: \(dataString!)")

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
