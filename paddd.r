library(terra)
library(stringr)
#load PADDD Events dataset
paddd_whole = read.csv("PADDDEvents.csv", header = T) #4962
paddd_whole = cbind(paddd_whole[, 1:25], Marine = paddd_whole$Marine)

polyg = terra::vect("./PADDD_Shapefiles/PADDDtracker_DataReleaseV2_1_2021_Poly.shp")
polyg$PADDD_ID = stringr::str_replace_all(polyg$PADDD_ID, "\r\n", "")

# find the centroid of polygons
centr = terra::centroids(polyg)
centr_df = as.data.frame(terra::geom(centr))
centr_df$PADDD_ID = centr$PADDD_ID
centr_df$OBJECTID = centr$OBJECTID

#filter out events outside of the tropics
centr_trop = subset(centr_df, y <= 2613000 & y >= -2613000) #distance between equator and tropics in meter; 894

#select and save degazettement events with polygon and location info,
#are terrestrial and tropical,
#and having enacted PADDD event after 1990 (where JRC-TMF data are available)
paddd_trop = subset(paddd_whole, GeoDataTyp == "Polygon" & Location_K == "Y" & 
                    Marine == 0 & PADDD_ID %in% centr_trop$PADDD_ID &
                    YearPADDD >= 1990 & EnactedPro == "Enacted" & EventType == "Degazette") #60
write.table(paddd_trop, "paddd_tropical.csv", sep = ",", row.names = F)

polyg_trop = polyg[polyg$PADDD_ID %in% paddd_trop$PADDD_ID] 
terra::writeVector(polyg_trop, "paddd_tropical.shp", overwrite = T)

#load ESA CCI LC dataset and create vegetation/forest mask
lc = terra::rast("lc1992_3857.tif")

a = Sys.time()
lc_vegetation = lc %in% c(30, 40, 50, 60, 70, 80, 90, 100, 110)
b = Sys.time()
b - a

a = Sys.time()
lc_forest = lc %in% c(50, 60, 70, 80, 90)
b = Sys.time()
b - a

terra::writeRaster(lc_vegetation, "lc1992_vegetation.tif", overwrite = T)
terra::writeRaster(lc_forest, "lc1992_forest.tif", overwrite = T)

lc_vegetation = terra::rast("lc1992_vegetation.tif")
lc_forest = terra::rast("lc1992_forest.tif")

#calculate proportion of project area that is vegetation/forest land cover in 1992
area_vegetation = terra::extract(lc_vegetation, polyg_trop, fun = sum)
area_forest = terra::extract(lc_forest, polyg_trop, fun = sum)
area_tot = terra::extract(lc_vegetation, polyg_trop, fun = length) #same if done with lc_forest

area_df = Reduce(function(df1, df2) merge(df1, df2, by = "ID", all = T), list(area_vegetation, area_forest, area_tot))
colnames(area_df) = c("ID", "area_vegetation", "area_forest", "area_tot")
area_df$prop_vegetation = area_df$area_vegetation / area_df$area_tot
area_df$prop_forest = area_df$area_forest / area_df$area_tot
area_df$PADDD_ID = polyg_trop$PADDD_ID
area_df$OBJECTID = polyg_trop$OBJECTID

#select and save events with projects having vegetation/forest land cover as of 1992 (using ESA CCI LC dataset)
polyg_veg = polyg_trop[polyg_trop$OBJECTID %in% subset(area_df, prop_vegetation >= 0.5)$OBJECTID] #51
terra::writeVector(polyg_veg, "paddd_selected_vegetation.shp", overwrite = T)

paddd_veg = subset(paddd_trop, PADDD_ID %in% polyg_veg$PADDD_ID) #51
write.table(paddd_veg, "paddd_selected_vegetation.csv", sep = ",", row.names = F)

polyg_for = polyg_trop[polyg_trop$OBJECTID %in% subset(area_df, prop_forest >= 0.5)$OBJECTID] #48
terra::writeVector(polyg_for, "paddd_selected_forest.shp", overwrite = T)

paddd_for = subset(paddd_trop, PADDD_ID %in% polyg_for$PADDD_ID) #48
write.table(paddd_for, "paddd_selected_forest.csv", sep = ",", row.names = F)

#check output
table(paddd_for$Region)
table(paddd_for$Country)
#excluding 31 in Australia, 12 in Brazil, 1 in French Guiana and 4 in Peru

polyg_veg_new = terra::vect("paddd_selected_vegetation.shp")
plot(polyg_veg_new$SHAPE_Area / (10 ^ 6), type = "h")
lines(polyg_veg_new$gis_area / (10 ^ 6), type = "h", col = "red")
lines(polyg_veg_new$Areaaffect, type = "h", col = "green")
