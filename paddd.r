library(terra)
library(netcdf)
#load PADDD Events dataset
paddd_whole = read.csv("PADDDEvents.csv", header = T) #4962

polyg = terra::vect("./PADDD_Shapefiles/PADDDtracker_DataReleaseV2_1_2021_Poly.shp")

# find centroid of polygons
centr = terra::centroids(polyg)
centr_df = as.data.frame(terra::geom(centr))

#filter out events outside of the tropics
centr_trop = subset(centr_df, y <= 2613000 & y >= -2613000) #distance between equator and tropics in meter; 894

#select and save events with polygon and location, after 1990 (JRC-TMF data available), are terrestrial, and tropical
paddd_trop = subset(paddd_whole, GeoDataTyp == "Polygon" & Location_K == "Y" & YearPADDD >= 1990 & Marine == 0 &
                   PADDD_ID %in% centr[centr_trop$geom, ]$PADDD_ID) #792
write.table(paddd_trop, "paddd_tropical.csv", sep = ",", row.names = F)

polyg_trop = polyg[polyg$PADDD_ID %in% paddd_trop$PADDD_ID] 
terra::writeVector(polyg_trop, "paddd_tropical.shp", overwrite = T)

#load ESA CCI LC dataset and create vegetation mask
lc = terra::rast("lc1992_3857.tif")

a = Sys.time()
lc_vegetation = lc %in% c(30, 40, 50, 60, 70, 80, 90, 100, 110)
b = Sys.time()
b - a

terra::writeRaster(lc_vegetation, "lc_vegetation1992.tif", overwrite = T)

#calculate proportion of project area that is vegetation land cover in 1992
area_vegetation = terra::extract(lc_vegetation, polyg_trop, fun = sum)
area_tot = terra::extract(lc_vegetation, polyg_trop, fun = length)

area_df = merge(area_vegetation, area_tot, by = "ID", all = T)
colnames(area_df) = c("ID", "area_vegetation", "area_tot")
area_df$proportion = area_df$area_vegetation / area_df$area_tot

#select and save events with projects having forest land cover as of 1992 (using ESA CCI LC dataset)
polyg_sel = polyg_trop[polyg_trop$OBJECTID %in% subset(area_df, proportion >= 0.5)$ID] #113
terra::writeVector(polyg_sel, "paddd_selected.shp", overwrite = T)

paddd_sel = subset(paddd_trop, PADDD_ID %in% polyg_sel$PADDD_ID) #113
write.table(paddd_sel, "paddd_selected.csv", sep = ",", row.names = F)
