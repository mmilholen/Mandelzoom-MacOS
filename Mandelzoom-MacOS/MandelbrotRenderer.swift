//
// Created by Rajib Singh on 6/18/16.
// Copyright (c) 2016 Sepoy Software. All rights reserved.
//

import Cocoa
import Foundation

class MandelbrotRenderer {
    
    let size: CGSize
    private let rgbColorSpace = CGColorSpaceCreateDeviceRGB()
    private let bitmapInfo: CGBitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.PremultipliedFirst.rawValue)
    internal var topLeft: ComplexNumber
    internal var bottomRight: ComplexNumber
    private let THRESHOLD = 10
    private let MAXITERATIONS = 100
    private let offset: ComplexNumber

    struct PixelData {
        var a: UInt8 = 255
        var r: UInt8 = 0
        var g: UInt8 = 0
        var b: UInt8 = 0

        init(red: UInt8, green: UInt8, blue: UInt8) {
            self.r = UInt8(red)
            self.g = UInt8(green)
            self.b = UInt8(blue)
        }
    }

    init(size: CGSize, topLeft: ComplexNumber, bottomRight: ComplexNumber) {
        self.size = size
        self.topLeft = topLeft
        self.bottomRight = bottomRight
        let dX = (bottomRight.x - topLeft.x) / Double(size.width)
        let dY = (bottomRight.y - topLeft.y) / Double(size.height)
        offset = ComplexNumber(x: dX, y: dY)
    }

    // create a bitmap and send that to the NSImage in the app
    func getImage() -> CGImage {
        let bitsPerComponent: UInt = 8
        let bitsPerPixel: UInt = 32
        var pixels = [PixelData]()
        var countArray = [Int]()

        for stepY: Int in 0 ... Int(size.height) - 1 {
            for stepX: Int in 0 ... Int(size.width) - 1 {
                let x = topLeft.x + (Double(stepX) * offset.x)
                let y = topLeft.y + (Double(stepY) * offset.y)
                let c: ComplexNumber = ComplexNumber(x: x, y: y)
                let count = getCount(c)
                countArray.append(count)
            }
        }

        let maxcolors = analyzeForColors(countArray)
        print("maxcolors: \(maxcolors)")

        var red:UInt8 = 255
        var green:UInt8 = 255
        var blue:UInt8 = 255
        var colorDelta:UInt8 = 0

        for count in countArray {
            // black
            var pixel:PixelData
            if count == MAXITERATIONS {
                red = UInt8(0)
                green = UInt8(0)
                blue = UInt8(0)
            }
            // white
            else if count == 1 {
                red = UInt8(255)
                green = UInt8(255)
                blue = UInt8(255)
            }
            // red
            else if (count > 1 && count < 7) {
                colorDelta = UInt8(255 - (42 * (7 - count)))
                green = colorDelta
                blue = colorDelta
                red = 255
            // green
            } else if (count >= 7 && count < 9) {
                colorDelta = UInt8(255 - (85 * (9 - count )))
                red = colorDelta
                blue = colorDelta
                green = 255
            // blue
            } else if count <   MAXITERATIONS {
                colorDelta = UInt8(255 - (2 * (MAXITERATIONS - count)))
                red = colorDelta
                green = colorDelta
                blue = 255
            }
            pixel = PixelData(red: red, green: green, blue: blue)
            pixels.append(pixel)
        }

        var data = pixels // Copy to mutable []
        let providerRef = CGDataProviderCreateWithCFData(
        NSData(bytes: &data, length: data.count * sizeof(PixelData))
        )
        let cgim = CGImageCreate(
        Int(size.width),
                Int(size.height),
                Int(bitsPerComponent),
                Int(bitsPerPixel),
                Int(size.width) * sizeof(PixelData),
                rgbColorSpace,
                bitmapInfo,
                providerRef,
                nil,
                true,
                CGColorRenderingIntent.RenderingIntentDefault
        )
        print("pixels size is \(pixels.count)");
        print("countArray size is \(countArray.count)")
        return cgim!
    }

    func getCount(c: ComplexNumber) -> Int{
        var count = 0
        var z = ComplexNumber(x: 0, y: 0)
        while (count < MAXITERATIONS && z.size() < 2) {
            count = count + 1
            z = z.squaredPlus(c)
        }
        return count
    }
    
    func zoom(zoomPct:Double) {
        let ht = bottomRight.y - topLeft.y
        let wdth = bottomRight.x - topLeft.x
        
        let newTopLeftX = topLeft.x - wdth * zoomPct
        let newTopLeftY = topLeft.y - ht * zoomPct
        let newTopLeft = ComplexNumber(x: newTopLeftX, y: newTopLeftY)
        topLeft = newTopLeft
        
        let newBottomRightX = bottomRight.x - wdth * zoomPct
        let newBottomRightY = bottomRight.y
        let newBottomRight = ComplexNumber(x: newBottomRightX, y: newBottomRightY)
        bottomRight = newBottomRight
    }
    
    func zoomIn() {
        zoom(0.10)
    }
    
    func zoomOut() {
        zoom(-0.10)
    }

    // just does analysis for now. is not altering the generated bitmap.
    func analyzeForColors(input : [Int]) -> Int  {
        var counts = [Int : Int]()
        for count in input {
            if counts[count] != nil {
                counts[count] = counts[count]! + 1
            } else {
                counts[count] = 1
            }
        }
        print("sorting keys")
        let keys = counts.keys.sort()
//        for key in keys {
//                print("key: \(key) value: \(counts[key]!)")
//        }
        return counts.count
    }
    
    
}

class ComplexNumber: CustomStringConvertible {
    var x: Double = 0
    var y: Double = 0
    var description: String {
        return "(\(self.x), \(self.y)i)"
    }

    init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }

    func size() -> Double {
        return sqrt(x * x + y * y)
    }

    func squaredPlus(c: ComplexNumber) -> ComplexNumber {
        return self.square().add(c)
    }

    func square() -> ComplexNumber {
        let newX = self.x * self.x - (y * y)
        let newY = (self.x * self.y) * 2
        return ComplexNumber(x: newX, y: newY)
    }

    func add(that: ComplexNumber) -> ComplexNumber {
        return ComplexNumber(x: self.x + that.x, y: self.y + that.y)
    }

    func isNear(that: ComplexNumber, distance: Int) -> Bool {
        let dX = that.x - self.x
        let dY = that.y - self.y
        if sqrt(dX * dX + dY * dY) <  Double(distance) {
            return true
        } else {
            return false
        }
    }

    func inBox(that: ComplexNumber, distance: Int) -> Bool {
        let dX = that.x - self.x
        let dY = that.y - self.y
        if abs(dX) < Double(distance) && abs(dY) < Double(distance) {
            return true
        } else {
            return false
        }
    }
}