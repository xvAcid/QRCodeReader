//
//  ViewController.swift
//  QRCodeReaderExample
//  Created by Ishutin Vitaliy on 04/04/2018.
//  Copyright © 2018 WSG4FUN. All rights reserved.
//

import UIKit
import QRCodeReader

class ViewController: UIViewController, QRCodeReaderDelegate {
    private let qrCodeReader: QRCodeReader = QRCodeReader()
    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var scaledImageView: UIImageView!

    override func viewDidLoad() {
        super.viewDidLoad()
        qrCodeReader.delegate = self
        qrCodeReader.addScannerFrame(view: imageView,
                                     size: CGSize(width: 200, height: 200),
                                     imageLine: UIImage(named: "scannerLineImage")!)
        qrCodeReader.startRunning()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    func captured(image: UIImage) {
        imageView.image = image
    }
    
    func croped(image: UIImage) {
        scaledImageView.image = image
    }
    
    func recognizedQRCode(results: [QRCodeData]) {
        if !results.isEmpty {
            qrCodeReader.stopRunning()
            let resultsString = results.map{ $0.data }
            let stringData = resultsString.joined(separator: ",")
            
            let alert = UIAlertController(title: stringData, message: nil, preferredStyle: .alert)
            let cancelAction = UIAlertAction(title: "OK", style: .default, handler: { action in
                self.qrCodeReader.startRunning()
            })
            alert.addAction(cancelAction)
            self.present(alert, animated: true, completion: nil)
        }
    }
}

