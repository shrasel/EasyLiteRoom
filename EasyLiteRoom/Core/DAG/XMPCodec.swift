//
//  XMPCodec.swift
//  EasyLiteRoom
//
//  Created by Shahjahan Rasel on 10/13/26.
//  Non-destructive XMP sidecar XML serialization and synchronization.
//

import Foundation

public enum XMPCodec {

    /// Serializes adjustment parameters into standard XMP sidecar XML.
    public static func exportToXMP(parameters: AdjustmentParameters) -> String {
        let knotsString = parameters.toneCurveKnots.map { String(format: "%.4f,%.4f", $0.x, $0.y) }.joined(separator: ";")

        return """
        <x:xmpmeta xmlns:x="adobe:ns:meta/" x:xmptk="EasyLiteRoom 1.0">
         <rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#">
          <rdf:Description rdf:about=""
            xmlns:crs="http://ns.adobe.com/camera-raw-settings/1.0/"
            crs:Version="16.0"
            crs:ProcessVersion="15.4"
            crs:Temperature="\(parameters.temperature)"
            crs:Tint="\(parameters.tint)"
            crs:Exposure2012="\(parameters.exposure)"
            crs:Contrast2012="\(parameters.contrast)"
            crs:Highlights2012="\(parameters.highlights)"
            crs:Shadows2012="\(parameters.shadows)"
            crs:Whites2012="\(parameters.whites)"
            crs:Blacks2012="\(parameters.blacks)"
            crs:Vibrance="\(parameters.vibrance)"
            crs:Saturation="\(parameters.saturation)"
            crs:Sharpening="\(parameters.detail.sharpening)"
            crs:LuminanceSmoothing="\(parameters.detail.noiseReduction)"
            crs:ToneCurveKnots="\(knotsString)">
           <crs:HueAdjustments>
            <rdf:Seq>
             <rdf:li crs:Red="\(parameters.hsl.red.hue)"/>
             <rdf:li crs:Orange="\(parameters.hsl.orange.hue)"/>
             <rdf:li crs:Yellow="\(parameters.hsl.yellow.hue)"/>
             <rdf:li crs:Green="\(parameters.hsl.green.hue)"/>
             <rdf:li crs:Aqua="\(parameters.hsl.aqua.hue)"/>
             <rdf:li crs:Blue="\(parameters.hsl.blue.hue)"/>
             <rdf:li crs:Purple="\(parameters.hsl.purple.hue)"/>
             <rdf:li crs:Magenta="\(parameters.hsl.magenta.hue)"/>
            </rdf:Seq>
           </crs:HueAdjustments>
           <crs:SaturationAdjustments>
            <rdf:Seq>
             <rdf:li crs:Red="\(parameters.hsl.red.saturation)"/>
             <rdf:li crs:Orange="\(parameters.hsl.orange.saturation)"/>
             <rdf:li crs:Yellow="\(parameters.hsl.yellow.saturation)"/>
             <rdf:li crs:Green="\(parameters.hsl.green.saturation)"/>
             <rdf:li crs:Aqua="\(parameters.hsl.aqua.saturation)"/>
             <rdf:li crs:Blue="\(parameters.hsl.blue.saturation)"/>
             <rdf:li crs:Purple="\(parameters.hsl.purple.saturation)"/>
             <rdf:li crs:Magenta="\(parameters.hsl.magenta.saturation)"/>
            </rdf:Seq>
           </crs:SaturationAdjustments>
           <crs:LuminanceAdjustments>
            <rdf:Seq>
             <rdf:li crs:Red="\(parameters.hsl.red.luminance)"/>
             <rdf:li crs:Orange="\(parameters.hsl.orange.luminance)"/>
             <rdf:li crs:Yellow="\(parameters.hsl.yellow.luminance)"/>
             <rdf:li crs:Green="\(parameters.hsl.green.luminance)"/>
             <rdf:li crs:Aqua="\(parameters.hsl.aqua.luminance)"/>
             <rdf:li crs:Blue="\(parameters.hsl.blue.luminance)"/>
             <rdf:li crs:Purple="\(parameters.hsl.purple.luminance)"/>
             <rdf:li crs:Magenta="\(parameters.hsl.magenta.luminance)"/>
            </rdf:Seq>
           </crs:LuminanceAdjustments>
          </rdf:Description>
         </rdf:RDF>
        </x:xmpmeta>
        """
    }

    /// Parses an XMP sidecar string and extracts non-destructive parameters.
    public static func parseXMP(xmlString: String) -> AdjustmentParameters {
        var params = AdjustmentParameters()

        func extractFloat(attr: String) -> Float? {
            let pattern = "\(attr)=\"([^\"]+)\""
            guard let regex = try? NSRegularExpression(pattern: pattern),
                  let match = regex.firstMatch(in: xmlString, range: NSRange(xmlString.startIndex..., in: xmlString)),
                  let range = Range(match.range(at: 1), in: xmlString) else {
                return nil
            }
            return Float(xmlString[range])
        }

        func extractString(attr: String) -> String? {
            let pattern = "\(attr)=\"([^\"]+)\""
            guard let regex = try? NSRegularExpression(pattern: pattern),
                  let match = regex.firstMatch(in: xmlString, range: NSRange(xmlString.startIndex..., in: xmlString)),
                  let range = Range(match.range(at: 1), in: xmlString) else {
                return nil
            }
            return String(xmlString[range])
        }

        if let temp = extractFloat(attr: "crs:Temperature") { params.temperature = temp }
        if let tint = extractFloat(attr: "crs:Tint") { params.tint = tint }
        if let exp = extractFloat(attr: "crs:Exposure2012") { params.exposure = exp }
        if let contrast = extractFloat(attr: "crs:Contrast2012") { params.contrast = contrast }
        if let hl = extractFloat(attr: "crs:Highlights2012") { params.highlights = hl }
        if let sh = extractFloat(attr: "crs:Shadows2012") { params.shadows = sh }
        if let wh = extractFloat(attr: "crs:Whites2012") { params.whites = wh }
        if let bl = extractFloat(attr: "crs:Blacks2012") { params.blacks = bl }
        if let vib = extractFloat(attr: "crs:Vibrance") { params.vibrance = vib }
        if let sat = extractFloat(attr: "crs:Saturation") { params.saturation = sat }
        if let sharp = extractFloat(attr: "crs:Sharpening") { params.detail.sharpening = sharp }
        if let nr = extractFloat(attr: "crs:LuminanceSmoothing") { params.detail.noiseReduction = nr }

        // Parse Tone Curve Knots
        if let knotsRaw = extractString(attr: "crs:ToneCurveKnots") {
            let knotPairs = knotsRaw.split(separator: ";")
            var parsedKnots: [SplinePoint] = []
            for pair in knotPairs {
                let coords = pair.split(separator: ",")
                if coords.count == 2, let x = Float(coords[0]), let y = Float(coords[1]) {
                    parsedKnots.append(SplinePoint(x: x, y: y))
                }
            }
            if parsedKnots.count >= 2 {
                params.toneCurveKnots = parsedKnots
            }
        }

        return params
    }

    /// Saves an XMP sidecar file next to the photo file URL.
    public static func saveSidecar(for photoURL: URL, parameters: AdjustmentParameters) throws {
        let xmpURL = photoURL.deletingPathExtension().appendingPathExtension("xmp")
        let xml = exportToXMP(parameters: parameters)
        try xml.write(to: xmpURL, atomically: true, encoding: .utf8)
    }

    /// Loads adjustment parameters from an XMP sidecar file if it exists next to the photo file URL.
    public static func loadSidecar(for photoURL: URL) -> AdjustmentParameters? {
        let xmpURL = photoURL.deletingPathExtension().appendingPathExtension("xmp")
        guard FileManager.default.fileExists(atPath: xmpURL.path),
              let xml = try? String(contentsOf: xmpURL, encoding: .utf8) else {
            return nil
        }
        return parseXMP(xmlString: xml)
    }
}
