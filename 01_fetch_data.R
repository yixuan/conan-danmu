library(jsonlite)
library(tibble)
library(curl)

episodes = read_json("ep_list.json")
info = lapply(episodes, function(ep) {
    tibble(
        episode = as.integer(ep$title),
        title   = paste(ep$titleFormat, ep$longTitle, sep = "-"),
        bv      = ep$bvid,
        ev      = ep$id,
        cid     = ep$cid
    )
})
info = do.call(rbind, info)


api = "http://api.bilibili.com/x/v1/dm/list.so?oid=%s"
requests = sprintf(api, info$cid)
i = 1
returns = lapply(requests, function(url) {
    print(i)
    i <<- i + 1
    ret = curl_fetch_memory(url)
    Sys.sleep(0.1)  # IP may be banned if requests are too intense
    ret
})

save(info, returns, file = "raw_data.RData")
