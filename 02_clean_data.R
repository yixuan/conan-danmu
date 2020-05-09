library(xml2)
library(tibble)
library(dplyr)

load("raw_data.RData")

i = 1
danmu_data = lapply(returns, function(ret) {
    print(i)
    i <<- i + 1
    doc = read_xml(ret$content, encoding = "UTF-8")
    nodes = xml_find_all(doc, ".//d")
    danmu = xml_text(nodes)

    attrs = xml_attr(nodes, "p")
    attrs = strsplit(attrs, ",")
    video_time = as.numeric(sapply(attrs, function(x) x[[1]]))
    send_time = as.integer(sapply(attrs, function(x) x[[5]]))
    type = as.integer(sapply(attrs, function(x) x[[2]]))
    pool_type = as.integer(sapply(attrs, function(x) x[[6]]))
    user_id = sapply(attrs, function(x) x[[7]])
    id = sapply(attrs, function(x) x[[8]])

    dat = tibble(
        danmu           = danmu,
        video_time      = video_time,
        send_time       = send_time,
        send_time_human = as.character(as.POSIXct(send_time, origin="1970-01-01")),
        type            = type,
        pool_type       = pool_type,
        user_id         = user_id,
        id              = id
    )
    dat[!duplicated(id), ]
})

num_danmu = sapply(danmu_data, nrow)
info = mutate(info, epid = sprintf("ep%d", episode), num_danmu = num_danmu)
names(danmu_data) = info$epid

save(info, danmu_data, file = "conan-danmu/danmu_data.RData")
