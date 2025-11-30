//
//  String+replaceUTF8Diacritics.swift
//  Photo Club Hub Data
//
//  Created by Peter van den Hamer on 26/11/2025.
//

import Foundation

// Converts strings containing lower-case symbols with diacritic marks like "é"
// to an HTML version of Unicode UTF-8 symbols like "&#xE9;}" that doesn't require UTF-8 support by web server.
// If the Unicode string is not listed below, it is kept as is: increasingly web servers support UTF-8
// so this list just contains common cases covered by the shortcuts provided for Mac/iPadOS keyboard entry.

extension String {
    public var replacingUTF8Diacritics: String {
        var string = self

        // fast return of unchanged strings that are ASCII only
        if self.unicodeScalars.allSatisfy({ $0.isASCII }) { return self }

        // a - character family that can be typed on Apple systems by long-pressing this key
        string = string.replacingOccurrences(of: "à", with: "&#xE0;")
        string = string.replacingOccurrences(of: "á", with: "&#xE1;")
        string = string.replacingOccurrences(of: "â", with: "&#xE2;")
        string = string.replacingOccurrences(of: "ã", with: "&#xE3;")
        string = string.replacingOccurrences(of: "ä", with: "&#xE4;")
        string = string.replacingOccurrences(of: "å", with: "&#xE5;")
        string = string.replacingOccurrences(of: "æ", with: "&#xE6;")
        string = string.replacingOccurrences(of: "ā", with: "&#x101;")
        string = string.replacingOccurrences(of: "ǎ", with: "&#x1CE;")

        // c - character family that can be typed on Apple systems by long-pressing this key
        string = string.replacingOccurrences(of: "ç", with: "&#xE7;")
        string = string.replacingOccurrences(of: "ć", with: "&#x107;")
        string = string.replacingOccurrences(of: "ċ", with: "&#x10B;")
        string = string.replacingOccurrences(of: "č", with: "&#x10D;")

        // d - character family that can be typed on Apple systems by long-pressing this key
        string = string.replacingOccurrences(of: "ď", with: "&#x10F;")
        string = string.replacingOccurrences(of: "ð", with: "&#xF0;")

        // e - character family that can be typed on Apple systems by long-pressing this key
        string = string.replacingOccurrences(of: "è", with: "&#xE8;")
        string = string.replacingOccurrences(of: "é", with: "&#xE9;")
        string = string.replacingOccurrences(of: "ê", with: "&#xEA;")
        string = string.replacingOccurrences(of: "ë", with: "&#xEB;")
        string = string.replacingOccurrences(of: "ě", with: "&#x11B;")
        string = string.replacingOccurrences(of: "ē", with: "&#x113;")
        string = string.replacingOccurrences(of: "ė", with: "&#x117;")
        string = string.replacingOccurrences(of: "ę", with: "&#x119;")
        string = string.replacingOccurrences(of: "ẽ", with: "&#x1EBD;")

        // g - character family that can be typed on Apple systems by long-pressing this key
        string = string.replacingOccurrences(of: "ğ", with: "&#x11F;")
        string = string.replacingOccurrences(of: "ġ", with: "&#x121;")

        // h - character family that can be typed on Apple systems by long-pressing this key
        string = string.replacingOccurrences(of: "ħ", with: "&#x127;")

        // i - character family that can be typed on Apple systems by long-pressing this key
        string = string.replacingOccurrences(of: "ì", with: "&#xEC;")
        string = string.replacingOccurrences(of: "í", with: "&#xED;")
        string = string.replacingOccurrences(of: "î", with: "&#xEE;")
        string = string.replacingOccurrences(of: "ï", with: "&#xEF;")
        string = string.replacingOccurrences(of: "ǐ", with: "&#x1D0;")
        string = string.replacingOccurrences(of: "ĩ", with: "&#x129;")
        string = string.replacingOccurrences(of: "ī", with: "&#x12B;")
        string = string.replacingOccurrences(of: "į", with: "&#x12F;")
        string = string.replacingOccurrences(of: "ı", with: "&#x131;")

        // k - character family that can be typed on Apple systems by long-pressing this key
        string = string.replacingOccurrences(of: "ķ", with: "&#x137;")

        // i - character family that can be typed on Apple systems by long-pressing this key
        string = string.replacingOccurrences(of: "ł", with: "&#x142;")
        string = string.replacingOccurrences(of: "ļ", with: "&#x13C;")
        string = string.replacingOccurrences(of: "ľ", with: "&#x13E;")

        // n - character family that can be typed on Apple systems by long-pressing this key
        string = string.replacingOccurrences(of: "ñ", with: "&#xF1;")
        string = string.replacingOccurrences(of: "ń", with: "&#x144;")
        string = string.replacingOccurrences(of: "ņ", with: "&#x146;")
        string = string.replacingOccurrences(of: "ň", with: "&#x148;")

        // o - character family that can be typed on Apple systems by long-pressing this key
        string = string.replacingOccurrences(of: "ò", with: "&#xF2;")
        string = string.replacingOccurrences(of: "ó", with: "&#xF3;")
        string = string.replacingOccurrences(of: "ô", with: "&#xF4;")
        string = string.replacingOccurrences(of: "õ", with: "&#xF5;")
        string = string.replacingOccurrences(of: "ö", with: "&#xF6;")
        string = string.replacingOccurrences(of: "ø", with: "&#xF8;")
        string = string.replacingOccurrences(of: "ō", with: "&#x14D;")
        string = string.replacingOccurrences(of: "œ", with: "&#x153;")
        string = string.replacingOccurrences(of: "ǒ", with: "&#x1D2;")

        // r - character family that can be typed on Apple systems by long-pressing this key
        string = string.replacingOccurrences(of: "ř", with: "&#x159;")

        // s - character family that can be typed on Apple systems by long-pressing this key
        string = string.replacingOccurrences(of: "ß", with: "&#xDF;")
        string = string.replacingOccurrences(of: "ś", with: "&#x15B;")
        string = string.replacingOccurrences(of: "ş", with: "&#x15F;")
        string = string.replacingOccurrences(of: "š", with: "&#x161;")
        string = string.replacingOccurrences(of: "ș", with: "&#x219;")

        // t - character family that can be typed on Apple systems by long-pressing this key
        string = string.replacingOccurrences(of: "þ", with: "&#xFE;")
        string = string.replacingOccurrences(of: "ť", with: "&#x165;")
        string = string.replacingOccurrences(of: "ț", with: "&#x21B;")

        // u - character family that can be typed on Apple systems by long-pressing this key
        string = string.replacingOccurrences(of: "ù", with: "&#xF9;")
        string = string.replacingOccurrences(of: "ú", with: "&#xFA;")
        string = string.replacingOccurrences(of: "û", with: "&#xFB;")
        string = string.replacingOccurrences(of: "ü", with: "&#xFC;")
        string = string.replacingOccurrences(of: "ũ", with: "&#x169;")
        string = string.replacingOccurrences(of: "ū", with: "&#x16B;")
        string = string.replacingOccurrences(of: "ů", with: "&#x16F;")
        string = string.replacingOccurrences(of: "ű", with: "&#x171;")
        string = string.replacingOccurrences(of: "ǔ", with: "&#x1D4;")

        // w - character family that can be typed on Apple systems by long-pressing this key
        string = string.replacingOccurrences(of: "ŵ", with: "&#x175;")

        // y - character family that can be typed on Apple systems by long-pressing this key
        string = string.replacingOccurrences(of: "ý", with: "&#xFD;")
        string = string.replacingOccurrences(of: "ÿ", with: "&#xFF;")
        string = string.replacingOccurrences(of: "ŷ", with: "&#x177;")

        return string
    }
}
