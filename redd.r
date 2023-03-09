library(tidyverse)

redd = read.table("./REDD_database/IDRECCO_Ver4_2_1_Project_20230308_corr2.csv",
                  colClasses = "character", fill = T, sep = ",", header = T)

redd = as.data.frame(sapply(redd, function(x) gsub("___", "'", x)))

redd_end = subset(redd, Status %in% "Ongoing" == F)

checkURLValidity = function(url_in, t = 2) {
    con = url(url_in)
    check = suppressWarnings(try(open.connection(con, open = "rt", timeout = t), silent = T)[1])
    suppressWarnings(try(close.connection(con), silent = T))
    ifelse(is.null(check), T, F)
}

urls = vector("list", nrow(redd_end))
valid_urls = vector("list", nrow(redd_end))

for (i in 1:nrow(redd_end)) {
    extracted = stringr::str_extract_all(redd_end[i, "Information.sources"], "https?://(?:[-\\w.]|(?:%[\\da-fA-F]{2}))+(/[-\\w./%?=&]*)?")
    urls[[i]] = extracted[[1]]
    if (length(extracted[[1]]) > 0) {
        url_validity = sapply(urls[[1]], checkURLValidity)
        valid_urls[[i]] = extracted[[1]][which(url_validity)]
    }
    cat(i, " done\n")
}
