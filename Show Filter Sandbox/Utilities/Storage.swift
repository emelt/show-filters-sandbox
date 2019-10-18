//
//  Storage.swift
//  MavFarm
//
//  Created by Stephen Walsh on 20/06/2019.
//  Copyright © 2019 MavFarm. All rights reserved.
//

import Foundation

public class Storage {

    enum PersistenceError: Error {
        case urlFailure
        case noFile
        case copyError
        case unknown(string: String)
        case permissionError
    }
    
    static func createSubdirectory(url: URL) {
        if !FileManager.default.fileExists(atPath: url.path) {
            do {
                try FileManager.default.createDirectory(atPath: url.path, withIntermediateDirectories: true, attributes: nil)
            } catch {
                print(error.localizedDescription)
            }
        }
    }
    
    static func store<T: Encodable>(_ object: T,
                                    atURL url: URL,
                                    completion: ((Result<Void, PersistenceError>) -> Void)) {
        let encoder = JSONEncoder()
        do {
            let data = try encoder.encode(object)
            if FileManager.default.fileExists(atPath: url.path) {
                try FileManager.default.removeItem(at: url)
            }
            FileManager.default.createFile(atPath: url.path,
                                           contents: data,
                                           attributes: nil)
            completion(Result.success(Void()))
        } catch {
            completion(Result.failure(.unknown(string: error.localizedDescription)))
        }
    }
    
    static func retrieve<T: Decodable>(fromURL url: URL,
                                       as type: T.Type) -> Result<T, PersistenceError> {
        
        if !FileManager.default.fileExists(atPath: url.path) {
            return .failure(.noFile)
        }
        
        if let data = FileManager.default.contents(atPath: url.path) {
            let decoder = JSONDecoder()
            do {
                let model = try decoder.decode(type, from: data)
                return .success(model)
            } catch {
                return .failure(.unknown(string: error.localizedDescription))
            }
        } else {
            return .failure(.noFile)
        }
    }
    
    static func clear(atURL directoryURL: URL, deleteDirectory: Bool) -> Result<Void, PersistenceError> {
        do {
            let contents = try FileManager.default.contentsOfDirectory(at: directoryURL, includingPropertiesForKeys: nil, options: [])
            for fileUrl in contents {
                try FileManager.default.removeItem(at: fileUrl)
            }
            
            if deleteDirectory {
                try FileManager.default.removeItem(at: directoryURL)
            }
            
            return .success(Void())
        } catch {
            return .failure(.unknown(string: error.localizedDescription))
        }
    }
}
