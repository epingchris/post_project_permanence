library(terra)

paddd_whole = read.csv("./PADDDtracker_DataReleaseV2.1_2021/Data/PADDDEvents.csv", header = T) #4962
paddd_sel = subset(paddd_whole, GeoDataTyp == "Polygon" & Location_K == "Y" & YearPADDD >= 1990 & Marine == 0) #3273

polyg = terra::vect("./PADDDtracker_DataReleaseV2.1_2021/Data/Shapefiles/PADDDtracker_DataReleaseV2_1_2021_Poly.shp")
centr = terra::centroids(polyg)
centr_df = as.data.frame(terra::geom(centr))
centr_trop = subset(centr_df, y <= 2613000 & y >= -2613000) #distance between equator and tropics in meter; 894
paddd_trop = paddd_sel[paddd_sel$PADDD_ID %in% centr[centr_trop$geom, ]$PADDD_ID, ]
write.table(paddd_trop, "paddd_tropical.csv", sep = ",", row.names = F)
