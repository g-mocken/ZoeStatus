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
    
    var username: String!
    var password: String!
    
    init(username u:String, password p:String) {
        username = u
        password = p
    }
    
    var apiKeysAndUrls: ApiKeyResult?
    var sessionInfo: SessionInfo?
    
    let serviceLog = OSLog(subsystem: "com.grm.ZEServices", category: "ZOE")

    
    func handleLoginProcess(onError errorCode:@escaping()->Void, onSuccess actionCode:@escaping()->Void) {
        getkeys(){ result in
            if result != nil {
                print(result!.servers.wiredProd.target)
                print(result!.servers.wiredProd.apikey)
                print(result!.servers.gigyaProd.target)
                print(result!.servers.gigyaProd.apikey)

                self.apiKeysAndUrls = result

                // continue: call next step func, with next closure
                self.getSessionKey(){ result in
                    if result != nil {
                        print("Cookie value: \(result!.sessionInfo.cookieValue)")
                        
                        self.sessionInfo = result
                        actionCode()
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
    
    /// Fetch URLs and API keys from a fixed URL
    func getkeys (callback:@escaping(ApiKeyResult?)->Void) {
        
        let apiKeysUrl = "https://renault-wrd-prod-1-euw1-myrapp-one.s3-eu-west-1.amazonaws.com/configuration/android/config_en_GB.json"
        
        let url = URL(string: apiKeysUrl)!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        
        let tString = ""
        let uploadData = tString.data(using: String.Encoding.utf8)
        let task = URLSession.shared.uploadTask(with: request, from: uploadData) { data, response, error in
            
            if let error = error {
                //print ("URLSession error: \(error)")
                os_log("URLSession error: %{public}s", log: self.serviceLog, type: .error, error.localizedDescription)
                callback(nil)
                return
            }
            
            guard let resp = response as? HTTPURLResponse,
                (200...299).contains(resp.statusCode) else {
                    //print ("server error")
                    os_log("server error, statusCode = %{public}d", log: self.serviceLog, type: .error, (response as? HTTPURLResponse)?.statusCode ?? 0)
                    callback(nil)
                    return
            }
            
            if let mimeType = resp.mimeType,
                mimeType == "application/json",
                let data = data
            /* let dataString = String(data: data, encoding: .utf8) */ {
                print ("got api key data! Decoding keys and urls...")
                
                let decoder = JSONDecoder()
                let result = try? decoder.decode(ApiKeyResult.self, from: data)
                callback(result)
            } else {
                callback(nil)
            }
        } // task completion handler end
        
        task.resume()
        
    }
    
    
    
    
    func getSessionKey (callback:@escaping(SessionInfo?)->Void) {
        let endpointUrl = URL(string: apiKeysAndUrls!.servers.gigyaProd.target + "/accounts.login")!
        var components = URLComponents(url: endpointUrl, resolvingAgainstBaseURL: false)!

        components.queryItems = [
            URLQueryItem(name: "apiKey", value: apiKeysAndUrls!.servers.gigyaProd.apikey),
            URLQueryItem(name: "loginID", value: username),
            URLQueryItem(name: "password", value: password)
        ]

        let query = components.url!.query
        var request = URLRequest(url: endpointUrl)
        request.httpMethod = "POST"
        print("Query: \(query!)")
        let uploadData = Data(query!.utf8)
        let task = URLSession.shared.uploadTask(with: request, from: uploadData) { data, response, error in
            
            if let error = error {
                print ("URLSession error: \(error)")
                os_log("URLSession error: %{public}s", log: self.serviceLog, type: .error, error.localizedDescription)
                callback(nil)
                return
            }
            
            guard let resp = response as? HTTPURLResponse,
                (200...299).contains(resp.statusCode) else {
                    //print ("server error")
                    os_log("server error, statusCode = %{public}d", log: self.serviceLog, type: .error, (response as? HTTPURLResponse)?.statusCode ?? 0)
                    callback(nil)
                    return
            }
            
            if /*let mimeType = resp.mimeType,
                mimeType == "application/json",*/
                let data = data
            /* let dataString = String(data: data, encoding: .utf8) */ {
                print ("session info data! Decoding cookie value...")
                
                let decoder = JSONDecoder()
                let result = try? decoder.decode(SessionInfo.self, from: data)
                callback(result)
            } else {
                callback(nil)
            }
        } // task completion handler end
        
        task.resume()
        
    }
    
}
