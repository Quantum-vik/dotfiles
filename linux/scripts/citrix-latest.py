#!/usr/bin/env python3
"""Print '<download-url> <sha256>' for the latest Citrix Workspace app .deb.

Reads the Citrix download page (path given as argv[1]). Citrix has no apt repo,
and its download links carry a short-lived token, so they must be scraped. The
SHA-256 Citrix publishes is printed just before each file's download link.
Prints '- -' if either value can't be found.
"""
import html, re, sys

s = html.unescape(open(sys.argv[1], errors="ignore").read())
link = re.search(r'rel="(//downloads\.citrix\.com/[^"]*icaclient-gcc-8_[0-9.]+_amd64\.deb\?[^"]+)"', s)
anchor = s.find('filepathOrUrl: "//downloads.citrix.com/')
while anchor != -1 and "icaclient-gcc-8_" not in s[anchor:anchor + 120]:
    anchor = s.find('filepathOrUrl: "//downloads.citrix.com/', anchor + 1)
sha = re.findall(r"SHA-256 - ([0-9a-fA-F]{64})", s[max(0, anchor - 2000):anchor]) if anchor != -1 else []
print(("https:" + link.group(1)) if link else "-", sha[-1].lower() if sha else "-")
