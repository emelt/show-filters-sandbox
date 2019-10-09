//
//  FilterAuthor.swift
//  MavFarm
//
//  Created by Stephen Walsh on 04/03/2019.
//  Copyright © 2019 MavFarm. All rights reserved.
//

import Foundation

enum FilterAuthor: String {
    case connorBell
    case invasiveCode
    case colinDuffy
    case colinDuffyAndInvasive
    
    var authorName: String? {
        return "filter_author_" + rawValue
    }
    
    var formattedAuthorName: String? {
        guard let authorName = authorName else { return nil }
        return "filter_author_prefix"
    }
}
