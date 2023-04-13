import os
import re
import csv
import requests
import mimetypes
from bs4 import BeautifulSoup
import pandas as pd

def download_file(url, destination_folder, initial):
    local_filename = url.split('/')[-1]
    local_filename = re.sub(r'[^\w\d_\.]+', '_', local_filename) #cleanup special characters in downloaded file name
    local_file_path = os.path.join(destination_folder, f'{initial}_{local_filename}') #add row number as prefix in downloaded file name

    try:
        response = requests.get(url, stream = True)
    except requests.exceptions.RequestException:
        print("URL not accessible") #skip when error is raised
    else:
        with open(local_file_path, 'wb') as f:
            for chunk in response.iter_content(chunk_size=8192):
                f.write(chunk)


    return local_file_path

def find_files(url, file_types):
    response = requests.get(url)

    #find the right parser based on content type
    content_type = response.headers.get('Content-Type')
    if content_type is not None:
        if 'text/html' in content_type:
            parser = 'html.parser'
        elif 'application/xml' in content_type or 'text/xml' in content_type or 'application/pdf' in content_type:
            parser = 'lxml'
    else:
        # If the server did not provide a Content-Type header, use the file extension to guess the MIME type
        extension = url.split('.')[-1]
        mime_type = mimetypes.types_map.get('.' + extension, None)
        if mime_type == 'text/html':
            parser = 'html.parser'
        elif mime_type == 'application/xml' or mime_type == 'text/xml' or mime_type == 'application/pdf':
            parser = 'lxml'
        else:
            raise ValueError('Unknown file type')

    encoding = 'ISO-8859-1' #set default encoding; 'utf-8' will result in error in some cases
    soup = BeautifulSoup(response.content.decode(encoding), parser)
    files = []

    for link in soup.find_all('a', href=True):
        for file_type in file_types:
            if link['href'].lower().endswith(file_type.lower()):
                files.append(link['href'])

    return files

def process_csv(csv_file, url_column, start_row, destination_folder):
    data_frame = pd.read_csv(csv_file)
    os.makedirs(destination_folder, exist_ok = True)

    #iterate over rows starting at designated row so that it is not necessary to restart from beginning when debugging
    for index, row in data_frame[start_row - 1:].iterrows():
        url = row[url_column]
        print(f'Reading row {index}')
        shapefiles = find_files(url, ['.kml', '.shp'])
        print(f'Finished finding shapefiles')
        project_docs = find_files(url, ['.pdf'])
        print(f'Finished finding project docs')

        for shapefile in shapefiles:
            print(f'Downloading shapefile: {shapefile}')
            download_file(shapefile, destination_folder, index)

        for project_doc in project_docs:
            print(f'Downloading project document: {project_doc}')
            download_file(project_doc, destination_folder, index)

if __name__ == '__main__':
    csv_file = 'redd_end_with_urls.csv'
    url_column = 'url'
    destination_folder = 'redd_webscraping_out'
    start_row = 1

    process_csv(csv_file, url_column, start_row, destination_folder)