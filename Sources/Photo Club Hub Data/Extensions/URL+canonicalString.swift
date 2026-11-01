//
//  URL+canonicalString.swift
//  Photo Club Hub Data
//
//  Created by Claude Code (guided by Peter van den Hamer) on 01/11/2026.
//

import Foundation   // for URL
import WebURL       // for standard URL normalization

extension URL {

    // Problem: the same website is often written in different ways in different files, for example
    // "https://www.fgFooBar.com/" in the list of bad websites and "http://fgfoobar.com" in a club's own file.
    // Comparing those URLs directly would conclude they are different, and a bad website would slip back in.
    // So the purpose is that `url1.canonicalString == url2.canonicalString` authoritively
    // determines whether two URLs point to the same website.
    //
    // Two steps:
    // 1. WebURL (which follows the WHATWG URL Standard that modern browsers use) does the standard normalization:
    //    - capitalization of the domain (but not of the path)
    //    - default ports
    //    - use of "." and ".." in the path
    //    - special characters using percent-encoding
    // 2. Our own additional rules for club websites. The following are ignored:
    //    - the scheme "http://" or "https://", or no scheme at all
    //    - a leading "www."
    //    - the fragment ("#top")
    //    - trailing "/" characters
    // So "https://www.fgFooBar.com/", "http://fgfoobar.com" and "www.fgFooBar.com" all give "fgfoobar.com".
    // Different paths stay different: "fgfoobar.com/members" is not the same page as "fgfoobar.com".
    var canonicalString: String {
        let text: String = self.absoluteString

        // step 1
        // WebURL needs a scheme, and URLs in our JSON files often don't have one. So prepend "https://" if needed.
        guard var webURL = WebURL(text.contains("://") ? text : "https://" + text) else {
            // WebURL rejects what the WHATWG standard cannot parse, for example "https://club.nl:99999".
            // Fall back to a crude version of the rules below, so that identical typos still compare as equal.
            ifDebugFatalError("The WebURL package cannot parse \"\(text)\" as a URL")
            var fallback: String = text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            while fallback.hasSuffix("/") { fallback.removeLast() }
            return fallback
        }

        // step 2
        webURL.fragment = nil
        var canonical: String = webURL.serialized()
        canonical.removeFirst("\(webURL.scheme)://".count)
        if canonical.hasPrefix("www.") { canonical.removeFirst("www.".count) } // WebURL has lowercased the domain
        while canonical.hasSuffix("/") { canonical.removeLast() }
        return canonical
    }

}
