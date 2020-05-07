//
//  Resizer.swift
//  PerformanceResizeImage
//
//  Created by ChenYuanfu on 2020/5/7.
//  Copyright © 2020 ChenYuanfu. All rights reserved.
//

import Foundation
import CoreMedia
import MetalKit
import MetalPerformanceShaders

@objc public enum PixelResizeMode: Int {
    case scaleToFill = 1
    case scaleAspectFit = 2
    case scaleAspectFill = 3
}

@objc public class Resizer: NSObject {
    
    private let metalDevice:MTLDevice? = MTLCreateSystemDefaultDevice()
    private var textureCache: CVMetalTextureCache?
    
    private lazy var commandQueue: MTLCommandQueue? = {
        guard let device =  metalDevice else {
            return nil
        }
        return device.makeCommandQueue()
    }()
    
    @objc public func prepare() {
         guard let metalDevice = metalDevice else {
             return
         }
         
         var metalTextureCache: CVMetalTextureCache?
         if CVMetalTextureCacheCreate(kCFAllocatorDefault, nil, metalDevice, nil, &metalTextureCache) != kCVReturnSuccess {
             assertionFailure("FrameMixer unable to allocate video mixer texture cache")
         } else {
             textureCache = metalTextureCache
         }
     }
        
    @objc public func resizeFrame(sourcePixelFrame:CVPixelBuffer, targetSize:MTLSize, resizeMode: PixelResizeMode) -> CVPixelBuffer? {
        
        guard let sourceTexture = makeTextureFromCVPixelBuffer(sourcePixelFrame) else {
            print("FrameMixer resize convert to texture failed")
            return nil
        }
        
        guard let queue = self.commandQueue,
        let commandBuffer = queue.makeCommandBuffer() else {
                print("FrameMixer makeCommandBuffer failed")
                return nil
        }
        
        let device = queue.device;
        
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: sourceTexture.pixelFormat, width: targetSize.width, height: targetSize.height, mipmapped: false)
        descriptor.usage = [.shaderWrite, .shaderRead, .renderTarget]
        
        guard let desTexture = device.makeTexture(descriptor: descriptor) else {
                  print("FrameMixer resize makeTexture failed")
                  return nil
        }
        
        // Scale texture
        let sourceWidth = CVPixelBufferGetWidth(sourcePixelFrame)
        let sourceHeight = CVPixelBufferGetHeight(sourcePixelFrame)
        let widthRatio: Double = Double(targetSize.width) / Double(sourceWidth)
        let heightRatio: Double = Double(targetSize.height) / Double(sourceHeight)
        var scaleX: Double = 0;
        var scaleY: Double  = 0;
        var translateX: Double = 0;
        var translateY: Double = 0;
        
        if resizeMode == .scaleToFill {
            scaleX = Double(targetSize.width) / Double(sourceWidth)
            scaleY = Double(targetSize.height) / Double(sourceHeight)
            
        } else if resizeMode == .scaleAspectFit {
            if heightRatio > widthRatio {
                scaleX = Double(targetSize.width) / Double(sourceWidth)
                scaleY = scaleX
                let currentHeight = Double(sourceHeight) * scaleY
                translateY = (Double(targetSize.height) - currentHeight) * 0.5
            } else {
                scaleY = Double(targetSize.height) / Double(sourceHeight)
                scaleX = scaleY
                let currentWidth = Double(sourceWidth) * scaleX
                translateX = (Double(targetSize.width) - currentWidth) * 0.5
            }
            
        } else if resizeMode == .scaleAspectFill {
            if heightRatio > widthRatio {
                scaleY = Double(targetSize.height) / Double(sourceHeight)
                scaleX = scaleY
                let currentWidth = Double(sourceWidth) * scaleX
                translateX = (Double(targetSize.width) - currentWidth) * 0.5
                
            } else {
                scaleX = Double(targetSize.width) / Double(sourceWidth)
                scaleY = scaleX
                let currentHeight = Double(sourceHeight) * scaleY
                translateY = (Double(targetSize.height) - currentHeight) * 0.5
            }
        }
        
        var transform = MPSScaleTransform(scaleX: scaleX, scaleY: scaleY, translateX: translateX, translateY: translateY)
        let scale = MPSImageBilinearScale.init(device: device)
        withUnsafePointer(to: &transform) { (transformPtr: UnsafePointer<MPSScaleTransform>) -> () in
            scale.scaleTransform = transformPtr
            scale.encode(commandBuffer: commandBuffer, sourceTexture: sourceTexture, destinationTexture: desTexture)
        }
        
        // Copy texture to buffer
        let bytesPerRow = CVPixelBufferGetBytesPerRow(sourcePixelFrame)
        guard let encoder = commandBuffer.makeBlitCommandEncoder(),
            let textureBuffer = device.makeBuffer(length: bytesPerRow * descriptor.height, options: .storageModeShared)else {
                return nil
        }
        encoder.copy(from: desTexture,
                     sourceSlice: 0,
                     sourceLevel: 0,
                     sourceOrigin: MTLOrigin.init(x: 0, y: 0, z: 0),
                     sourceSize: MTLSize.init(width: desTexture.width, height: desTexture.height, depth: 1),
                     to: textureBuffer,
                     destinationOffset: 0,
                     destinationBytesPerRow: CVPixelBufferGetBytesPerRow(sourcePixelFrame),
                     destinationBytesPerImage: textureBuffer.length)
        encoder.endEncoding()
        commandBuffer.commit()
        
        // Create CVPixelBuffer from buffer
        var resultBuffer: CVPixelBuffer?
        let pixelFormatType = CVPixelBufferGetPixelFormatType(sourcePixelFrame)
        CVPixelBufferCreateWithBytes(kCFAllocatorDefault,
                                     desTexture.width,
                                     desTexture.height,
                                     pixelFormatType,
                                     textureBuffer.contents(),
                                     CVPixelBufferGetBytesPerRow(sourcePixelFrame),
                                     nil,
                                     nil,
                                     nil,
                                     &resultBuffer)
        return resultBuffer
    }
    
    private func makeTextureFromCVPixelBuffer(_ pixelBuffer:CVPixelBuffer) -> MTLTexture? {
         
         guard let textureCache = textureCache else {
             print("FrameMixer make buffer failed, texture cache is not exist")
             return nil
         }
         
         let width = CVPixelBufferGetWidth(pixelBuffer)
         let height = CVPixelBufferGetHeight(pixelBuffer)
         
         var cvTextureOut:CVMetalTexture?
         
         let result = CVMetalTextureCacheCreateTextureFromImage(kCFAllocatorDefault, textureCache, pixelBuffer, nil, .bgra8Unorm, width, height, 0, &cvTextureOut)
         assert(result == kCVReturnSuccess)
         
         guard let cvTexture = cvTextureOut, let texture = CVMetalTextureGetTexture(cvTexture) else {
             print("FrameMixer make buffer failed to create preview texture")
             
             CVMetalTextureCacheFlush(textureCache, 0)
             return nil
         }
         
         return texture
         
     }
}

