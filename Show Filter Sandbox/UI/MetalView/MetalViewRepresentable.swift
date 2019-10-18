//
//  MetalViewRepresentable.swift
//  MavFarm
//
//  Created by Stephen Walsh on 10/06/2019.
//  Copyright © 2019 MavFarm. All rights reserved.
//

import Foundation
import MetalKit
import UIKit
import CoreGraphics

protocol MetalViewRepresentable: class {
    var inputTexture: MTLTexture? { get set }
    var drawableSize: CGSize { get set }
    
    func updateContentMode(to contentMode: UIView.ContentMode)
}
