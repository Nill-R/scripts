#!/usr/bin/env python3

import sys
import os
import requests
import gzip
import ipaddress
from datetime import datetime
from pathlib import Path
import argparse

CACHE_DIR = Path.home() / "tmp" / "inetnum"

RIR_DATABASES = {
    'ripe': {
        'url': "https://ftp.ripe.net/ripe/dbase/split/ripe.db.inetnum.gz",
        'file': "ripe.db.inetnum.gz"
    },
    'arin': {
        'url': "https://ftp.arin.net/pub/rr/arin.db.gz",
        'file': "arin.db.gz"
    }
}

def ensure_cache_dir():
    CACHE_DIR.mkdir(parents=True, exist_ok=True)

def download_if_needed(rir):
    ensure_cache_dir()
    cache_file = CACHE_DIR / RIR_DATABASES[rir]['file']
    url = RIR_DATABASES[rir]['url']
    
    if cache_file.exists():
        print(f"Checking if local file {cache_file} is up to date...")
        head = requests.head(url)
        remote_size = int(head.headers.get('Content-Length', 0))
        remote_modified = head.headers.get('Last-Modified')
        
        if remote_modified:
            remote_modified = datetime.strptime(remote_modified, "%a, %d %b %Y %H:%M:%S GMT")
            local_modified = datetime.fromtimestamp(cache_file.stat().st_mtime)
            
            if remote_size == cache_file.stat().st_size and remote_modified <= local_modified:
                print("Local file is up to date. Using cached version.")
                return
    
    print(f"Downloading fresh copy from {url}...")
    response = requests.get(url, stream=True)
    if response.status_code == 200:
        with open(cache_file, 'wb') as f:
            for chunk in response.iter_content(chunk_size=8192):
                f.write(chunk)
        print("Download complete.")
    else:
        raise Exception(f"Failed to download file: HTTP {response.status_code}")

def process_file(rir, search_term):
    search_term_lower = search_term.lower()
    current_range = None
    matching_ranges = []
    cache_file = CACHE_DIR / RIR_DATABASES[rir]['file']

    with gzip.open(cache_file, 'rt', encoding='latin-1') as f:
        for line in f:
            line = line.strip()
            if line.startswith(('inetnum:', 'NetRange:')):
                parts = line.split(':')
                if len(parts) > 1:
                    range_str = parts[1].strip()
                    if '-' in range_str:
                        start, end = range_str.split('-')
                    else:
                        start, end = range_str.split()
                    current_range = (start.strip(), end.strip())
            elif line.startswith(('mnt-by:', 'OrgName:')) and current_range:
                org = line.split(':', 1)[1].strip()
                if search_term_lower in org.lower():
                    matching_ranges.append((current_range, org))
                current_range = None
            
            if len(matching_ranges) >= 1000:
                for range_info in matching_ranges:
                    yield range_info
                matching_ranges = []
    
    for range_info in matching_ranges:
        yield range_info

def main(rir, search_term):
    download_if_needed(rir)
    
    print(f"Parsing {rir.upper()} file and searching for '{search_term}'...", file=sys.stderr)
    
    count = 0
    for (start, end), org in process_file(rir, search_term):
        count += 1
        try:
            cidrs = ipaddress.summarize_address_range(ipaddress.IPv4Address(start), ipaddress.IPv4Address(end))
            for cidr in cidrs:
                print(f"{cidr}")
        except ValueError as e:
            print(f"Error processing range {start} - {end}: {e}", file=sys.stderr)
    
    print(f"Found {count} matching ranges in {rir.upper()} database.", file=sys.stderr)

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Search for network ranges in RIR databases.")
    parser.add_argument('rir', choices=['ripe', 'arin'], help="RIR database to search (ripe or arin)")
    parser.add_argument('search_term', help="Term to search for in the database")
    args = parser.parse_args()

    main(args.rir, args.search_term)
