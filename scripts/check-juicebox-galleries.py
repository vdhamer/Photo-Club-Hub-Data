#!/usr/bin/env python3
"""Check that every JuiceBox gallery referenced by a Level 2 file is well-formed XML.

A club using JuiceBox Pro publishes `config.xml` next to each member's portfolio, and the apps read
the first <image> element out of it to find that member's featured image. They do so with a regular
expression, which happily matches a document no XML parser will accept, so a gallery can look
perfectly healthy in the app and render as a blank page in a browser (Data#54).

That is not hypothetical: a Lightroom Classic release between 2026-05-26 and 2026-09-12 began
writing empty metadata values as `<div></div>`, and inside the linkURL attribute a raw '<' makes
the whole document ill-formed. Every gallery re-exported since is affected until it is repaired.

Which portfolios are JuiceBox galleries is not recorded in the JSON, and the two clubs that use it
are hardcoded in Swift. Rather than duplicate that list here, this asks the server. A 200 is not
enough on its own: Wix, Instagram and others answer any path with their own HTML, which would then
be reported as a malformed gallery. So a portfolio counts only when the body actually contains a
<juiceboxgallery> root element. That element precedes every <image>, so it survives the corruption
this check looks for, and a club adopting JuiceBox is covered without editing this script.

The opening tag rather than the bare word, so that a page merely mentioning Juicebox is not adopted
and then reported as malformed. Note the gallery's own index.html says "juicebox" four times and
"juiceboxgallery" never, so a soft 404 serving that page is skipped either way. A different plug-in
writing its own config.xml has its own root element and is likewise skipped: the file name is never
the criterion.

Usage:  check-juicebox-galleries.py <directory of *.level2.json files>
Exits non-zero if any gallery is malformed, or if no gallery was found at all.
"""
import glob
import json
import os
import re
import sys
import urllib.error
import urllib.request
import xml.etree.ElementTree as ET

TIMEOUT = 20

# A Juicebox config.xml opens with <juiceboxgallery followed by whitespace or '>'.
ROOT_ELEMENT = re.compile(r"<juiceboxgallery[\s>]")


def portfolio_urls(json_dir):
    """Every distinct level3URL in the Level 2 files, in a stable order."""
    urls = []
    for path in sorted(glob.glob(os.path.join(json_dir, "*.level2.json"))):
        with open(path, encoding="utf-8") as file:
            document = json.load(file)
        for member in document.get("members", []):
            url = (member.get("optional") or {}).get("level3URL")
            if url and url not in urls:
                urls.append(url)
    return urls


def config_url(portfolio_url):
    """The config.xml beside a portfolio, mirroring MemberPortfolio.urlOfImageIndex."""
    base = portfolio_url.split("#")[0]
    if not base.endswith("/"):
        base += "/"
    return base + "config.xml"


def fetch(url):
    """Return the body, or None when there is nothing there to check."""
    try:
        with urllib.request.urlopen(url, timeout=TIMEOUT) as response:
            if response.status != 200:
                return None
            return response.read().decode("utf-8", errors="replace")
    except (urllib.error.URLError, urllib.error.HTTPError, OSError):
        return None


def main():
    if len(sys.argv) != 2:
        sys.exit("usage: check-juicebox-galleries.py <directory of *.level2.json files>")

    json_dir = sys.argv[1]
    galleries = malformed = 0

    for portfolio in portfolio_urls(json_dir):
        url = config_url(portfolio)
        body = fetch(url)
        if body is None or not ROOT_ELEMENT.search(body):
            continue  # an ordinary web page, a soft 404, or momentarily unreachable
        galleries += 1
        try:
            ET.fromstring(body)
        except ET.ParseError as error:
            malformed += 1
            print(f"::error::{url} is not well-formed XML: {error}")

    # A wrong directory, a renamed field or a network with no egress would all make the loop find
    # nothing, and the check would pass having verified nothing. Silence is not success.
    if galleries == 0:
        print("::error::No JuiceBox galleries were found at all, so nothing was actually checked.")
        sys.exit(1)

    print(f"Checked {galleries} JuiceBox galleries; {malformed} malformed.")
    sys.exit(1 if malformed else 0)


if __name__ == "__main__":
    main()
