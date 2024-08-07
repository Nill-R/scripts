#!/usr/bin/env python3
import sys
import os
import requests
import gzip
import ipaddress
from datetime import datetime
from pathlib import Path

CACHE_DIR = Path.home() / "tmp" / "inetnum"
CACHE_FILE = CACHE_DIR / "ripe.db.inetnum.gz"
URL = "https://ftp.ripe.net/ripe/dbase/split/ripe.db.inetnum.gz"

def ensure_cache_dir():
    CACHE_DIR.mkdir(parents=True, exist_ok=True)

def download_if_needed():
    ensure_cache_dir()
    
    if CACHE_FILE.exists():
        print(f"Checking if local file {CACHE_FILE} is up to date...")
        head = requests.head(URL)
        remote_size = int(head.headers.get('Content-Length', 0))
        remote_modified = head.headers.get('Last-Modified')
        
        if remote_modified:
            remote_modified = datetime.strptime(remote_modified, "%a, %d %b %Y %H:%M:%S GMT")
            local_modified = datetime.fromtimestamp(CACHE_FILE.stat().st_mtime)
            
            if remote_size == CACHE_FILE.stat().st_size and remote_modified <= local_modified:
                print("Local file is up to date. Using cached version.")
                return
    
    print(f"Downloading fresh copy from {URL}...")
    response = requests.get(URL, stream=True)
    if response.status_code == 200:
        with open(CACHE_FILE, 'wb') as f:
            for chunk in response.iter_content(chunk_size=8192):
                f.write(chunk)
        print("Download complete.")
    else:
        raise Exception(f"Failed to download file: HTTP {response.status_code}")

def process_file(search_term):
    search_term_lower = search_term.lower()
    current_range = None
    matching_ranges = []

    with gzip.open(CACHE_FILE, 'rt', encoding='latin-1') as f:
        for line in f:
            line = line.strip()
            if line.startswith('inetnum:'):
                start, end = line.split(':')[1].strip().split('-')
                current_range = (start.strip(), end.strip())
            elif line.startswith('mnt-by:') and current_range:
                mnt_by = line.split(':')[1].strip()
                if search_term_lower in mnt_by.lower():
                    matching_ranges.append((current_range, mnt_by))
                current_range = None
            
            if len(matching_ranges) >= 1000:
                for range_info in matching_ranges:
                    yield range_info
                matching_ranges = []
    
    for range_info in matching_ranges:
        yield range_info

def main(search_term):
    download_if_needed()
    
    print(f"Parsing file and searching for '{search_term}'...")
    
    count = 0
    for (start, end), mnt_by in process_file(search_term):
        count += 1
        try:
            cidrs = ipaddress.summarize_address_range(ipaddress.IPv4Address(start), ipaddress.IPv4Address(end))
            for cidr in cidrs:
                print(f"{cidr}")
        except ValueError as e:
            print(f"Error processing range {start} - {end}: {e}", file=sys.stderr)
    
    print(f"Found {count} matching ranges.", file=sys.stderr)

if __name__ == "__main__":
    if len(sys.argv) != 2:
        print("Usage: python script.py <search_term>")
        sys.exit(1)

    main(sys.argv[1])
