import csv
import requests
from bs4 import BeautifulSoup
import wget
import os
import re
from urllib.parse import urlparse

# List of project IDs from REDD Project Database stored in a CSV file
csv_file = 'redd_end.csv'

# Destination folder to save shapefiles
destination_folder = 'redd_vcssearch_out/'

# Create a CSV file to store project summaries
project_summary_file = open('project_summary.csv', 'w', newline = '')
project_summary_writer = csv.writer(project_summary_file)
project_summary_writer.writerow(['Project ID', 'VCS ID', 'Summary'])

# Function to save Verra VCS registry page
def save_verra_page(html_content, project_id, vcs_id):
    if not os.path.exists(f'{destination_folder}/verra_pages'):
        os.makedirs(f'{destination_folder}/verra_pages')
        
    filename = f'{destination_folder}/verra_pages/{project_id}_{vcs_id}.html'
    with open(filename, 'w', encoding='utf-8') as file:
        file.write(html_content)
    print(f"Saved Verra VCS registry page for Project # {project_id} (VCS ID: {vcs_id}).")

# Function to download shapefile
def download_shapefile(url, project_id, vcs_id, obj_num, type):
    if not os.path.exists(f'{destination_folder}/shapefiles'):
        os.makedirs(f'{destination_folder}/shapefiles')

    filename = f'{destination_folder}/shapefiles/{project_id}_{vcs_id}_{obj_num}.{type}'
    wget.download(url, filename)
    print(f"Downloaded shapefile for Project # {project_id} (VCS ID: {vcs_id}).")

# Read the project IDs from the CSV file
with open(csv_file, 'r', encoding = 'utf-8', errors = 'ignore') as file:
    project_ids = csv.DictReader(file)
    num_rows_to_skip = 0 # number of rows to skip
    
    # Skip desired number of rows
    for _ in range(num_rows_to_skip):
        next(project_ids)

    # Iterate over each project ID
    for row in project_ids:
        project_id = row['Project.ID']  # Extract project ID from list
        #project_id = '377' #testing on one project
        print(f'Project ID: {project_id}')
        
        # Access the project page
        url_project = 'https://www.reddprojectsdatabase.org/view/project.php?id=' + project_id
        response = requests.get(url_project)
        soup = BeautifulSoup(response.text, 'html.parser')

        # Find the table with forest carbon certification
        certification_table = soup.find('strong', string = 'Forest carbon certification:').find_next('table')
        rows = certification_table.find_all('tr')

        # Iterate over rows in the certification table to find the row and column containing VCS Standard
        col_to_look = None
        row_to_look = None
        for row_idx, row_item in enumerate(rows):
            cols = row_item.find_all('td')
            for col_idx, col_item in enumerate(cols):
                cell_text = col_item.text
                if 'VCS' in cell_text:
                    print(f'There is VCS')
                    col_to_look = col_idx
                    row_to_look = row_idx
                    break
        
        # Iterate in the content column over rows starting from the standard name row, look for the first url
        url = None  # Initialize VCS url to None
        vcs_id = None  # Initialize VCS ID to None
        file_name = None  # Initialize filename to None
        if col_to_look:
            for row_idx, row_item in enumerate(rows[row_to_look:len(rows)]):
                col_text = row_item.find_all('td')[col_to_look].text
                match = re.search(r'#(.*)#', col_text)  # Use regex to find URLs between "#" symbols
                if match:
                    url = match.group(1)  # Extract URL from regex match
                    print(f'Found: {url}')
                    if 'www.vcsprojectdatabase.org/#/project_details/' in url or 'registry.verra.org/app/projectDetail/' in url:
                        vcs_id = url.split('/')[-1]  # Extract VCS ID from URL
                        break
                    elif '.asp?' in url:
                        # Send HTTP request to the ASP dynamic page
                        try:
                            response = requests.get(url)
                            
                            # Check if response is successful (status code 200)
                            if response.status_code == 200:
                                # Extract filename from response or file location URL
                                file_name = response.headers.get('Content-Disposition').split('filename=')[1]
                                match = re.search(r'(?<=VALID_REP_)\d+(?=_)', file_name)
                                if match:
                                    vcs_id = match.group(0)
                                    file_name = None
                                    break
                        except requests.exceptions.ConnectionError as e:
                            print(f'Error connecting to URL')
                            code = response.status_code
                            pass

        # Check if VCS ID was found
        if url is None:
            print(f'Status: no URL found')
        elif file_name:
            print(f'Status: link to individual file, project ID surely in {file_name}')
        elif vcs_id is None:
            print(f'Status: VCS ID not found or format different (Project ID: {project_id}, URL: {url}, )')
        elif vcs_id:
            print(f'Status: VCS ID is {vcs_id}')
            
            # Access the VCS Registry page
            url_vcs_new = 'https://registry.verra.org/app/projectDetail/VCS/' + vcs_id
            vcs_response = requests.get(url_vcs_new)
            vcs_soup = BeautifulSoup(vcs_response.text, 'html.parser')

            # Save the VCS registry page
            save_verra_page(vcs_response.text, project_id, vcs_id)

            # Construct the URL for the JSON file
            json_url = 'https://registry.verra.org/uiapi/resource/resourceSummary/' + vcs_id

            # Fetch the JSON file
            response = requests.get(json_url)
            json_data = response.json()

            # Extract URIs for KML and SHP files
            obj_num = 1
            for documentGroup in json_data['documentGroups']:
                for document in documentGroup['documents']:
                    if 'documentType' in document and document['documentType'] == 'KML File':
                        uri = document['uri']
                        # Process KML URI as needed
                        print(f'KML URI: {uri}')
                        download_shapefile(uri, project_id, vcs_id, obj_num, 'kml')
                        obj_num += 1
                    elif 'documentType' in document and document['documentType'] == 'SHP File':
                        uri = document['uri']
                        # Process SHP URI as needed
                        print(f'SHP URI: {uri}')
                        download_shapefile(uri, project_id, vcs_id, obj_num, 'shp')
                        obj_num += 1
            if obj_num == 1:
                print('No shapefile downloaded.')

        #break #testing on one project

print('Extraction complete!')
