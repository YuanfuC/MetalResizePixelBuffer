//
//  ViewController.swift
//  PerformancePixelBufferResize
//
//  Created by ChenYuanfu on 2020/5/7.
//  Copyright © 2020 ChenYuanfu. All rights reserved.
//

import UIKit
import AVFoundation

class ViewController: UIViewController {
    
    var sourceVideoReader: AVAssetReader?
    var sourceOutput: AVAssetReaderVideoCompositionOutput?
    let filter = Resizer.init()
    override func viewDidLoad() {
        super.viewDidLoad()
        filter.prepare()
        startReadVideo()
    }
    
    func copyFrameVideoVideo(_ isFinish:inout Bool) {
           
           guard let videoOutput = self.sourceOutput else {
               print("source video out put is not exist")
               return
           }
           
           if let sample = videoOutput.copyNextSampleBuffer() {
               autoreleasepool{
                   guard let pixelBuffer = CMSampleBufferGetImageBuffer(sample) else {
                       print("source sample is nil")
                       return
                   }
                    
                let date = Date()
                // Ues breakpoint to check resized buffer
                let resizedBuffer = filter.resizeFrame(sourcePixelFrame: pixelBuffer, targetSize: MTLSize.init(width: 640, height: 480, depth: 0), resizeMode: .scaleAspectFit)
                let string = String.init(format: "Resize cost:%.02f", -date.timeIntervalSinceNow * 1000)
                print("Resize cost:\(string)ms")
               }
               
           } else {
               isFinish = true
               print("Finish copyBufferAndAppend")
           }
       }


    func startReadVideo() -> Void {
         guard let path = Bundle.main.path(forResource: "sourceVideo", ofType: "mp4") else {
             print("Video file not exist")
             return
         }
         
         let tuple = initVideoReader(path: path)
         guard let reader = tuple.reader,
             let output = tuple.videoOutput else {
                 print("Init video reader failed")
                 return;
         }
         
        self.sourceOutput = output
        self.sourceVideoReader = reader
         assert(reader.startReading())
         var isFinish = false
        while !isFinish {
             self.copyFrameVideoVideo(&isFinish)
             Thread.sleep(forTimeInterval:1.0/30.0)
         }
     }
    
    // MARK: - Read source video
    
    func initVideoReader(path:String) ->(reader:AVAssetReader?,
        videoOutput:AVAssetReaderVideoCompositionOutput?) {
            
            let url = URL.init(fileURLWithPath: path)
            let asset = AVAsset.init(url: url)
            
            guard let reader = try? AVAssetReader.init(asset: asset) else {
                print("Asset reader init failed")
                return (nil ,nil)
            }
            
            guard let track  = asset.tracks(withMediaType: .video).last else {
                print("Track init failed")
                return (nil, nil)
            }
            
            let videoComposition = AVVideoComposition.init(propertiesOf: asset)
            let output = AVAssetReaderVideoCompositionOutput.init(videoTracks: [track], videoSettings: [kCVPixelBufferPixelFormatTypeKey as String:kCVPixelFormatType_32BGRA])
            output.videoComposition = videoComposition;
            reader.add(output);
            return (reader, output)
    }
}

