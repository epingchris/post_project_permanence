#!/bin/bash

conda activate gdal_env
gdalwarp -of Gtiff -co COMPRESS=LZW -co TILED=YES -ot Byte -te -180.0000000 -90.0000000 180.0000000 90.0000000 -tr 0.002777777777778 0.002777777777778 -t_srs EPSG:4326 NETCDF:ESACCI-LC-L4-LCCS-Map-300m-P1Y-1992-v2.0.7cds.nc:lccs_class lc1992.tif
gdalwarp -s_srs "EPSG:4326" -t_srs "EPSG:3857" lc1992.tif lc1992_3857.tif