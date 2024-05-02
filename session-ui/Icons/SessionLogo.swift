import Foundation
import SwiftUI

struct SessionLogo: Shape {
  func path(in rect: CGRect) -> Path {
    var path = Path()
    let width = rect.size.width
    let height = rect.size.height
    path.move(to: CGPoint(x: 0.71261*width, y: 0.93625*height))
    path.addLine(to: CGPoint(x: 0.22783*width, y: 0.93625*height))
    path.addCurve(to: CGPoint(x: 0.06941*width, y: 0.80422*height), control1: CGPoint(x: 0.14493*width, y: 0.93625*height), control2: CGPoint(x: 0.07349*width, y: 0.87891*height))
    path.addCurve(to: CGPoint(x: 0.22336*width, y: 0.65817*height), control1: CGPoint(x: 0.06503*width, y: 0.72439*height), control2: CGPoint(x: 0.13578*width, y: 0.65817*height))
    path.addLine(to: CGPoint(x: 0.50255*width, y: 0.65817*height))
    path.addCurve(to: CGPoint(x: 0.51439*width, y: 0.65605*height), control1: CGPoint(x: 0.50661*width, y: 0.65817*height), control2: CGPoint(x: 0.51064*width, y: 0.65745*height))
    path.addCurve(to: CGPoint(x: 0.52442*width, y: 0.65*height), control1: CGPoint(x: 0.51814*width, y: 0.65465*height), control2: CGPoint(x: 0.52155*width, y: 0.65259*height))
    path.addCurve(to: CGPoint(x: 0.53113*width, y: 0.64095*height), control1: CGPoint(x: 0.5273*width, y: 0.64741*height), control2: CGPoint(x: 0.52958*width, y: 0.64434*height))
    path.addCurve(to: CGPoint(x: 0.53348*width, y: 0.63028*height), control1: CGPoint(x: 0.53268*width, y: 0.63757*height), control2: CGPoint(x: 0.53348*width, y: 0.63394*height))
    path.addLine(to: CGPoint(x: 0.53348*width, y: 0.4247*height))
    path.addLine(to: CGPoint(x: 0.80817*width, y: 0.56199*height))
    path.addCurve(to: CGPoint(x: 0.92846*width, y: 0.74131*height), control1: CGPoint(x: 0.8808*width, y: 0.59829*height), control2: CGPoint(x: 0.92652*width, y: 0.66667*height))
    path.addCurve(to: CGPoint(x: 0.71261*width, y: 0.93625*height), control1: CGPoint(x: 0.93126*width, y: 0.8485*height), control2: CGPoint(x: 0.83147*width, y: 0.93625*height))
    path.closeSubpath()
    path.move(to: CGPoint(x: 0.18958*width, y: 0.43669*height))
    path.addCurve(to: CGPoint(x: 0.06928*width, y: 0.25737*height), control1: CGPoint(x: 0.11694*width, y: 0.40039*height), control2: CGPoint(x: 0.07122*width, y: 0.33201*height))
    path.addCurve(to: CGPoint(x: 0.28513*width, y: 0.06243*height), control1: CGPoint(x: 0.06648*width, y: 0.15019*height), control2: CGPoint(x: 0.16627*width, y: 0.06243*height))
    path.addLine(to: CGPoint(x: 0.7699*width, y: 0.06243*height))
    path.addCurve(to: CGPoint(x: 0.92834*width, y: 0.19446*height), control1: CGPoint(x: 0.85281*width, y: 0.06243*height), control2: CGPoint(x: 0.92424*width, y: 0.11978*height))
    path.addCurve(to: CGPoint(x: 0.77438*width, y: 0.34051*height), control1: CGPoint(x: 0.93271*width, y: 0.2743*height), control2: CGPoint(x: 0.86196*width, y: 0.34051*height))
    path.addLine(to: CGPoint(x: 0.49518*width, y: 0.34055*height))
    path.addCurve(to: CGPoint(x: 0.46431*width, y: 0.36844*height), control1: CGPoint(x: 0.47811*width, y: 0.34055*height), control2: CGPoint(x: 0.46432*width, y: 0.35304*height))
    path.addLine(to: CGPoint(x: 0.46426*width, y: 0.57398*height))
    path.addLine(to: CGPoint(x: 0.18958*width, y: 0.43669*height))
    path.closeSubpath()
    path.move(to: CGPoint(x: 0.84171*width, y: 0.50739*height))
    path.addLine(to: CGPoint(x: 0.63273*width, y: 0.40294*height))
    path.addLine(to: CGPoint(x: 0.77438*width, y: 0.40294*height))
    path.addCurve(to: CGPoint(x: 0.99774*width, y: 0.20148*height), control1: CGPoint(x: 0.89754*width, y: 0.40294*height), control2: CGPoint(x: 0.99774*width, y: 0.31256*height))
    path.addCurve(to: CGPoint(x: 0.77438*width, y: 0), control1: CGPoint(x: 0.99774*width, y: 0.09039*height), control2: CGPoint(x: 0.89754*width, y: 0))
    path.addLine(to: CGPoint(x: 0.27982*width, y: 0))
    path.addCurve(to: CGPoint(x: 0, y: 0.2524*height), control1: CGPoint(x: 0.12553*width, y: 0), control2: CGPoint(x: 0, y: 0.11324*height))
    path.addCurve(to: CGPoint(x: 0.15604*width, y: 0.4913*height), control1: CGPoint(x: 0, y: 0.35166*height), control2: CGPoint(x: 0.05979*width, y: 0.44319*height))
    path.addLine(to: CGPoint(x: 0.36501*width, y: 0.59574*height))
    path.addLine(to: CGPoint(x: 0.22336*width, y: 0.59574*height))
    path.addCurve(to: CGPoint(x: 0, y: 0.79721*height), control1: CGPoint(x: 0.1002*width, y: 0.59574*height), control2: CGPoint(x: 0, y: 0.68612*height))
    path.addCurve(to: CGPoint(x: 0.22336*width, y: 0.99868*height), control1: CGPoint(x: 0, y: 0.90829*height), control2: CGPoint(x: 0.1002*width, y: 0.99868*height))
    path.addLine(to: CGPoint(x: 0.71792*width, y: 0.99868*height))
    path.addCurve(to: CGPoint(x: 0.99774*width, y: 0.74628*height), control1: CGPoint(x: 0.87221*width, y: 0.99868*height), control2: CGPoint(x: 0.99774*width, y: 0.88545*height))
    path.addCurve(to: CGPoint(x: 0.84171*width, y: 0.50739*height), control1: CGPoint(x: 0.99774*width, y: 0.64702*height), control2: CGPoint(x: 0.93795*width, y: 0.55549*height))
    path.closeSubpath()
    return path
  }
}
