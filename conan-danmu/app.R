## app.R ##

library(shiny)
library(shinydashboard)    # http://rstudio.github.io/shinydashboard/index.html
library(dplyr)
library(jsonlite)

# Some examples of interactive visualization -- not related to this App
# https://bioconnector.github.io/workshops/r-interactive-viz.html

load("danmu_data.RData")
info_sort = info %>% arrange(desc(num_danmu), episode)



ui = dashboardPage(
    dashboardHeader(
        title = "《名侦探柯南》B站弹幕浏览器",
        titleWidth = "320px"
    ),

    dashboardSidebar(
        sidebarMenu(
            menuItem("查看弹幕", tabName = "sort_danmu", icon = icon("stream")),
            menuItem("更新弹幕", tabName = "sync_danmu", icon = icon("sync-alt")),
            menuItem("项目GitHub", href = "https://github.com/yixuan/conan-danmu", icon = icon("github"))
        ),
        width = "160px"
    ),

    dashboardBody(
        tags$head(
            tags$script(src = "https://cdn.jsdelivr.net/npm/vega@5.11.1"),
            tags$script(src = "https://cdn.jsdelivr.net/npm/vega-lite@4.12.0"),
            tags$script(src = "https://cdn.jsdelivr.net/npm/vega-embed@6.7.1"),
            tags$link(rel = "stylesheet", type = "text/css", href = "custom.css")
        ),
        tabItems(
            tabItem(tabName = "sort_danmu",
                fluidRow(
                    column(width = 8, offset = 2,
                        # https://stackoverflow.com/q/36709441
                        div(style = "display:inline-block;vertical-align:middle;width: 50px;",
                            div(style = "margin-bottom:15px", strong("翻页"))
                        ),
                        div(style = "display:inline-block;vertical-align:middle;width: 90%;",
                            sliderInput(
                                "pager", label = NULL, min = 1, max = ceiling(nrow(info) / 6),
                                value = 1, step = 1, width = "100%"
                            )
                        )
                    ),
                    column(width = 2,
                           selectInput(
                               "sort", label = span(icon("sort-amount-down"), strong("排序")), 
                               choices = c("按热度排序", "按集数排序"), width = "100%"
                           )
                    )
                ),
                fluidRow(
                    # https://stackoverflow.com/a/35559719
                    column(width = 6,
                        uiOutput("box1")
                    ),
                    column(width = 6,
                        uiOutput("box2")
                    )
                ),
                fluidRow(
                    column(width = 6,
                        uiOutput("box3")
                    ),
                    column(width = 6,
                        uiOutput("box4")
                    )
                ),
                fluidRow(
                    column(width = 6,
                        uiOutput("box5")
                    ),
                    column(width = 6,
                        uiOutput("box6")
                    )
                )
            ),

            tabItem(tabName = "sync_danmu",
                h2("待完成")
            )
        )
    )
)

# Generate plot titles
get_title = function(info, entry)
{
    main = function(title, href)
        h3(a(title, href = href, target="_blank"), class = "box-title")
    sub = function(...)
        h3(..., class = "box-title", style = "float: right;")
    if(entry > nrow(info))
        return(list(main = main("", NULL), sub = sub("")))

    title = info$title[entry]
    href = sprintf("https://www.bilibili.com/bangumi/play/ep%s", info$ev[entry])
    num_danmu = info$num_danmu[entry]
    list(main = main(title, href), sub = sub(icon("stream"), "×", num_danmu))
}
# Render the boxes for plots
render_box = function(plotbox, info, entry)
{
    titles = get_title(info, entry)
    div(class = "box box-solid box-primary", style = "height: 200px;",
        div(class = "box-header",
            titles$main, titles$sub
        ),
        div(class = "box-body",
            htmlOutput(plotbox, style = "height: 165px;")
        )
    )
}
# Merge multiple danmu
merge_danmu = function(danmu, max_danmu = 30)
{
    paste(head(danmu, max_danmu), collapse = "<br/>")
}
# Render the plots
render_plot = function(info, entry)
{
    if(entry > nrow(info))
        return(NULL)
    # Episode ID
    e = info$epid[entry]
    # Danmu for this episode
    dat = danmu_data[[e]]
    # Show danmu within this time window
    window = 20
    half = window / 2
    x1 = seq(0, max(dat$video_time), by = window)
    x2 = x1 + window
    n = length(x1)
    # Kernel density estimation
    den = density(dat$video_time, bw = half, from = x1[1] + half, to = x1[n] + half, n = n)
    # Divide video time into bins
    dat = dat %>% mutate(bin = cut(dat$video_time, c(x1, Inf), include.lowest = TRUE))
    # Aggregate danmu within each bin
    max_danmu = 30
    gdat = dat %>% group_by(bin) %>% arrange(video_time) %>%
        summarize(danmus = merge_danmu(danmu, max_danmu))
    # Some bins may not contain data
    ind = as.integer(gdat$bin)
    gdat = gdat %>% select(-bin) %>%
        mutate(x1 = x1[ind], x2 = x2[ind], y = den$y[ind])

    # Shortcuts
    u = jsonlite::unbox
    false = u(FALSE)
    true = u(TRUE)
    # Vega specification
    spec = list(
        `$schema` = u("https://vega.github.io/schema/vega-lite/v4.json"),
        width     = u("container"),
        height    = u("container"),
        autosize  = list(type = u("fit"), contains = u("padding")),
        # https://stackoverflow.com/a/47364520
        config    = list(style = list(cell = list(stroke = u("transparent")))),
        data      = list(values = gdat),
        mark      = list(type = u("bar"), stroke = u("#FFFFFF"), strokeWidth = u(0), opacity = u(0.7)),
        encoding  = list(
            x  = list(field = u("x1"), type = u("quantitative"), bin = u("binned"),
                      axis = list(title = u("播放时间 (s)"), ticks = false)),
            x2 = list(field = u("x2")),
            y  = list(field = u("y"), type = u("quantitative"),
                      axis = list(title = NULL, ticks = false, grid = false,
                                  labels = false, domain = false)),
            tooltip = list(field = u("danmus"))
        )
    )

    script = "
    <div id='plot-%s' style='width: 100%%; height: 100%%;'></div>
    <script>
      // Assign the specification to a local variable vlSpec.
      var vlSpec = %s;
      // Options for Vega
      var opt = {
        tooltip: {sanitize: (value) => String(value)}
      };
      // Embed the visualization in the container
      vegaEmbed('#plot-%s', vlSpec, opt);
    </script>
    "
    HTML(sprintf(script, e, toJSON(spec, null = "null"), e, e, e))
}

server = function(input, output)
{
    plot_id = 1:6
    plot_var = sprintf("plot%d", plot_id)
    box_var = sprintf("box%d", plot_id)

    for(i in plot_id)
    {
        box_expr = substitute({
            entry = (input$pager - 1) * 6 + i
            meta = if(input$sort == "按热度排序") info_sort else info
            render_box(plot_var[i], meta, entry)
        }, list(i = i))
        output[[box_var[i]]] = renderUI(box_expr, quote = TRUE)

        plot_expr = substitute({
            entry = (input$pager - 1) * 6 + i
            meta = if(input$sort == "按热度排序") info_sort else info
            render_plot(meta, entry)
        }, list(i = i))
        output[[plot_var[i]]] = renderUI(plot_expr, quote = TRUE)
    }
}

shinyApp(ui, server)
