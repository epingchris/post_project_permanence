library(tidyverse)

redd = read.table("./REDD_database/IDRECCO_Ver4_2_1_Project_20230308_corr.csv",
                  colClasses = "character", fill = T, sep = ",", header = T)

#the apostrophes were creating problems, so I converted them in Excel to ___ before loading
redd = as.data.frame(sapply(redd, function(x) gsub("___", "'", x)))

#all projects with a status other than "Ongoing" are retained
redd_end = subset(redd, Status %in% "Ongoing" == F)

#function from https://stackoverflow.com/questions/52911812/check-if-url-exists-in-r
checkURLValidity = function(url_in, t = 2) {
    con = url(url_in)
    check = suppressWarnings(try(open.connection(con, open = "rt", timeout = t), silent = T)[1])
    suppressWarnings(try(close.connection(con), silent = T))
    ifelse(is.null(check), T, F)
}

urls = vector("list", nrow(redd_end))
valid_urls = vector("list", nrow(redd_end))

#extract urls from the "Information.sources" column: ChatGPT helped with the regular expression but I haven't checked if it in infallible
for (i in 1:nrow(redd_end)) {
    extracted = stringr::str_extract_all(redd_end[i, "Information.sources"], "https?://(?:[-\\w.]|(?:%[\\da-fA-F]{2}))+(/[-\\w./%?=&]*)?")
    urls[[i]] = extracted[[1]]
    if (length(urls[[i]]) > 0) {
        url_validity = sapply(urls[[i]], checkURLValidity)
        valid_urls[[i]] = urls[[i]][which(url_validity)]
    }
    cat(i, " done, no. of urls: ", length(valid_urls[[i]]), "\n")
}

#exclude urls poiting to "theredddesk.org", as the site seems to be defunct (redirecting to "https://cabinet.legalnodes.com/")
valid_urls_without_redddesk = vector("list", length(valid_urls))
for(i in 1:length(valid_urls)){
    tmp = sapply(valid_urls[[i]], function(x) ifelse(grepl("theredddesk", x, fixed = T), NA, x))
    valid_urls_without_redddesk[[i]] = tmp[!is.na(tmp)]
    names(valid_urls_without_redddesk[[i]]) = NULL
    cat(i, " done, no. of urls: ", length(valid_urls_without_redddesk[[i]]), "\n")
}

#create long format
df_valid_urls = data.frame(rows = rep(seq_along(valid_urls_without_redddesk), lengths(valid_urls_without_redddesk)),
                           url = unlist(valid_urls_without_redddesk))
df_valid_urls$Project.ID = redd_end[df_valid_urls$rows, "Project.ID"]
write.table(df_valid_urls, "./df_valid_urls.csv", quote = F, sep = ",")

redd_end_with_urls = merge(redd_end[, -c(10, 23:25)], df_valid_urls, by = "Project.ID", all.y = T)

write.table(redd_end_with_urls, "./redd_end_with_urls.txt", quote = F, sep = "\t")
write.table(redd_end_with_urls, "./redd_end_with_urls.csv", quote = T, sep = ",")
redd_end_with_urls = read.table("./redd_end_with_urls.csv", sep = ",", header = T)

