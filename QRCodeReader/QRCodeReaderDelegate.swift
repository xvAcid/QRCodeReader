//
//  QRCodeReaderDelegate.swift
//  Created by Ishutin Vitaliy on 04/04/2018.
//  Copyright © 2018 WSG4FUN. All rights reserved.
//

import UIKit

public class QRCodeData: NSObject {
    public var frame: CGRect = CGRect()
    public var data: String = ""
}

public protocol QRCodeReaderDelegate: class {
    /** call every time when working camera and take image */
    func captured(image: UIImage)
    /** call when qr code is recognized and return array of QRCodeData */
    func recognizedQRCode(results: [QRCodeData])
    /** call when croped image */
    func croped(image: UIImage)
}
