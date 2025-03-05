#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-2.0-or-later OR MIT

import sys
import os
import requests
import gzip
import ipaddress
from datetime import datetime
from pathlib import Path
import argparse
import concurrent.futures

CACHE_DIR = Path.home() / "tmp" / "inetnum"

RIR_DATABASES = {
    'ripe': {
        'url': "https://ftp.ripe.net/ripe/dbase/split/ripe.db.inetnum.gz",
        'file': "ripe.db.inetnum.gz"
    },
    'arin': {
        'url': "https://ftp.arin.net/pub/rr/arin.db.gz",
        'file': "arin.db.gz"
    },
    'apnic': {
        'url': "https://ftp.apnic.net/apnic/whois/apnic.db.inetnum.gz",
        'file': "apnic.db.inetnum.gz"
    },
    'lacnic': {
        'url': "https://ftp.lacnic.net/lacnic/dbase/lacnic.db.gz",
        'file': "lacnic.db.gz"
    },
    'afrinic': {
        'url': "https://ftp.afrinic.net/pub/dbase/afrinic.db.gz",
        'file': "afrinic.db.gz"
    }
}

def ensure_cache_dir():
    CACHE_DIR.mkdir(parents=True, exist_ok=True)

def download_if_needed(rir):
    ensure_cache_dir()
    cache_file = CACHE_DIR / RIR_DATABASES[rir]['file']
    url = RIR_DATABASES[rir]['url']

    if cache_file.exists():
        print(f"Checking if local file {cache_file} is up to date...", file=sys.stderr)
        try:
            head = requests.head(url)
            remote_size = int(head.headers.get('Content-Length', 0))
            remote_modified = head.headers.get('Last-Modified')

            if remote_modified:
                remote_modified = datetime.strptime(remote_modified, "%a, %d %b %Y %H:%M:%S GMT")
                local_modified = datetime.fromtimestamp(cache_file.stat().st_mtime)

                if remote_size == cache_file.stat().st_size and remote_modified <= local_modified:
                    print(f"Local file for {rir} is up to date. Using cached version.", file=sys.stderr)
                    return
        except requests.RequestException as e:
            print(f"Error checking remote file: {e}", file=sys.stderr)
            print("Using cached version.", file=sys.stderr)
            return

    print(f"Downloading fresh copy from {url}...", file=sys.stderr)
    try:
        response = requests.get(url, stream=True)
        response.raise_for_status()
        with open(cache_file, 'wb') as f:
            for chunk in response.iter_content(chunk_size=8192):
                f.write(chunk)
        print(f"Download complete for {rir}.", file=sys.stderr)
    except requests.RequestException as e:
        raise Exception(f"Failed to download file for {rir}: {e}")

def process_file(rir, search_term):
    search_term_lower = search_term.lower()
    current_range = None
    matching_ranges = []
    cache_file = CACHE_DIR / RIR_DATABASES[rir]['file']

    with gzip.open(cache_file, 'rt', encoding='latin-1') as f:
        for line in f:
            line = line.strip()
            if line.startswith(('inetnum:', 'NetRange:', 'inet6num:')):
                parts = line.split(':')
                if len(parts) > 1:
                    range_str = parts[1].strip()
                    if '-' in range_str:
                        start, end = range_str.split('-')
                    else:
                        start, end = range_str.split()
                    current_range = (start.strip(), end.strip())

            elif ((rir == 'ripe' and line.startswith('mnt-by:')) or
                  (rir == 'arin' and line.startswith(('OrgName:', 'owner:'))) or
                  (rir == 'apnic' and line.startswith(('mnt-by:', 'descr:'))) or
                  (rir == 'lacnic' and line.startswith(('owner:', 'descr:'))) or
                  (rir == 'afrinic' and line.startswith('mnt-by:'))) and current_range:

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

def search_rir(rir, search_term):
    try:
        download_if_needed(rir)

        print(f"Parsing {rir.upper()} file and searching for '{search_term}'...", file=sys.stderr)

        count = 0
        for (start, end), org in process_file(rir, search_term):
            count += 1
            try:
                if ':' in start:  # IPv6
                    cidrs = [ipaddress.IPv6Network(f"{start}/{ipaddress.IPv6Address(end)._prefix_from_prefix_string()}")]
                else:  # IPv4
                    cidrs = ipaddress.summarize_address_range(ipaddress.IPv4Address(start), ipaddress.IPv4Address(end))
                for cidr in cidrs:
                    print(f"{rir.upper()}: {cidr}")
            except ValueError as e:
                print(f"Error processing range {start} - {end} in {rir.upper()}: {e}", file=sys.stderr)

        print(f"Found {count} matching ranges in {rir.upper()} database.", file=sys.stderr)
        return count
    except Exception as e:
        print(f"Error processing {rir.upper()}: {e}", file=sys.stderr)
        return 0

def main(rir, search_term):
    if rir == 'all':
        total_count = 0
        with concurrent.futures.ThreadPoolExecutor(max_workers=5) as executor:
            future_to_rir = {executor.submit(search_rir, r, search_term): r for r in RIR_DATABASES.keys()}
            for future in concurrent.futures.as_completed(future_to_rir):
                rir = future_to_rir[future]
                try:
                    count = future.result()
                    total_count += count
                except Exception as exc:
                    print(f"{rir} generated an exception: {exc}", file=sys.stderr)
        print(f"Total matching ranges across all RIRs: {total_count}", file=sys.stderr)
    else:
        search_rir(rir, search_term)

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Search for network ranges in RIR databases.")
    parser.add_argument('rir', choices=['ripe', 'arin', 'apnic', 'lacnic', 'afrinic', 'all'], help="RIR database to search or 'all' for all databases")
    parser.add_argument('search_term', help="Term to search for in the database")
    args = parser.parse_args()

    main(args.rir, args.search_term)
