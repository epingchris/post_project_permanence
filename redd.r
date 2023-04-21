library(tidyverse)

redd = read.table("./REDD_database/IDRECCO_Ver4_2_1_Project_20230308_corr.csv",
                  colClasses = "character", fill = T, sep = ",", header = T)

#the apostrophes were creating problems, so I converted them in Excel to ___ before loading
redd = as.data.frame(sapply(redd, function(x) gsub("___", "'", x)))

#all projects containing a REDD component, in humid forest, with a status "Abandoned", "Ended", "Terminated ahead of schedule"
redd_end = subset(redd, Status %in% c("Abandoned", "Ended", "Terminated ahead of schedule") &
                        grepl("humid", Type.of.forest, fixed = T) & 
                        grepl("REDD", Project.Type, fixed = T))
write.table(redd_end, "./redd_end.csv", quote = T, sep = ",", row.names = F)
