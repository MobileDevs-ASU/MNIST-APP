//
//  ViewController.swift
//  MNIST-APP
//
//  Created by Paul Butler on 1/22/18.
//  Copyright © 2018 Paul Butler. All rights reserved.
//

import UIKit
import CoreML

class ViewController: UIViewController {
    @IBOutlet weak var drawPad: UIImageView!
    @IBOutlet weak var tempImage: UIImageView!
    @IBOutlet weak var predictedLabel: UILabel!
    
    let model = mnist_cnn()
    
    var lastPoint = CGPoint.zero
    var red: CGFloat = 255.0
    var green: CGFloat = 255.0
    var blue: CGFloat = 255.0
    var brushWidth: CGFloat = 20.0
    var opacity: CGFloat = 1.0
    var swiped = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        tempImage.layer.borderColor = UIColor.darkText.cgColor
        tempImage.layer.borderWidth = 2
        predictedLabel.text = "You have not entered a number"
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        swiped=false
        if let touch = touches.first {
            lastPoint = touch.location(in: drawPad)
        }
    }
    
    func drawLine(fromPoint: CGPoint, toPoint: CGPoint) {
        UIGraphicsBeginImageContext(drawPad.frame.size)
        let context = UIGraphicsGetCurrentContext()
        tempImage.image?.draw(in: CGRect(x: 0, y: 0, width: drawPad.frame.width, height: drawPad.frame.height))
        context?.move(to: CGPoint(x: fromPoint.x, y: fromPoint.y))
        context?.addLine(to: CGPoint(x: toPoint.x, y: toPoint.y))
        context?.setLineCap(CGLineCap.round)
        context?.setLineWidth(brushWidth)
        context?.setStrokeColor(red: red, green: green, blue: blue, alpha: opacity)
        context?.setBlendMode(.normal)
        context?.strokePath()
        
        tempImage.image = UIGraphicsGetImageFromCurrentImageContext()
        tempImage.alpha = opacity
        UIGraphicsEndImageContext()
    }
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        swiped = true
        if let touch = touches.first {
            let currenPoint = touch.location(in: drawPad)
            drawLine(fromPoint: lastPoint, toPoint: currenPoint)
            lastPoint = currenPoint
        }
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        if !swiped {
            drawLine(fromPoint: lastPoint, toPoint: lastPoint)
        }
        UIGraphicsBeginImageContext(drawPad.frame.size)
        drawPad.image?.draw(in: CGRect(x: 0, y: 0, width: drawPad.frame.width, height: drawPad.frame.height), blendMode: .normal, alpha: 1.0)
        tempImage.image?.draw(in: CGRect(x: 0, y: 0, width: tempImage.frame.width, height: tempImage.frame.height), blendMode: .normal, alpha: 1.0)
        drawPad.image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        tempImage.image = nil
    }

    @IBAction func onResetPressed(_ sender: UIButton) {
        clear()
        predictedLabel.text = "You have not entered a number"
    }
    
    @IBAction func predictDidPressed(_ sender: UIButton) {
        let cImage = getViewContext(withImage: drawPad).makeImage()
        
        if let cgImg = UIImage(cgImage: cImage!).pixelBuffer() {
            let output = try? model.prediction(image: cgImg)
            if let prediction = output {
                predictedLabel.text = "The Number you wrote is: \(prediction.classLabel)"
            }
        }
    }
    
    func getViewContext(withImage image: UIImageView) -> CGContext {
        let colorSpace: CGColorSpace = CGColorSpaceCreateDeviceGray()
        let bitmapInfo = CGImageAlphaInfo.none.rawValue
        let context = CGContext(data: nil, width: 28, height: 28, bitsPerComponent: 8, bytesPerRow: 28, space: colorSpace, bitmapInfo: bitmapInfo)
        context!.translateBy(x: 0, y: 28)
        context!.scaleBy(x: 28/image.frame.size.width, y: -28/image.frame.size.width)
        image.layer.render(in: context!)
        return context!
    }
    
    
    func clear() {
        drawPad.image = nil
        tempImage.image = nil
    }
    
    func resizeImage(image: UIImage, newWidth: CGFloat) -> UIImage {
        let scale = newWidth / image.size.width
        let newHeight = image.size.height * scale
        UIGraphicsBeginImageContext(CGSize(width: newWidth, height: newHeight))
        image.draw(in: CGRect(x: 0, y: 0, width: newWidth, height: newHeight))
        let newImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        if let returnImg = newImage {
            return returnImg
        }else{
            return UIImage()
        }
    }
    
}

extension UIImage {
    func pixelBuffer() -> CVPixelBuffer? {
        let width = self.size.width
        let height = self.size.height
        let attrs = [kCVPixelBufferCGImageCompatibilityKey: kCFBooleanTrue,
                     kCVPixelBufferCGBitmapContextCompatibilityKey: kCFBooleanTrue] as CFDictionary
        var pixelBuffer: CVPixelBuffer?
        let status = CVPixelBufferCreate(kCFAllocatorDefault,
                                         Int(width),
                                         Int(height),
                                         kCVPixelFormatType_OneComponent8,
                                         attrs,
                                         &pixelBuffer)
        
        guard let resultPixelBuffer = pixelBuffer, status == kCVReturnSuccess else {
            return nil
        }
        
        CVPixelBufferLockBaseAddress(resultPixelBuffer, CVPixelBufferLockFlags(rawValue: 0))
        let pixelData = CVPixelBufferGetBaseAddress(resultPixelBuffer)
        
        let grayColorSpace = CGColorSpaceCreateDeviceGray()
        guard let context = CGContext(data: pixelData,
                                      width: Int(width),
                                      height: Int(height),
                                      bitsPerComponent: 8,
                                      bytesPerRow: CVPixelBufferGetBytesPerRow(resultPixelBuffer),
                                      space: grayColorSpace,
                                      bitmapInfo: CGImageAlphaInfo.none.rawValue) else {
                                        return nil
        }
        
        context.translateBy(x: 0, y: height)
        context.scaleBy(x: 1.0, y: -1.0)
        
        UIGraphicsPushContext(context)
        self.draw(in: CGRect(x: 0, y: 0, width: width, height: height))
        UIGraphicsPopContext()
        CVPixelBufferUnlockBaseAddress(resultPixelBuffer, CVPixelBufferLockFlags(rawValue: 0))
        
        return resultPixelBuffer
    }
}


