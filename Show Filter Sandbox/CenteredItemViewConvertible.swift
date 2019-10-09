//
//  CenteredItemViewConvertible.swift
//  MavFarm
//
//  Created by Stephen Walsh on 26/02/2019.
//  Copyright © 2019 MavFarm. All rights reserved.
//

import Foundation
import UIKit

protocol CenteredItemViewConvertible {
    var displayImage: UIImage? { get }
    var displayTitle: String? { get }
    var rawValue: String { get }
}
