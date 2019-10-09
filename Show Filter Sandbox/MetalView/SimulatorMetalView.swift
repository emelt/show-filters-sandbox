//
//  SimulatorMetalView.swift
//  MavFarm
//
//  Created by Stephen Walsh on 24/06/2019.
//  Copyright © 2019 MavFarm. All rights reserved.
//

import Foundation
import MetalKit
import CoreGraphics

final class SimulatorMetalView: UIView, MetalViewRepresentable {
    
    var inputTexture: MTLTexture?
    var drawableSize: CGSize
    
    // MARK: Lifecycle
    
    init() {
        self.drawableSize = CGSize(square: 100.0)
        super.init(frame: .zero)
    }
    
    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

// MARK: MetalViewRepresentable Implementation

extension SimulatorMetalView {
    
    func updateContentMode(to contentMode: UIView.ContentMode) {
        self.contentMode = contentMode
    }
}
