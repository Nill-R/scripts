import argparse
from datetime import datetime
from pathlib import Path
import os
import requests
from dateutil.parser import parse
from PIL import Image
from PIL.ExifTags import TAGS
import xml.etree.ElementTree as ET

def get_exif(filename):
    try:
        image = Image.open(filename)
        image.verify()
        return image._getexif()
    except (IOError, AttributeError):
        return None

def get_labeled_exif(exif):
    if exif is not None:
        labeled = {}
        for (key, val) in exif.items():
            if key in TAGS:
                labeled[TAGS[key]] = val
        return labeled
    else:
        return {}

def get_date_from_exif(exif):
    if exif is not None and "DateTimeOriginal" in exif:
        try:
            return parse(exif["DateTimeOriginal"]).date()
        except ValueError:
            return None
    else:
        return None

def download_image(url, directory, filename):
    response = requests.get(url)
    if response.status_code == 200:
        with open(os.path.join(directory, filename), 'wb') as file:
            file.write(response.content)
            print(f"Downloaded {filename} to {directory}")
    else:
        print(f"Failed to download {filename} from {url}")

def main():
    parser = argparse.ArgumentParser(description='RSS Image Downloader')
    parser.add_argument('rss_url', help='URL of the RSS feed')
    args = parser.parse_args()

    response = requests.get(args.rss_url)
    data = response.text

    try:
        root = ET.fromstring(data)
        image_urls = [item.attrib['url'] for item in root.findall('.//media:content', namespaces={'media': 'http://search.yahoo.com/mrss/'})]
        titles = [root.find('.//title').text[:10]]
    except ET.ParseError:
        print("Error parsing the RSS feed.")
        return

    if not image_urls:
        print("No image URLs found in the RSS feed.")
        return

    if not titles:
        print("No titles found in the RSS feed.")
        return

    print(f"Found {len(image_urls)} image URLs and {len(titles)} titles in the RSS feed.")

    for title, url in zip(titles * len(image_urls), image_urls):
        date = datetime.strptime(title, '%Y-%m-%d').strftime('%d-%m-%Y')
        directory = Path(date)
        directory.mkdir(exist_ok=True)
        filename = os.path.basename(url)
        download_image(url, directory, filename)

        # Check EXIF date
        filepath = directory / filename
        exif = get_exif(filepath)
        labeled_exif = get_labeled_exif(exif)
        exif_date = get_date_from_exif(labeled_exif)
        if exif_date and exif_date != date:
            new_filename = f"{date}_{filename}"
            os.rename(filepath, directory / new_filename)
            print(f"Updated date for {filename} from {exif_date} to {date}")

    print("All images processed.")

if __name__ == "__main__":
    main()

# Скрипт вряд ли нужен вам
# если вы его видите, то можете проходить мимо
# писался для скачивания из RSS-лент старых фоток в личный архив
#