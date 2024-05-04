import SwiftUI

// CREDIT: https://navsin.medium.com/recreating-the-ios-chat-bubble-with-the-tail-using-swiftui-1e3a3ab51647

struct BubbleShape: Shape {
  var myMessage : Bool
  func path(in rect: CGRect) -> Path {
    let width = rect.width
    let height = rect.height
    let factor: CGFloat = 0.85
    
    let bezierPath = UIBezierPath()
    if !myMessage {
      bezierPath.move(to: CGPoint(x: factor*20, y: height))
      bezierPath.addLine(to: CGPoint(x: width - factor*15, y: height))
      bezierPath.addCurve(to: CGPoint(x: width, y: height - factor*15), controlPoint1: CGPoint(x: width - factor*8, y: height), controlPoint2: CGPoint(x: width, y: height - factor*8))
      bezierPath.addLine(to: CGPoint(x: width, y: factor*15))
      bezierPath.addCurve(to: CGPoint(x: width - factor*15, y: factor*0), controlPoint1: CGPoint(x: width, y: factor*8), controlPoint2: CGPoint(x: width - factor*8, y: factor*0))
      bezierPath.addLine(to: CGPoint(x: factor*20, y: factor*0))
      bezierPath.addCurve(to: CGPoint(x: factor*5, y: factor*15), controlPoint1: CGPoint(x: factor*12, y: factor*0), controlPoint2: CGPoint(x: factor*5, y: factor*8))
      bezierPath.addLine(to: CGPoint(x: factor*5, y: height - factor*10))
      bezierPath.addCurve(to: CGPoint(x: factor*0, y: height), controlPoint1: CGPoint(x: factor*5, y: height - factor*1), controlPoint2: CGPoint(x: factor*0, y: height))
      bezierPath.addLine(to: CGPoint(x: -factor*1, y: height))
      bezierPath.addCurve(to: CGPoint(x: factor*12, y: height - factor*4), controlPoint1: CGPoint(x: factor*4, y: height + factor*1), controlPoint2: CGPoint(x: factor*8, y: height - factor*1))
      bezierPath.addCurve(to: CGPoint(x: factor*20, y: height), controlPoint1: CGPoint(x: factor*15, y: height), controlPoint2: CGPoint(x: factor*20, y: height))
    } else {
      bezierPath.move(to: CGPoint(x: width - factor*20, y: height))
      bezierPath.addLine(to: CGPoint(x: factor*15, y: height))
      bezierPath.addCurve(to: CGPoint(x: factor*0, y: height - factor*15), controlPoint1: CGPoint(x: factor*8, y: height), controlPoint2: CGPoint(x: factor*0, y: height - factor*8))
      bezierPath.addLine(to: CGPoint(x: factor*0, y: factor*15))
      bezierPath.addCurve(to: CGPoint(x: factor*15, y: factor*0), controlPoint1: CGPoint(x: factor*0, y: factor*8), controlPoint2: CGPoint(x: factor*8, y: factor*0))
      bezierPath.addLine(to: CGPoint(x: width - factor*20, y: factor*0))
      bezierPath.addCurve(to: CGPoint(x: width - factor*5, y: factor*15), controlPoint1: CGPoint(x: width - factor*12, y: factor*0), controlPoint2: CGPoint(x: width - factor*5, y: factor*8))
      bezierPath.addLine(to: CGPoint(x: width - factor*5, y: height - factor*12))
      bezierPath.addCurve(to: CGPoint(x: width, y: height), controlPoint1: CGPoint(x: width - factor*5, y: height - factor*1), controlPoint2: CGPoint(x: width, y: height))
      bezierPath.addLine(to: CGPoint(x: width + factor*1, y: height))
      bezierPath.addCurve(to: CGPoint(x: width - factor*12, y: height - factor*4), controlPoint1: CGPoint(x: width - factor*4, y: height + factor*1), controlPoint2: CGPoint(x: width - factor*8, y: height - factor*1))
      bezierPath.addCurve(to: CGPoint(x: width - factor*20, y: height), controlPoint1: CGPoint(x: width - factor*15, y: height), controlPoint2: CGPoint(x: width - factor*20, y: height))
    }
    return Path(bezierPath.cgPath)
  }
}
