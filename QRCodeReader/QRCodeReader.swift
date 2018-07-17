//
//  QRCodeReader.swift
//  Created by Ishutin Vitaliy on 04/04/2018.
//  Copyright © 2018 WSG4FUN. All rights reserved.
//

import UIKit
import AVFoundation
import ZBarSDK

public class QRCodeReader: NSObject {
    public enum TourchState: Int {
        case on
        case off
    }
    
    private let quality             = AVCaptureSession.Preset.hd1920x1080
    private let sessionQuality      = AVCaptureSession.Preset.hd1920x1080
    private var permissionGranted   = false
    private var calcCorrection      = false
    private let sessionQueue        = DispatchQueue(label: "com.qrcodereader.camera_session_queue")
    private let captureQueue        = DispatchQueue(label: "com.qrcodereader.camera_capture_output")
    private let recognizeQueue      = DispatchQueue(label: "com.qrcodereader.image_recognize")
    private lazy var captureDevice  = AVCaptureDevice.default(for: AVMediaType.video)
    private let captureSession      = AVCaptureSession()
    private let context             = CIContext()
    private let zbarReader          = ZBarReaderController()

    private var scannerImageLine: UIImage? = nil
    private var scanner: CameraScannerFrame? = nil
    private var frameCount: Int = 0
    private var correctWidth: CGFloat = 0.0
    private var correctHeight: CGFloat = 0.0
    private var tourchState: TourchState = TourchState.off
    
    public weak var delegate: QRCodeReaderDelegate? = nil
    /** return scanner frame */
    public var scannerFrame: CGRect { return scanner?.scannerFrame ?? CGRect() }
    /** skipped frames after try to recognized image */
    public var skippedFrames: Int = 5
    
    /**
     * Add scanner frame to view with frame rect
     * - parameter view: parent view
     * - parameter frame: frame rect
     */
    public func addScannerFrame(view: UIView, size: CGSize, imageLine: UIImage?) {
        if scanner != nil {
            scanner?.removeFromSuperview()
            scanner = nil
        }

        scannerImageLine        = imageLine
        let viewCenterX         = ((view.bounds.size.width - view.bounds.origin.x) * 0.5)
        let viewCenterY         = ((view.bounds.size.height - view.bounds.origin.y) * 0.5)
        let posX: CGFloat       = viewCenterX - (size.width * 0.5)
        let posY: CGFloat       = viewCenterY - (size.height * 0.5)
        scanner                 = CameraScannerFrame(frame: view.bounds)
        scanner!.scannerFrame   = CGRect(x: posX, y: posY, width: size.width, height: size.height)
        if scannerImageLine != nil {
            scanner?.showScannerLine(image: scannerImageLine!)
        }
        view.addSubview(scanner!)
    }
    
    /** Stops an AVCaptureSession instance that is currently running. */
    public func stopRunning() {
        scanner?.showScannerLine(image: nil)
        captureSession.stopRunning()
    }
    
    /** Starts an AVCaptureSession instance running. */
    public func startRunning() {
        checkPermission()
        sessionQueue.async { [weak self] in
            guard let `self` = self else { return }
            self.configureSession()
            self.captureSession.startRunning()
            self.scanner?.showScannerLine(image: self.scannerImageLine!)
            
            if self.tourchState == TourchState.on {
                self.setTourchState(state: .on)
            }
        }
    }
    
    /**
     * Turns on or off tourch
     * - parameter state: tourch state
     */
    public func setTourchState(state: TourchState) {
        tourchState = state
        
        if captureDevice?.isTorchAvailable == true {
            try? captureDevice?.lockForConfiguration()
            switch tourchState {
            case .on:
                try? captureDevice?.setTorchModeOn(level: 1)
            case .off:
                try? captureDevice?.setTorchModeOn(level: 0)
            }
            captureDevice?.unlockForConfiguration()
        }
    }
    
    /**
     * Check user has granted permission for used camera
     */
    private func checkPermission() {
        switch AVCaptureDevice.authorizationStatus(for: AVMediaType.video) {
        case .authorized:
            permissionGranted = true
        case .notDetermined:
            requestPermission()
        default:
            permissionGranted = false
        }
    }
    
    /**
     * Request access permission for use camera
     */
    private func requestPermission() {
        sessionQueue.suspend()
        AVCaptureDevice.requestAccess(for: AVMediaType.video) { [weak self] granted in
            self?.permissionGranted = granted
            self?.sessionQueue.resume()
        }
    }
    
    /**
     * Configure camera session
     */
    private func configureSession() {
        guard permissionGranted else { return }
        captureSession.sessionPreset = sessionQuality
        guard let captureDeviceInput = try? AVCaptureDeviceInput(device: captureDevice!) else { return }
        
        if(captureDevice!.isFocusModeSupported(.continuousAutoFocus)) {
            try! captureDevice!.lockForConfiguration()
            captureDevice!.focusMode = .continuousAutoFocus
            captureDevice!.autoFocusRangeRestriction = .near
            captureDevice!.unlockForConfiguration()
        }
        
        guard captureSession.canAddInput(captureDeviceInput) else { return }
        captureSession.addInput(captureDeviceInput)
        
        let videoOutput = AVCaptureVideoDataOutput()
        videoOutput.setSampleBufferDelegate(self, queue: captureQueue)
        guard captureSession.canAddOutput(videoOutput) else { return }
        captureSession.addOutput(videoOutput)
        
        guard let connection = videoOutput.connection(with: AVFoundation.AVMediaType.video) else { return }
        guard connection.isVideoOrientationSupported else { return }
        connection.videoOrientation = .portrait
        connection.preferredVideoStabilizationMode = .standard
    }
    
    /**
     * Extract UIImage from CMSampleBuffer
     * - parameter sampleBuffer: sample buffer
     */
    private func imageFromSampleBuffer(sampleBuffer: CMSampleBuffer) -> UIImage? {
        guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return nil }
        let ciImage = CIImage(cvPixelBuffer: imageBuffer)
        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else { return nil }
        return UIImage(cgImage: cgImage)
    }
    
    /**
     * Prepare image for decoding.
     * - parameter image: Real image from camera
     */
    private func prepareImageForDecode(image: UIImage) -> UIImage {
        let rect = CGRect(x: scannerFrame.origin.x * correctWidth,
                          y: scannerFrame.origin.y * correctHeight,
                          width: scannerFrame.size.width * correctWidth,
                          height: scannerFrame.size.height * correctHeight)
        let croppedImage = image.cgImage?.cropping(to: rect)
        return UIImage(cgImage: croppedImage!)
    }
    
    /**
     * Find qr code from croped image and recognize data
     */
    private func recognizeImage(image: UIImage) {
        recognizeQueue.async { [weak self] in
            guard let `self` = self else { return }
            if self.frameCount >= self.skippedFrames {
                self.frameCount = 0
                let cropedImage = self.prepareImageForDecode(image: image)
                DispatchQueue.main.async {
                    self.delegate?.croped(image: cropedImage)
                }

                let symbols = self.zbarReader.scanImage(cropedImage.cgImage!)
                if symbols != nil {
                    var arrayResult: [QRCodeData] = []
                    guard let arraySymbols = symbols as? [ZBarSymbol] else { return }
                    for symbol in arraySymbols {
                        let data = QRCodeData()
                        data.data = symbol.data
                        data.frame = CGRect()
                        arrayResult.append(data)
                    }
                    
                    DispatchQueue.main.async {
                        self.delegate?.recognizedQRCode(results: arrayResult)
                    }
                }
            } else {
                self.frameCount += 1
            }
        }
    }

    /**
     * Calc correction width and height for rectangle scanner
     */
    private func calcCorrectionSize(size: CGSize) {
        if scanner != nil {
            self.calcCorrection = true
            self.correctWidth   = size.width / self.scanner!.frame.size.width
            self.correctHeight  = size.height / self.scanner!.frame.size.height
        }
    }
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate
extension QRCodeReader: AVCaptureVideoDataOutputSampleBufferDelegate {
    public func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let bufferImage = imageFromSampleBuffer(sampleBuffer: sampleBuffer) else { return }
        DispatchQueue.main.async { [weak self] in
            guard let `self` = self else { return }
            
            if !self.calcCorrection {
                self.calcCorrectionSize(size: bufferImage.size)
            }
            
            self.delegate?.captured(image: bufferImage)
            self.recognizeImage(image: bufferImage)
        }
    }
}
