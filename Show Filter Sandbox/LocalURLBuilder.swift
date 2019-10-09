//
//  LocalURLBuilder.swift
//  MavFarm
//
//  Created by Stephen Walsh on 21/06/2019.
//  Copyright © 2019 MavFarm. All rights reserved.
//

import Foundation

enum LocalURLBuilder {
    
    enum Directory {
        case documents, caches
    }
    
    private enum Key {
        static let temp = "temp"
    }
    
    static func createTempFileURL(withFileName fileName: String) -> URL? {
        guard let tempFolderURL = createFolder(in: .documents, orderedSubdirectories: [Key.temp]) else { return nil }
        let tempFileUrl = tempFolderURL.appendingPathComponent(fileName, isDirectory: false)
        
        return tempFileUrl
    }
    
    static func fetchTempFileFolder() -> URL? {
        return fetchFolderURL(for: .documents, orderedSubdirectories: [Key.temp])
    }
    
    static func createFolder(in directory: Directory,
                             orderedSubdirectories: [String]) -> URL? {
        
        guard let url = fetchFolderURL(for: directory,
                                       orderedSubdirectories: orderedSubdirectories) else { return nil }
        
        Storage.createSubdirectory(url: url)
        
        return url
    }
    
    static func buildURL(for directory: Directory,
                         orderedSubdirectories: [String],
                         fileName: String?) -> URL? {
        
        guard let builtURL = fetchFolderURL(for: directory,
                                            orderedSubdirectories: orderedSubdirectories) else { return nil }
        
        if let fileName = fileName {
            return builtURL.appendingPathComponent(fileName, isDirectory: false)
        }
        
        return builtURL
    }
}

// MARK: Helpers

extension LocalURLBuilder {
    
    private static func fetchFolderURL(for directory: Directory,
                                       orderedSubdirectories: [String]) -> URL? {
        
        guard let url = getURL(for: directory) else { return nil }
        
        let builtURL = orderedSubdirectories.reduce(url) { (res, next) -> URL in
            return res.appendingPathComponent(next, isDirectory: true)
        }
        
        return builtURL
    }
    
    private static func getURL(for directory: Directory) -> URL? {
        var searchPathDirectory: FileManager.SearchPathDirectory
        
        switch directory {
        case .documents:
            searchPathDirectory = .documentDirectory
        case .caches:
            searchPathDirectory = .cachesDirectory
        }
        
        if let url = FileManager.default.urls(for: searchPathDirectory, in: .userDomainMask).first {
            return url
        } else {
            print("Could not create URL for specified directory!")
        }
        
        return nil
    }
}
