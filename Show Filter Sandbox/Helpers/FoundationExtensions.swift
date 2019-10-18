//
//  FoundationExtensions.swift
//  MavFarm
//
//  Created by Stephen Walsh on 28/02/2019.
//  Copyright © 2019 MavFarm. All rights reserved.
//

import Foundation
import CoreGraphics

extension CGSize {
    
    init(square value: CGFloat) {
        self.init(width: value, height: value)
    }
    
    var abs: CGSize {
        let absWidth = width < 0 ? width * -1 : width
        let absHeight = height < 0 ? height * -1 : height
        return CGSize(width: absWidth, height: absHeight)
    }
}
