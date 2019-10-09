//
//  ComputeCommandEncoder+Helpers.swift
//  CoreVision
//
//  Created by Geppy Parziale on 12/15/17.
//  Copyright © 2017 INVASIVECODE, Inc. All rights reserved.
//

import Metal
import MetalPerformanceShaders
import MetalKit


extension MTLComputeCommandEncoder {


	/// Dispatches a compute kernel on a 2-dimensional grid.
	///
	/// - Parameters:
	///		- width: the first dimension
	///		- height: the second dimension
	func dispatchThreadgroups(computePipelineState: MTLComputePipelineState, width: Int, height: Int) {

		let w = computePipelineState.threadExecutionWidth
		let h = computePipelineState.maxTotalThreadsPerThreadgroup / w
		let threadGroupSize = MTLSizeMake(w, h, 1)

		let threadGroups = MTLSizeMake((width + threadGroupSize.width  - 1) / threadGroupSize.width,
									   (height + threadGroupSize.height - 1) / threadGroupSize.height,
									   1)
		dispatchThreadgroups(threadGroups, threadsPerThreadgroup: threadGroupSize)
	}


	/// Dispatches a compute kernel on a 3-dimensional image grid.
	///
	/// - Parameters:
	/// 	- computePipelineState: the compute pipeline state
	///		- width: the width of the image in pixels
	///		- height: the height of the image in pixels
	///		- featureChannels: the number of channels in the image
	///		- numberOfImages: the number of images in the batch (default is 1)
	func dispatchThreadgroups(computePipelineState: MTLComputePipelineState, width: Int, height: Int, featureChannels: Int = 4, numberOfImages: Int = 1) {

		let slices = ((featureChannels + 3)/4) * numberOfImages

		let w = computePipelineState.threadExecutionWidth
		let h = computePipelineState.maxTotalThreadsPerThreadgroup / w
		let d = 1
		let threadGroupSize = MTLSizeMake(w, h, d)

		let threadGroups = MTLSizeMake( (width  + threadGroupSize.width  - 1) / threadGroupSize.width,
										(height + threadGroupSize.height - 1) / threadGroupSize.height,
										(slices + threadGroupSize.depth  - 1) / threadGroupSize.depth)

//		printGrid(threadGroups: threadGroups, threadsPerThreadgroup: threadGroupSize)
		dispatchThreadgroups(threadGroups, threadsPerThreadgroup: threadGroupSize)
	}


	/// For debugging the threadgroup sizes.
	private func printGrid(threadGroups: MTLSize, threadsPerThreadgroup: MTLSize) {

		let groups = threadGroups
		let threads = threadsPerThreadgroup
		let grid = MTLSizeMake(groups.width * threads.width, groups.height * threads.height, groups.depth * threads.depth)

		print("threadGroups: \(groups.width)x\(groups.height)x\(groups.depth)"
			+ ", threadsPerThreadgroup: \(threads.width)x\(threads.height)x\(threads.depth)"
			+ ", grid: \(grid.width)x\(grid.height)x\(grid.depth)")
	}


//	/// Dispatches a compute kernel on an MPSImage's texture or texture array.
//	func dispatch(computePipelineState: MTLComputePipelineState, image: MPSImage) {
//		dispatchThreadgroups(computePipelineState: computePipelineState, width: image.width, height: image.height, featureChannels: image.featureChannels, numberOfImages: image.numberOfImages)
//	}
//
//
//	/// Dispatches a compute kernel on an MPSImage's texture or texture array.
//	/// Use this method if you only want to overwrite a portion of the MPSImage's
//	/// channels (i.e. when you're using `destinationFeatureChannelOffset`).
//	func dispatch(computePipelineState: MTLComputePipelineState, image: MPSImage, featureChannels: Int) {
//		dispatchThreadgroups(computePipelineState: computePipelineState, width: image.width, height: image.height, featureChannels: featureChannels, numberOfImages: image.numberOfImages)
//	}

}
