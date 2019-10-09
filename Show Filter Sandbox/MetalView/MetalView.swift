//
//  MetalView.swift
//  MetalCamera
//
//  Created by Geppy Parziale on 7/12/18.
//  Copyright © 2018 INVASIVECODE, Inc. All rights reserved.
//

import MetalKit
import MetalPerformanceShaders
import CoreAudio

class MetalView: MTKView {
    
	var inputTexture: MTLTexture? {
		didSet {
			setNeedsDisplay()
		}
	}
    
    override init(frame frameRect: CGRect, device: MTLDevice?) {
        super.init(frame: frameRect, device: device)
        
        if let device = device {
            commonInit(device: device)
        }
    }
    
    convenience init() {
        self.init(frame: CGRect.zero, device: MetalHelper.shared.metalDevice)
    }
    
	required init(coder: NSCoder) {
		super.init(coder: coder)
		
        commonInit(device: MetalHelper.shared.metalDevice)
	}
    
    func commonInit(device: MTLDevice) {
        self.device = device
        
        // Enable drawable texture read/write.
        self.framebufferOnly = false
        
        // Disables drawable auto-resize.
        self.autoResizeDrawable = false
        
        // Sets the content mode.
        self.contentMode = .scaleAspectFill
        
        // Changes drawing mode to only draw on notification.
        self.enableSetNeedsDisplay = true
        self.isPaused = true
        
        // Sets the content scale factor
        self.contentScaleFactor = UIScreen.main.scale
        
        // Sets the size of the drawable
        self.drawableSize = CGSize(width: frame.size.width, height: frame.size.height)
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        // Sets the size of the drawable
        self.drawableSize = CGSize(width: frame.size.width, height: frame.size.height)
    }
    
	override func draw(_ rect: CGRect) {
        if rect.width > 0 && rect.height > 0 {
            self.render()
        }
	}

	private func render() {
		guard let texture = self.inputTexture else { return }
        
        autoreleasepool {
            executePassThroughKernel(for: texture)
        }
	}

	private func executePassThroughKernel(for inputTexture: MTLTexture) {
        #if !targetEnvironment(simulator)
		guard let commandBuffer = MetalHelper.shared.commandQueue.makeCommandBuffer(), let drawable: CAMetalDrawable = self.currentDrawable else { return }
        MetalHelper.shared.passthroughKernel.encode(commandBuffer: commandBuffer, sourceTexture: inputTexture, destinationTexture: drawable.texture, time: 0.0)
		commandBuffer.present(drawable)
		commandBuffer.commit()
        #endif
	}
}

// MARK: MetalViewRepresentable Implementation

extension MetalView: MetalViewRepresentable {
    
    func updateContentMode(to contentMode: UIView.ContentMode) {
        guard self.contentMode != contentMode else { return }
        self.contentMode = contentMode
    }
}
