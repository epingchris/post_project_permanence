import scrapy

import os
import csv
import pandas as pd
import scrapy
from scrapy.http import Request

class FileDownloaderSpider(scrapy.Spider):
    name = 'file_downloader'
    allowed_domains = []

    def __init__(self, csv_file, url_column, destination_folder):
        self.csv_file = csv_file
        self.url_column = url_column
        self.destination_folder = destination_folder

    def start_requests(self):
        data_frame = pd.read_csv(self.csv_file)
        for index, row in data_frame.iterrows():
            url = row[self.url_column]
            yield Request(url, callback=self.parse, meta={'index': index})

    def parse(self, response):
        index = response.meta['index']
        file_types = ['.kml', '.shp', '.pdf']
        for file_type in file_types:
            for link in response.css(f'a[href$="{file_type}"]::attr(href)').getall():
                file_url = response.urljoin(link)
                yield Request(file_url, callback=self.download_file, meta={'index': index})

    def download_file(self, response):
        os.makedirs(self.destination_folder, exist_ok=True)
        file_name = response.url.split('/')[-1]
        index = response.meta['index']  # Get the index from response.meta

        # Add the index as a prefix to the file name
        file_name_with_prefix = f'{index}_{file_name}'
        file_path = os.path.join(self.destination_folder, file_name_with_prefix)

        with open(file_path, 'wb') as f:
            f.write(response.body)

        self.log(f'Saved file {file_name_with_prefix}')
