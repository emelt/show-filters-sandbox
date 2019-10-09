//
//  LocalizationManager.swift
//  MavFarm
//
//  Created by Emel Topaloglu on 7/11/17.
//  Copyright © 2017 Mav Farm. All rights reserved.
//

import Foundation

func Localized(_ string: String) -> String {
    return NSLocalizedString(string, comment: "")
}

func LocalizedUppercase(_ string: String) -> String {
    return NSLocalizedString(string, comment: "").uppercased()
}
