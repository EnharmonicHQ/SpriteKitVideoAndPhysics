//
//  ENHSWVideoCamToSKTexture.swift
//  TestVideoCam
//
//  Created by Jonathan Saggau on 5/30/15.
//  Copyright (c) 2015 Enharmonic. All rights reserved.
//

import Foundation
import AVFoundation
import CoreVideo
import Accelerate
import SpriteKit


struct ENHSWVideoCamToSKTextureConstants {
    static let lowerCameraFrameRate: Bool = false
}

class ENHSWVideoCamToSKTexture: NSObject {

    var spriteNodesToUpdate: Set<SKSpriteNode> = Set<SKSpriteNode>()

    // "dynamic" gets us KVO
    //https://developer.apple.com/library/ios/documentation/Swift/Conceptual/BuildingCocoaApps/AdoptingCocoaDesignPatterns.html#//apple_ref/doc/uid/TP40014216-CH7-ID12
    dynamic var texture: SKMutableTexture?
    var captureSession: AVCaptureSession
    var bufferPool:CVPixelBufferPool?

    init(captureSessionPreset: String, useFrontCamera: Bool)
    {
        captureSession = AVCaptureSession()
        let devices = AVCaptureDevice.devicesWithMediaType(AVMediaTypeVideo) as NSArray
        var possibleDevice: AVCaptureDevice?
        var preset: String = captureSessionPreset

        let dataOutput = AVCaptureVideoDataOutput()

        if useFrontCamera
        {
            possibleDevice = devices.lastObject as! AVCaptureDevice?
        }
        else
        {
            possibleDevice = devices.firstObject as! AVCaptureDevice?
        }
        if let device = possibleDevice
        {
            if device.supportsAVCaptureSessionPreset(preset) == false
            {
                preset = AVCaptureSessionPresetMedium
            }
            captureSession.sessionPreset = preset
            let videoInput: AVCaptureDeviceInput!
            do {
                videoInput = try AVCaptureDeviceInput(device:device)
            } catch _ {
                videoInput = nil
            }
            if captureSession.canAddInput(videoInput)
            {
                captureSession.addInput(videoInput)
                dataOutput.alwaysDiscardsLateVideoFrames = true
                dataOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as NSObject: Int(kCVPixelFormatType_32BGRA)]
                if ENHSWVideoCamToSKTextureConstants.lowerCameraFrameRate
                {
                    if let format = device.activeFormat
                    {
                        let ranges = format.videoSupportedFrameRateRanges as! [AVFrameRateRange]
                        let range = ranges[0]
                        let minRate = range.minFrameRate
                        let maxRate = range.maxFrameRate
                        var targetMin = 30.0 // 1/30 of a second
                        targetMin = minRate <= targetMin ? targetMin : minRate
                        var targetMax = 30.0 // 1/30 of a second
                        targetMax = maxRate >= targetMax ? targetMax : maxRate
                        let minFrameDuration = CMTimeMakeWithEpoch(Int64(1), Int32(targetMin), Int64(0))
                        let maxFrameDuration = CMTimeMakeWithEpoch(Int64(1), Int32(targetMax), Int64(0))
                        do
                        {
                            try device.lockForConfiguration()
                            device.activeVideoMinFrameDuration = minFrameDuration
                            device.activeVideoMaxFrameDuration = maxFrameDuration
                            device.unlockForConfiguration()
                        }
                        catch
                        {
                            print("Unable to lock \(device) for configuration: \(error)")
                        }
                    }
                }
                captureSession.addOutput(dataOutput)
                captureSession.commitConfiguration()

                let connection = dataOutput.connectionWithMediaType(AVMediaTypeVideo)
                if connection.supportsVideoMirroring
                {
                    connection.videoMirrored = true
                }
            }
        }
        else
        {
            precondition(false, "!!! No device -- Note: this won't work on the simulator")
        }
        super.init()
        //AVCaptureVideoDataOutputSampleBufferDelegate implemented in extension below
        dataOutput.setSampleBufferDelegate(self, queue:dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0))
    }

    func startCapture()
    {
        captureSession.startRunning()
    }

    func stopCapture()
    {
        captureSession.stopRunning()
    }
}

extension ENHSWVideoCamToSKTexture: AVCaptureVideoDataOutputSampleBufferDelegate
{
    func captureOutput(captureOutput: AVCaptureOutput!, didOutputSampleBuffer sampleBuffer: CMSampleBuffer!, fromConnection connection: AVCaptureConnection!)
    {
        autoreleasepool {
            guard let pixelBuffer:CVPixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
            let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer);
            let width = CVPixelBufferGetWidth(pixelBuffer);
            let height = CVPixelBufferGetHeight(pixelBuffer);
            
            if bufferPool == nil
            {
                let createdBufferPool: CVPixelBufferPool? = nil
                let poolAttributes:CFDictionary = [kCVPixelBufferPoolMinimumBufferCountKey as NSString: 2]
                let pixelBufferAttributes = [kCVPixelBufferWidthKey as NSObject: Int(width),
                    kCVPixelBufferHeightKey as NSObject: Int(height),
                    kCVPixelBufferPixelFormatTypeKey as NSObject:Int(kCVPixelFormatType_32BGRA)]
                let returnVal = CVPixelBufferPoolCreate(kCFAllocatorDefault, poolAttributes, pixelBufferAttributes, &bufferPool)
                if returnVal != kCVReturnSuccess
                {
                    print("unable to create bufferPool returnVal: \(returnVal)")
                    return
                }
                else
                {
                    let bufferPool = createdBufferPool
                    print("bufferPool = \(bufferPool)")
                }
            }
            
            let readOnlyFlag:CVOptionFlags = UInt64(kCVPixelBufferLock_ReadOnly.value)
            var cvErr = CVPixelBufferLockBaseAddress(pixelBuffer, readOnlyFlag)
            if cvErr != kCVReturnSuccess
            {
                print("CVPixelBufferLockBaseAddress(pixelBuffer) failed with CVReturn value \(cvErr)")
            }
            let baseAddress:UnsafeMutablePointer<Void> = CVPixelBufferGetBaseAddress(pixelBuffer)
            
            var createdPassablePixelBuffer:CVPixelBuffer?
            let bufferAttributes:CFDictionary = [kCVPixelBufferPoolAllocationThresholdKey as NSString:2]
            cvErr = CVPixelBufferPoolCreatePixelBufferWithAuxAttributes(kCFAllocatorDefault, bufferPool!, bufferAttributes, &createdPassablePixelBuffer)
            if cvErr != kCVReturnSuccess
            {
                print("CVPixelBufferPoolCreatePixelBufferWithAuxAttributes failed with CVReturn value \(cvErr)");
                return
            }
            let passablePixelBuffer = createdPassablePixelBuffer!
            
            cvErr = CVPixelBufferLockBaseAddress(passablePixelBuffer, 0)
            if cvErr != kCVReturnSuccess
            {
                print("CVPixelBufferLockBaseAddress(passablePixelBuffer) failed with CVReturn value \(cvErr)");
            }
            let passableBaseAddress:UnsafeMutablePointer<Void> = CVPixelBufferGetBaseAddress(passablePixelBuffer)

            memcpy(passableBaseAddress, baseAddress, bytesPerRow * height);

            cvErr = CVPixelBufferUnlockBaseAddress(pixelBuffer, readOnlyFlag)
            if cvErr != kCVReturnSuccess
            {
                print("CVPixelBufferUnlockBaseAddress(pixelBuffer) failed with CVReturn value \(cvErr)")
            }
            
            if self.texture?.size().height != CGFloat(height) || self.texture?.size().width != CGFloat(width) || self.texture == nil
            {
                self.texture = SKMutableTexture(size:CGSize(width: CGFloat(width), height: CGFloat(height)))
            }
            self.texture?.modifyPixelDataWithBlock() { (pixeldata, lengthInBytes) -> Void in
                memcpy(pixeldata, passableBaseAddress, lengthInBytes)
                let cvErr = CVPixelBufferUnlockBaseAddress(passablePixelBuffer, 0)
                if cvErr != kCVReturnSuccess
                {
                    print("CVPixelBufferUnlockBaseAddress(passablePixelBuffer) failed with CVReturn value \(cvErr)")
                }
                //TODO: figure out weak capture semantics (I forgot them)
                if self.spriteNodesToUpdate.count > 0
                {
                    for spriteNodeToUpdate in self.spriteNodesToUpdate
                    {
                        let initialSize = spriteNodeToUpdate.size
                        spriteNodeToUpdate.texture = self.texture
                        spriteNodeToUpdate.size = initialSize
                    }
                }
            }
        }
    }
}

