import UIKit
import AVFoundation

struct VideoOutputSettings {
    let size: CGSize
    var fps: Int
    var avCodecKey = AVVideoCodecType.h264
    var videoFilename = "render"
    var videoFilenameExt = "mp4"
    var outputURL: URL

    init(size: CGSize = .zero, fps: Int = 1, avCodecKey: AVVideoCodecType = .h264, videoFilename: String = "render", videoFilenameExt: String = "mp4") {
    self.size = size
    self.fps = fps
    self.avCodecKey = avCodecKey
    self.videoFilename = videoFilename
    self.videoFilenameExt = videoFilenameExt
    self.outputURL = {
      let fileManager = FileManager.default
      if let tmpDirURL = try? fileManager.url(for: .cachesDirectory, in: .userDomainMask, appropriateFor: nil, create: true) {
        let url = tmpDirURL.appendingPathComponent(videoFilename).appendingPathExtension(videoFilenameExt)
        try? fileManager.removeItem(at: url)
        return url
      }
      fatalError("URLForDirectory() failed")
    }()
  }
}
 

class VideoMaker {
    let outputSettings: VideoOutputSettings
    let assetWriter: AVAssetWriter
    let input: AVAssetWriterInput
    let pixelBufferAdaptor: AVAssetWriterInputPixelBufferAdaptor!
    var currentFrame = 0
    let timescale: Int32 = 600
    
    
    var imageIndex = 0
    
    init(outputSettings: VideoOutputSettings) {
        self.outputSettings = outputSettings
        
        do {
            self.assetWriter = try AVAssetWriter(outputURL: outputSettings.outputURL, fileType: .mp4)
            
            let outputSettings = [AVVideoCodecKey : AVVideoCodecType.h264,
                                  AVVideoWidthKey : NSNumber(floatLiteral: Double(outputSettings.size.width)),
                                  AVVideoHeightKey : NSNumber(floatLiteral: Double(outputSettings.size.height))] as [String : Any]
            
            self.input = AVAssetWriterInput(mediaType: .video, outputSettings: outputSettings)
            self.input.transform = CGAffineTransform(rotationAngle: CGFloat.pi/2)
            self.assetWriter.add(input)
            print(assetWriter.canApply(outputSettings: AVOutputSettingsAssistant(preset: .hevc3840x2160WithAlpha)?.videoSettings!, forMediaType: .video))
        } catch {
            print("error: \(error)")
            fatalError()
        }

        let pixelBufferAttributes = [
            kCVPixelBufferPixelFormatTypeKey as String: NSNumber(value: kCVPixelFormatType_32ARGB),
            kCVPixelBufferWidthKey as String: NSNumber(value: Float(outputSettings.size.width)),
            kCVPixelBufferHeightKey as String: NSNumber(value: Float(outputSettings.size.height))
        ]
        
        pixelBufferAdaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input,
                                                                  sourcePixelBufferAttributes: pixelBufferAttributes)
    }

    func pixelBufferFrom(_ image: UIImage,
                         pixelBufferPool: CVPixelBufferPool,
                         size: CGSize) -> CVPixelBuffer {
        
        var pixelBufferOut: CVPixelBuffer?
        
        let status = CVPixelBufferPoolCreatePixelBuffer(kCFAllocatorDefault,
                                                        pixelBufferPool,
                                                        &pixelBufferOut)
        
        if status != kCVReturnSuccess {
            fatalError("CVPixelBufferPoolCreatePixelBuffer() failed")
        }
        
        let pixelBuffer = pixelBufferOut!
        
        CVPixelBufferLockBaseAddress(pixelBuffer,
                                     CVPixelBufferLockFlags(rawValue: 0))
        
        let data = CVPixelBufferGetBaseAddress(pixelBuffer)
        let rgbColorSpace = CGColorSpaceCreateDeviceRGB()
        
        let context = CGContext(data: data,
                                width: Int(size.width),
                                height: Int(size.height),
                                bitsPerComponent: 8,
                                bytesPerRow: CVPixelBufferGetBytesPerRow(pixelBuffer),
                                space: rgbColorSpace,
                                bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue)
        
        context?.clear(CGRect(x:0,
                              y: 0,
                              width: size.width,
                              height: size.height))
        
        let horizontalRatio = size.width / image.size.width
        let verticalRatio = size.height / image.size.height
        
        // ScaleAspectFit
        let aspectRatio = min(horizontalRatio,
                              verticalRatio)
        
        let newSize = CGSize(width: image.size.width * aspectRatio,
                             height: image.size.height * aspectRatio)
        
        let x = newSize.width < size.width ? (size.width - newSize.width) / 2 : 0
        let y = newSize.height < size.height ? (size.height - newSize.height) / 2 : 0
        
        context?.draw(image.cgImage!,
                      in: CGRect(x:x,
                                 y: y,
                                 width: newSize.width,
                                 height: newSize.height))
        
        CVPixelBufferUnlockBaseAddress(pixelBuffer,
                                       CVPixelBufferLockFlags(rawValue: 0))
        
        return pixelBuffer
    }
    
    func start() {
        assetWriter.startWriting()
        assetWriter.startSession(atSourceTime: .zero)
    }
    
    func addImage(image: CVPixelBuffer) {
        let frameDuration = CMTimeMake(value: Int64(timescale / Int32(outputSettings.fps)),
                                       timescale: timescale)
        imageIndex += 1
        
        while currentFrame < imageIndex
        {
            let presentationTime = CMTimeMultiply(frameDuration,
                                                  multiplier: Int32(currentFrame))
            
            print("is ready", pixelBufferAdaptor.assetWriterInput.isReadyForMoreMediaData)
            while !pixelBufferAdaptor.assetWriterInput.isReadyForMoreMediaData { usleep(10) }
            if pixelBufferAdaptor.assetWriterInput.isReadyForMoreMediaData == true {
                pixelBufferAdaptor.append(image,
                                          withPresentationTime: presentationTime)
            }
            
            currentFrame += 1
        }
    }
    
    func finish(completion: @escaping (URL?) -> ()) {
        input.markAsFinished()
        
        imageIndex = 0
        
        assetWriter.finishWriting {
            print(self.outputSettings.outputURL)
            completion(self.outputSettings.outputURL)
        }
    }
}
