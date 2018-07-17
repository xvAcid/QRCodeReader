//
//  CameraScannerFrame.swift
//  Created by Ishutin Vitaliy on 04/04/2018.
//  Copyright © 2018 WSG4FUN. All rights reserved.
//

import UIKit

public class CameraScannerFrame: UIView {
    public var scannerFrame: CGRect = CGRect()
    public var frameColor: UIColor = UIColor.white
    public var backgroundFade: UIColor = UIColor(red: 0, green: 0, blue: 0, alpha: 0.5)
    public var scannerLineDuration: CFTimeInterval = 2
    private var scannerLine: UIImageView? = nil
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        self.backgroundColor = UIColor.clear
    }
    
    required public init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public func showScannerLine(image: UIImage?) {
        guard let image = image else { return }
        
        DispatchQueue.main.async { [weak self] in
            guard let `self` = self else { return }
            
            self.scannerLine?.removeFromSuperview()
            self.scannerLine = UIImageView(image: image)
            self.scannerLine!.contentMode = .scaleAspectFit
            self.addSubview(self.scannerLine!)
            
            self.scannerLine!.frame = CGRect(x: self.scannerFrame.origin.x, y: self.scannerFrame.origin.y,
                                             width: self.scannerFrame.size.width, height: image.size.height)
            let animation           = CABasicAnimation(keyPath: "position.y")
            animation.fromValue     = self.scannerLine!.frame.origin.y
            animation.toValue       = self.scannerLine!.frame.origin.y + self.scannerFrame.size.width
            animation.repeatCount   = .infinity
            animation.duration      = self.scannerLineDuration
            self.scannerLine!.layer.add(animation, forKey: "scanner_line")
        }
    }
    
    public override func draw(_ rect: CGRect) {
        let context = UIGraphicsGetCurrentContext()
        context?.setStrokeColor(frameColor.cgColor)
        context?.setLineWidth(1)
        context?.addRect(scannerFrame)
        context?.strokePath()
        
        backgroundFade.setFill()
        let rectangleMinY = self.frame.size.height * 0.5 - scannerFrame.size.height * 0.5
        let rectangleMaxY = rectangleMinY + scannerFrame.size.height
        
        var rect = CGRect(x: 0, y: 0, width: self.frame.size.width, height: rectangleMinY)
        context?.fill(rect)
        
        rect = CGRect(x: 0, y: rectangleMaxY, width: self.frame.size.width, height: rectangleMinY)
        context?.fill(rect)
        
        rect = CGRect(x: 0, y: rectangleMinY, width: self.frame.size.width * 0.5 - scannerFrame.size.width * 0.5, height: scannerFrame.size.height)
        context?.fill(rect)
        
        rect = CGRect(x: scannerFrame.origin.x + scannerFrame.size.width, y: rectangleMinY,
                      width: self.frame.size.width * 0.5 - scannerFrame.size.width * 0.5, height: scannerFrame.size.height)
        context?.fill(rect)
    }
}
