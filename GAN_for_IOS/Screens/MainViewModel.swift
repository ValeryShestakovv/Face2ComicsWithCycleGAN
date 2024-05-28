import Accelerate
import AVFoundation
import Vision
import CoreVideo
import UIKit
import Photos
import AVKit

protocol MainViewModelDelegate: AnyObject {
    var imageView: UIImageView { get set }
    func setPhoto(image: UIImage)
    func playVideo(_ url: URL)
}

final class MainViewModel: NSObject {
    
    private var captureDevice: AVCaptureDevice?
    private var backCamera: AVCaptureDevice?
    private var frontCamera: AVCaptureDevice?
    
    private var backInput: AVCaptureInput!
    private var frontInput: AVCaptureInput!
    private let dataOutputQueue = DispatchQueue(label: "video data queue",
                                           qos: .userInteractive,
                                           attributes: [],
                                           autoreleaseFrequency: .workItem)
    private let imageProcessQueue = DispatchQueue(label: "videocreate queue",
                                           qos: .userInteractive,
                                           attributes: [],
                                           autoreleaseFrequency: .workItem)
    
    private var backCameraOn = true
    private var cvPixelBuffferArrayForVideo = [CVPixelBuffer]()
    
    let captureSession = AVCaptureSession()
    let videoOutput = AVCaptureVideoDataOutput()
    
    var cvPixelBuffer: CVPixelBuffer?
    var recordVideoIsRun = false
    var renderCameraPreview = true
    var realtimeRender = false
    
    // Bi-Planar Component Y'CbCr 8-bit 4:2:0, video-range (luma=[16,235] chroma=[16,240]).
    static let cvPixelFormat = kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange
    static let sessionPreset = AVCaptureSession.Preset.hd1280x720
    static let width = 1280
    static let height = 720
    
    let argbPixelBuffer = vImage.PixelBuffer(width: width,
                                             height: height,
                                             pixelFormat: vImage.Interleaved8x4.self)
    
    weak var delegate: MainViewModelDelegate?
    
    var effect = VideoEffects.comics
    var videoUrl: URL?
    
    override init() {
        super.init()
        setupAndStartCaptureSession()
        configureYpCbCrToARGBInfo()
    }
    
    var infoYpCbCrToARGB = vImage_YpCbCrToARGB()
    
    func configureYpCbCrToARGBInfo() {
        var pixelRange = vImage_YpCbCrPixelRange(Yp_bias: 16,
                                                 CbCr_bias: 128,
                                                 YpRangeMax: 235,
                                                 CbCrRangeMax: 240,
                                                 YpMax: 235,
                                                 YpMin: 16,
                                                 CbCrMax: 240,
                                                 CbCrMin: 16)
        
        _ = vImageConvert_YpCbCrToARGB_GenerateConversion(
            kvImage_YpCbCrToARGBMatrix_ITU_R_601_4!,
            &pixelRange,
            &infoYpCbCrToARGB,
            kvImage422CbYpCrYp8,
            kvImageARGB8888,
            vImage_Flags(kvImageNoFlags))
    }
    
    var cgImageFormat = vImage_CGImageFormat(
        bitsPerComponent: 8,
        bitsPerPixel: 8 * 4,
        colorSpace: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.noneSkipFirst.rawValue))!
    
    func convertYpCbCrToRGB(cvPixelBuffer: CVPixelBuffer) {
        assert(CVPixelBufferGetPlaneCount(cvPixelBuffer) == 2, "Pixel buffer should have two planes.")
        
        let lumaPixelBuffer = vImage.PixelBuffer(referencing: cvPixelBuffer,
                                                 planeIndex: 0,
                                                 pixelFormat: vImage.Planar8.self)
   
        let chromaPixelBuffer = vImage.PixelBuffer(referencing: cvPixelBuffer,
                                                   planeIndex: 1,
                                                   pixelFormat: vImage.Interleaved8x2.self)
        
        argbPixelBuffer.convert(lumaSource: lumaPixelBuffer,
                                chromaSource: chromaPixelBuffer,
                                conversionInfo: infoYpCbCrToARGB)
    }
    
    func resizeCVPixelBufferRGBFormat() {
        guard let resizedPixelBuffer = self.createPixelBuffer(width: 256, height: 256) else { return }
        argbPixelBuffer.withCVPixelBuffer(readOnly: true) { CVPixelBuffer in
            resizePixelBuffer(from: CVPixelBuffer, to: resizedPixelBuffer, width: 256, height: 256)
            self.cvPixelBuffer = resizedPixelBuffer
        }
    }
        
    func generateFrame(frame: CVPixelBuffer) -> CVPixelBuffer? {
        do {
            let config = MLModelConfiguration()
            config.computeUnits = .all
            
            switch effect {
            case .comics:
                let model = try model_comics_fp16(configuration: config)
                let input = model_comics_fp16Input(input_1: frame)
                let output = try model.prediction(input: input)
                return output.var_413
            case .anime:
                let model = try model_anime_fp16(configuration: config)
                let input = model_anime_fp16Input(input_1: frame)
                let output = try model.prediction(input: input)
                return output.var_413
            case .simpson:
                let model = try model_simpson_fp16(configuration: config)
                let input = model_simpson_fp16Input(input_1: frame)
                let output = try model.prediction(input: input)
                return output.var_413
            case .noise:
                return nil
            }
            
        } catch {
            print(error.localizedDescription)
            return nil
        }
    }
    
    func renderDestinationBuffer() {
        if renderCameraPreview {
            guard var pixelBuffer = self.cvPixelBuffer else { return }
            if realtimeRender {
                guard let frame = self.generateFrame(frame: pixelBuffer) else { return }
                pixelBuffer = frame
            }
            DispatchQueue.main.sync {
                let ciimage = CIImage(cvPixelBuffer: pixelBuffer).oriented(CGImagePropertyOrientation.right)
                let context = CIContext()
                guard let cgImage = context.createCGImage(ciimage, from: ciimage.extent) else { return  }
                self.delegate?.imageView.layer.contents = cgImage
            }
        } else { return }
    }
    
    func switchCameraInput() {
        captureSession.beginConfiguration()
        if backCameraOn {
            captureSession.removeInput(backInput)
            captureSession.addInput(frontInput)
            captureDevice = frontCamera
            backCameraOn = false
        } else {
            captureSession.removeInput(frontInput)
            captureSession.addInput(backInput)
            captureDevice = backCamera
            backCameraOn = true
        }
        captureSession.commitConfiguration()
    }

    private func currentDevice() -> AVCaptureDevice? {
        guard let device = AVCaptureDevice.default(for: .video) else { return nil }
        return device
    }

    private func setupAndStartCaptureSession() {
        dataOutputQueue.async { [weak self] in
            self?.captureSession.beginConfiguration()

            if let canSetSessionPreset = self?.captureSession.canSetSessionPreset(.photo), canSetSessionPreset {
                self?.captureSession.sessionPreset = MainViewModel.sessionPreset
            }
            self?.captureSession.automaticallyConfiguresCaptureDeviceForWideColor = true

            self?.setupInputs()
            self?.setupOutput()

            self?.captureSession.commitConfiguration()
            self?.captureSession.startRunning()
        }
    }

    private func setupInputs() {
        backCamera = currentDevice()
        frontCamera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front)

        guard let backCamera = backCamera,
              let frontCamera = frontCamera
        else {
            return
        }

        do {
            backInput = try AVCaptureDeviceInput(device: backCamera)
            guard captureSession.canAddInput(backInput) else {
                return
            }

            frontInput = try AVCaptureDeviceInput(device: frontCamera)
            guard captureSession.canAddInput(frontInput) else {
                return
            }
        } catch {
            fatalError("could not connect camera")
        }

        captureDevice = backCamera

        captureSession.addInput(backInput)
    }

    private func setupOutput() {
        videoOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: MainViewModel.cvPixelFormat]
        videoOutput.alwaysDiscardsLateVideoFrames = true
        videoOutput.setSampleBufferDelegate(self,
                                            queue: dataOutputQueue)
        
        if captureSession.canAddOutput(videoOutput) {
            captureSession.addOutput(videoOutput)
        } else {
            fatalError("Unable to add video output.")
        }
    }

    private func updateZoom(scale: CGFloat) {
        do {
            defer { captureDevice?.unlockForConfiguration() }
            try captureDevice?.lockForConfiguration()
            captureDevice?.videoZoomFactor = scale
        } catch {
            print(error.localizedDescription)
        }
    }
    
    func configureVideo() {
        for (index, value) in cvPixelBuffferArrayForVideo.enumerated() {
            imageProcessQueue.sync { [self] in
                guard let frame = generateFrame(frame: value) else { return }
                cvPixelBuffferArrayForVideo[index] = frame
            }
        }

        let outputSettings = VideoOutputSettings(size: CGSize(width: 256, height: 256),
                                                 fps: 30)
        
        let movieMaker = VideoMaker(outputSettings: outputSettings)
        
        movieMaker.start()
        
        for image in cvPixelBuffferArrayForVideo
        {
            movieMaker.addImage(image: image)
        }
        
        movieMaker.finish { [weak self] (url) in
            if let url = url
            {
                self?.videoUrl = url
                DispatchQueue.main.async { [self] in
                    self?.delegate?.playVideo(url)
                }
            }
        }

    }
    func saveVideoInLibrary() {
        if let url = videoUrl {
            PHPhotoLibrary.shared().performChanges({
                PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: url)
            }) { saved, error in
                if saved {
                    let fetchOptions = PHFetchOptions()
                    fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]

                    let fetchResult = PHAsset.fetchAssets(with: .video, options: fetchOptions).firstObject
                }
            }
        }
    
    }
    
    func configureFrames(cvPixelBuffer: CVPixelBuffer?) {
        if recordVideoIsRun == true {
            guard let frame = cvPixelBuffer else { return }
            cvPixelBuffferArrayForVideo.append(frame)
        } else {
            if !cvPixelBuffferArrayForVideo.isEmpty {
                configureVideo()
                cvPixelBuffferArrayForVideo.removeAll()
            }
        }
    }
}

extension MainViewModel: AVCaptureVideoDataOutputSampleBufferDelegate {
   
    func captureOutput(_ output: AVCaptureOutput,
                       didOutput sampleBuffer: CMSampleBuffer,
                       from connection: AVCaptureConnection) {
        
        guard let pixelBuffer = sampleBuffer.imageBuffer else {
            return
        }
     
        CVPixelBufferLockBaseAddress(
            pixelBuffer,
            CVPixelBufferLockFlags.readOnly)
        
        convertYpCbCrToRGB(cvPixelBuffer: pixelBuffer)
        resizeCVPixelBufferRGBFormat()
        renderDestinationBuffer()
        configureFrames(cvPixelBuffer: self.cvPixelBuffer)
        
        CVPixelBufferUnlockBaseAddress(
            pixelBuffer,
            CVPixelBufferLockFlags.readOnly)
    }
}

extension MainViewModel {

    func createPixelBuffer(width: Int, height: Int) -> CVPixelBuffer? {
        var pixelBuffer: CVPixelBuffer?
        let attributes = [
            kCVPixelBufferCGImageCompatibilityKey as String: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey as String: true,
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32ARGB
        ] as [String : Any]
        let status = CVPixelBufferCreate(kCFAllocatorDefault, width, height, kCVPixelFormatType_32ARGB, attributes as CFDictionary, &pixelBuffer)
        guard status == kCVReturnSuccess, let buffer = pixelBuffer else {
            return nil
        }
        return buffer
    }
}
