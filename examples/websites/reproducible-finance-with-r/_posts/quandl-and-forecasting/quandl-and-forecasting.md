---
title: 'Quandl and Forecasting'
description: |
  In this post, we will explore commodity prices using data from [Quandl](https://www.quandl.com/), a repository for both free and paid data sources. We will also get into the forecasting game a bit and think about how best to use dygraphs when visualizing predicted time series as an extension of historical data.
author: 
  - name: "Jonathan Regenstein"
    url: https://www.linkedin.com/in/jkregenstein/
    affiliation: RStudio
    affiliation_url: https://www.rstudio.com
date: 03-07-2017
output: 
  radix::radix_article:
    keep_md: true
---



## Overview

Welcome to another installment of Reproducible Finance with R. Today we are going to shift focus in recognition of the fact that there's more to Finance than stock prices, and there's more to data download than quantmod/getSymbols. We are not going to do anything too complex, but we will expand our toolkit by getting familiar with Quandl, commodity prices, the forecast() function, and some advanced dygraph work. 

Before we dive in, a few thoughts to frame the notebook underlying this post.      

*   We are using oil data from Quandl, but the original data is from [FRED](https://fred.stlouisfed.org/).  There's nothing wrong with grabbing the data directly from FRED, of course, and I browse FRED frequently to check out economic data, but I tend to download the data into my RStudio environment using Quandl.  I wanted to introduce Quandl today because it's a nice resource that will be involved in the next few posts in this series. Plus, it's gaining in popularity, and if you work in the financial industry, you might start to encounter it in your work. 

*   This post marks our first foray into the world of predictive modeling, albeit in a very simple way. But the complexity and accuracy of the forecasting methodology we use here is almost irrelevant since I expect that most R coders, whether in industry or otherwise, will have their own proprietary models. Rather, what I want to accomplish here is a framework where models can be inserted, visualized, and scrutinized in the future.  I harp on reproducible workflows a lot, and that's not going to change today because one goal of this Notebook is to house a forecast that can be reproduced in the future (at which point, we will know if the forecast was accurate or not), and then tweaked/criticized/updated/heralded. 

*   This post walks through a detailed example of importing, forecasting, and visualizing oil prices. In the near future, I will repeat those steps for gold and copper, and we will examine the relationship between the copper/gold price ratio and interest rates. We are starting simple, but stay tuned.

Let's start by loading the packages we'll need for this post:

<div class="layout-chunk" data-layout="l-body">

```r

library(Quandl)
library(dplyr)
library(xts)
library(lubridate)
library(forecast)
library(dygraphs)
```

</div>


## Downloading the data

Now, let's get to the data download! In the chunk below, as we import WTI oil prices, notice that Quanld makes it easy to choose types of objects (raw/dataframe, xts, or zoo), periods (daily, weekly, or monthly) and start/end dates.   


```r

# Start with daily data. Note that "type = raw" will download a data frame.
oil_daily <- Quandl("FRED/DCOILWTICO", type = "raw", collapse = "daily",  
                    start_date="2006-01-01", end_date="2017-02-28")
# Now weekely and let's use xts as the type.
oil_weekly <- Quandl("FRED/DCOILWTICO", type = "xts", collapse = "weekly",  
                     start_date="2006-01-01", end_date="2017-02-28")
# And monthly using xts as the type.
oil_monthly <- Quandl("FRED/DCOILWTICO", type = "xts", collapse = "monthly",  
                      start_date="2006-01-01", end_date="2017-02-28")

# Have a quick look at our three  objects. 
str(oil_daily)
```

```
'data.frame':	2809 obs. of  2 variables:
 $ Date : Date, format: "2017-02-28" "2017-02-27" ...
 $ Value: num  54 54 54 54.5 53.6 ...
 - attr(*, "freq")= chr "daily"
```

```r

str(oil_weekly)
```

```
An 'xts' object on 2006-01-08/2017-03-05 containing:
  Data: num [1:583, 1] 64.2 63.9 68.2 67.8 65.4 ...
  Indexed by objects of class: [Date] TZ: UTC
  xts Attributes:  
 NULL
```

```r

str(oil_monthly)
```

```
An 'xts' object on Jan 2006/Feb 2017 containing:
  Data: num [1:134, 1] 67.9 61.4 66.2 71.8 71.4 ...
  Indexed by objects of class: [yearmon] TZ: UTC
  xts Attributes:  
 NULL
```

Also note that I specified the end date of February 2017. This indicates that the Notebook houses a model that was built and run using data as of February 2017. Without the end date, this Notebook would house a model that was built and run using data as of time `t`. Which you choose depends how you want the Notebook to function for your team.

Looking back at those oil price objects, each would work well for the rest of this project, but let's stick with the monthly data.  We will be dealing with the date index quite a bit below, so let's use the `seq()` function and `mdy()` from the lubridate package to put the date into a nicer format.

<div class="layout-chunk" data-layout="l-body">

```r

index(oil_monthly) <- seq(mdy('01/01/2006'), mdy('02/01/2017'), by = 'months')
head(index(oil_monthly))
```

```
[1] "2006-01-01" "2006-02-01" "2006-03-01" "2006-04-01" "2006-05-01"
[6] "2006-06-01"
```

</div>


Now we have a cleaner date format. Our base data object is in good shape. As always, we like to have a look at the data in graphical format, so let's fire up dygraphs. Since we imported an xts object directly from Quandl, we can just plug it straight into the `dygraph()` function.

<div class="layout-chunk" data-layout="l-page">

```r

dygraph(oil_monthly, main = "Monthly oil Prices")
```
<!--html_preserve--><div id="htmlwidget-d84931b524f494dec146" style="width:576px;height:384px;" class="dygraphs html-widget"></div>
<script type="application/json" data-for="htmlwidget-d84931b524f494dec146">{"x":{"attrs":{"title":"Monthly oil Prices","labels":["month","V1"],"legend":"auto","retainDateWindow":false,"axes":{"x":{"pixelsPerLabel":60}}},"scale":"monthly","annotations":[],"shadings":[],"events":[],"format":"date","data":[["2006-01-01T00:00:00.000Z","2006-02-01T00:00:00.000Z","2006-03-01T00:00:00.000Z","2006-04-01T00:00:00.000Z","2006-05-01T00:00:00.000Z","2006-06-01T00:00:00.000Z","2006-07-01T00:00:00.000Z","2006-08-01T00:00:00.000Z","2006-09-01T00:00:00.000Z","2006-10-01T00:00:00.000Z","2006-11-01T00:00:00.000Z","2006-12-01T00:00:00.000Z","2007-01-01T00:00:00.000Z","2007-02-01T00:00:00.000Z","2007-03-01T00:00:00.000Z","2007-04-01T00:00:00.000Z","2007-05-01T00:00:00.000Z","2007-06-01T00:00:00.000Z","2007-07-01T00:00:00.000Z","2007-08-01T00:00:00.000Z","2007-09-01T00:00:00.000Z","2007-10-01T00:00:00.000Z","2007-11-01T00:00:00.000Z","2007-12-01T00:00:00.000Z","2008-01-01T00:00:00.000Z","2008-02-01T00:00:00.000Z","2008-03-01T00:00:00.000Z","2008-04-01T00:00:00.000Z","2008-05-01T00:00:00.000Z","2008-06-01T00:00:00.000Z","2008-07-01T00:00:00.000Z","2008-08-01T00:00:00.000Z","2008-09-01T00:00:00.000Z","2008-10-01T00:00:00.000Z","2008-11-01T00:00:00.000Z","2008-12-01T00:00:00.000Z","2009-01-01T00:00:00.000Z","2009-02-01T00:00:00.000Z","2009-03-01T00:00:00.000Z","2009-04-01T00:00:00.000Z","2009-05-01T00:00:00.000Z","2009-06-01T00:00:00.000Z","2009-07-01T00:00:00.000Z","2009-08-01T00:00:00.000Z","2009-09-01T00:00:00.000Z","2009-10-01T00:00:00.000Z","2009-11-01T00:00:00.000Z","2009-12-01T00:00:00.000Z","2010-01-01T00:00:00.000Z","2010-02-01T00:00:00.000Z","2010-03-01T00:00:00.000Z","2010-04-01T00:00:00.000Z","2010-05-01T00:00:00.000Z","2010-06-01T00:00:00.000Z","2010-07-01T00:00:00.000Z","2010-08-01T00:00:00.000Z","2010-09-01T00:00:00.000Z","2010-10-01T00:00:00.000Z","2010-11-01T00:00:00.000Z","2010-12-01T00:00:00.000Z","2011-01-01T00:00:00.000Z","2011-02-01T00:00:00.000Z","2011-03-01T00:00:00.000Z","2011-04-01T00:00:00.000Z","2011-05-01T00:00:00.000Z","2011-06-01T00:00:00.000Z","2011-07-01T00:00:00.000Z","2011-08-01T00:00:00.000Z","2011-09-01T00:00:00.000Z","2011-10-01T00:00:00.000Z","2011-11-01T00:00:00.000Z","2011-12-01T00:00:00.000Z","2012-01-01T00:00:00.000Z","2012-02-01T00:00:00.000Z","2012-03-01T00:00:00.000Z","2012-04-01T00:00:00.000Z","2012-05-01T00:00:00.000Z","2012-06-01T00:00:00.000Z","2012-07-01T00:00:00.000Z","2012-08-01T00:00:00.000Z","2012-09-01T00:00:00.000Z","2012-10-01T00:00:00.000Z","2012-11-01T00:00:00.000Z","2012-12-01T00:00:00.000Z","2013-01-01T00:00:00.000Z","2013-02-01T00:00:00.000Z","2013-03-01T00:00:00.000Z","2013-04-01T00:00:00.000Z","2013-05-01T00:00:00.000Z","2013-06-01T00:00:00.000Z","2013-07-01T00:00:00.000Z","2013-08-01T00:00:00.000Z","2013-09-01T00:00:00.000Z","2013-10-01T00:00:00.000Z","2013-11-01T00:00:00.000Z","2013-12-01T00:00:00.000Z","2014-01-01T00:00:00.000Z","2014-02-01T00:00:00.000Z","2014-03-01T00:00:00.000Z","2014-04-01T00:00:00.000Z","2014-05-01T00:00:00.000Z","2014-06-01T00:00:00.000Z","2014-07-01T00:00:00.000Z","2014-08-01T00:00:00.000Z","2014-09-01T00:00:00.000Z","2014-10-01T00:00:00.000Z","2014-11-01T00:00:00.000Z","2014-12-01T00:00:00.000Z","2015-01-01T00:00:00.000Z","2015-02-01T00:00:00.000Z","2015-03-01T00:00:00.000Z","2015-04-01T00:00:00.000Z","2015-05-01T00:00:00.000Z","2015-06-01T00:00:00.000Z","2015-07-01T00:00:00.000Z","2015-08-01T00:00:00.000Z","2015-09-01T00:00:00.000Z","2015-10-01T00:00:00.000Z","2015-11-01T00:00:00.000Z","2015-12-01T00:00:00.000Z","2016-01-01T00:00:00.000Z","2016-02-01T00:00:00.000Z","2016-03-01T00:00:00.000Z","2016-04-01T00:00:00.000Z","2016-05-01T00:00:00.000Z","2016-06-01T00:00:00.000Z","2016-07-01T00:00:00.000Z","2016-08-01T00:00:00.000Z","2016-09-01T00:00:00.000Z","2016-10-01T00:00:00.000Z","2016-11-01T00:00:00.000Z","2016-12-01T00:00:00.000Z","2017-01-01T00:00:00.000Z","2017-02-01T00:00:00.000Z"],[67.86,61.37,66.25,71.8,71.42,73.94,74.56,70.38,62.9,58.72,62.97,60.85,58.17,61.78,65.94,65.78,64.02,70.47,78.2,73.98,81.64,94.16,88.6,95.95,91.67,101.78,101.54,113.7,127.35,139.96,124.17,115.55,100.7,68.1,55.21,44.6,41.73,44.15,49.64,50.35,66.31,69.82,69.26,69.97,70.46,77.04,77.19,79.39,72.85,79.72,83.45,86.07,74,75.59,78.85,71.93,79.95,81.45,84.12,91.38,90.99,97.1,106.19,113.39,102.7,95.3,95.68,88.81,78.93,93.19,100.36,98.83,98.46,107.08,103.03,104.89,86.52,85.04,88.08,96.47,92.18,86.23,88.54,91.83,97.65,92.03,97.24,93.22,91.93,96.36,105.1,107.98,102.36,96.29,92.55,98.17,97.55,102.88,101.57,100.07,103.4,106.07,98.23,97.86,91.17,80.53,65.94,53.45,47.79,49.84,47.72,59.62,60.25,59.48,47.11,49.2,45.06,46.6,40.43,37.13,33.66,32.74,36.94,45.98,49.1,48.27,41.54,44.68,47.72,46.83,49.41,53.75,52.75,54]]},"evals":[],"jsHooks":[]}</script><!--/html_preserve-->

</div>


Alright, nothing too shocking here. We see a peak in mid-2008, followed by a precipitous decline through the beginning of 2009.

## Forecasting

Now we'll make things a bit more interesting and try to extract some meaning from that data. Let's use the `forecast()` function to predict what oil prices will look like over the next six months. This is the part of the code where you might want to insert whatever model your team has built or wish to test. We can think of it as a placeholder for any proprietary model or models that could be dropped into this Notebook. For our purposes, we will simply pass in the monthly oil prices object and supply a `lookahead` parameter of 6. The `forecast()` function will then supply some interesting numbers about the next six months of oil prices.

<div class="layout-chunk" data-layout="l-body">

```r

oil_6month <- forecast(oil_monthly, h = 6)

# Let's have a quick look at the 6-month forecast and the 80%/95% confidence levels. 
oil_6month
```

```
    Point Forecast    Lo 80    Hi 80    Lo 95    Hi 95
135       53.99987 47.53908 60.46067 44.11894 63.88081
136       53.99987 44.84351 63.15624 39.99642 68.00333
137       53.99987 42.76141 65.23834 36.81212 71.18763
138       53.99987 40.99460 67.00515 34.11002 73.88973
139       53.99987 39.42782 68.57193 31.71385 76.28590
140       53.99987 38.00211 69.99764 29.53340 78.46635
```

</div>


The mean forecast is right around \$54. It looks like the 95% confidence level has a high of \$78 in August and a low of \$29 in March. We won't dwell on these numbers because I imagine you will want to use your own model here - this Notebook is more of a skeleton where those models can be inserted and then tested or evaluated at a later date.

Let's move on to visualizing the results of the forecast along with the historical data. The base `plot()` function does a decent job here.

<div class="layout-chunk" data-layout="l-page">

```r

plot(oil_6month, main = "Oil Forecast")
```
![](quandl-and-forecasting_files/figure-html5/unnamed-chunk-6-1.png)<!-- -->

</div>


That plot looks OK, but it's not great. We can see that the mean forecast is to stay around \$50, with the 95% bands stretching all the way to around \$80 and \$30, but honestly, I have to squint to really see those 95% intervals. We don't like squinting, so let's put in some extra work to make use of dygraphs, which will have the benefit of allowing a reader to zoom on the predicted portion of the graph. 

This is where things require a bit more thought. We want one xts object to hold both the historical data and the forecasted prices.

We already have our monthly prices in the xts object we imported from Quandl, but the forecasted prices are currently in a list with a different date convention than we would like. 

First, let's move the mean forecast and 95% confidence bands to a dataframe, along with a date column. We predicted oil out six months, so we will need a date column for the six months after February.


<div class="layout-chunk" data-layout="l-body">

```r

oil_forecast_data <- data.frame(date = seq(mdy('03/01/2017'), 
                                           by = 'months', length.out = 6),
                                Forecast = oil_6month$mean,
                                Hi_95 = oil_6month$upper[,2],
                                Lo_95 = oil_6month$lower[,2])

head(oil_forecast_data)
```

```
        date Forecast    Hi_95    Lo_95
1 2017-03-01 53.99987 63.88081 44.11894
2 2017-04-01 53.99987 68.00333 39.99642
3 2017-05-01 53.99987 71.18763 36.81212
4 2017-06-01 53.99987 73.88973 34.11002
5 2017-07-01 53.99987 76.28590 31.71385
6 2017-08-01 53.99987 78.46635 29.53340
```

</div>


The data we want is now housed in its own dataframe. Let's convert that to an xts object.

<div class="layout-chunk" data-layout="l-body">

```r

oil_forecast_xts <- xts(oil_forecast_data[,-1], order.by = oil_forecast_data[,1])
```

</div>


Now we can combine the historical xts object with the forecasted xts object using `cbind()`.

<div class="layout-chunk" data-layout="l-body">

```r

# Combine the xts objects with cbind.

oil_combined_xts <- cbind(oil_monthly, oil_forecast_xts)

# Add a nicer name for the first column.

colnames(oil_combined_xts)[1] <- "Actual"

# Have a look at both the head and the tail of our new xts object. Make sure the
# NAs are correct.
head(oil_combined_xts)
```

```
           Actual Forecast Hi_95 Lo_95
2006-01-01  67.86       NA    NA    NA
2006-02-01  61.37       NA    NA    NA
2006-03-01  66.25       NA    NA    NA
2006-04-01  71.80       NA    NA    NA
2006-05-01  71.42       NA    NA    NA
2006-06-01  73.94       NA    NA    NA
```

```r

tail(oil_combined_xts)
```

```
           Actual Forecast    Hi_95    Lo_95
2017-03-01     NA 53.99987 63.88081 44.11894
2017-04-01     NA 53.99987 68.00333 39.99642
2017-05-01     NA 53.99987 71.18763 36.81212
2017-06-01     NA 53.99987 73.88973 34.11002
2017-07-01     NA 53.99987 76.28590 31.71385
2017-08-01     NA 53.99987 78.46635 29.53340
```

</div>


It looks as it should. From January 2006 to February 2017 we have our actual data and NAs for the forecasted data. From March 2017 to August  2017, we have our mean forecast and 95% confidence levels and NAs for actual data. Said another way, we have four time series with observations at different dates, some of which are in the future. Most fortunately, dygraph provides a nice way to plot our actual time series versus our three forecasted time series because it simply does not plot the NAs.

<div class="layout-chunk" data-layout="l-body">

```r

dygraph(oil_combined_xts, main = "Oil Prices: Historical and Forecast") %>%
  # Add the actual series
  dySeries("Actual", label = "Actual") %>%
  # Add the three forecasted series
  dySeries(c("Lo_95", "Forecast", "Hi_95"))
```
<!--html_preserve--><div id="htmlwidget-b18a0ad53025515e3d76" style="width:576px;height:384px;" class="dygraphs html-widget"></div>
<script type="application/json" data-for="htmlwidget-b18a0ad53025515e3d76">{"x":{"attrs":{"title":"Oil Prices: Historical and Forecast","labels":["month","Actual","Forecast"],"legend":"auto","retainDateWindow":false,"axes":{"x":{"pixelsPerLabel":60}},"series":{"Actual":{"axis":"y"},"Forecast":{"axis":"y"}},"customBars":true},"scale":"monthly","annotations":[],"shadings":[],"events":[],"format":"date","data":[["2006-01-01T00:00:00.000Z","2006-02-01T00:00:00.000Z","2006-03-01T00:00:00.000Z","2006-04-01T00:00:00.000Z","2006-05-01T00:00:00.000Z","2006-06-01T00:00:00.000Z","2006-07-01T00:00:00.000Z","2006-08-01T00:00:00.000Z","2006-09-01T00:00:00.000Z","2006-10-01T00:00:00.000Z","2006-11-01T00:00:00.000Z","2006-12-01T00:00:00.000Z","2007-01-01T00:00:00.000Z","2007-02-01T00:00:00.000Z","2007-03-01T00:00:00.000Z","2007-04-01T00:00:00.000Z","2007-05-01T00:00:00.000Z","2007-06-01T00:00:00.000Z","2007-07-01T00:00:00.000Z","2007-08-01T00:00:00.000Z","2007-09-01T00:00:00.000Z","2007-10-01T00:00:00.000Z","2007-11-01T00:00:00.000Z","2007-12-01T00:00:00.000Z","2008-01-01T00:00:00.000Z","2008-02-01T00:00:00.000Z","2008-03-01T00:00:00.000Z","2008-04-01T00:00:00.000Z","2008-05-01T00:00:00.000Z","2008-06-01T00:00:00.000Z","2008-07-01T00:00:00.000Z","2008-08-01T00:00:00.000Z","2008-09-01T00:00:00.000Z","2008-10-01T00:00:00.000Z","2008-11-01T00:00:00.000Z","2008-12-01T00:00:00.000Z","2009-01-01T00:00:00.000Z","2009-02-01T00:00:00.000Z","2009-03-01T00:00:00.000Z","2009-04-01T00:00:00.000Z","2009-05-01T00:00:00.000Z","2009-06-01T00:00:00.000Z","2009-07-01T00:00:00.000Z","2009-08-01T00:00:00.000Z","2009-09-01T00:00:00.000Z","2009-10-01T00:00:00.000Z","2009-11-01T00:00:00.000Z","2009-12-01T00:00:00.000Z","2010-01-01T00:00:00.000Z","2010-02-01T00:00:00.000Z","2010-03-01T00:00:00.000Z","2010-04-01T00:00:00.000Z","2010-05-01T00:00:00.000Z","2010-06-01T00:00:00.000Z","2010-07-01T00:00:00.000Z","2010-08-01T00:00:00.000Z","2010-09-01T00:00:00.000Z","2010-10-01T00:00:00.000Z","2010-11-01T00:00:00.000Z","2010-12-01T00:00:00.000Z","2011-01-01T00:00:00.000Z","2011-02-01T00:00:00.000Z","2011-03-01T00:00:00.000Z","2011-04-01T00:00:00.000Z","2011-05-01T00:00:00.000Z","2011-06-01T00:00:00.000Z","2011-07-01T00:00:00.000Z","2011-08-01T00:00:00.000Z","2011-09-01T00:00:00.000Z","2011-10-01T00:00:00.000Z","2011-11-01T00:00:00.000Z","2011-12-01T00:00:00.000Z","2012-01-01T00:00:00.000Z","2012-02-01T00:00:00.000Z","2012-03-01T00:00:00.000Z","2012-04-01T00:00:00.000Z","2012-05-01T00:00:00.000Z","2012-06-01T00:00:00.000Z","2012-07-01T00:00:00.000Z","2012-08-01T00:00:00.000Z","2012-09-01T00:00:00.000Z","2012-10-01T00:00:00.000Z","2012-11-01T00:00:00.000Z","2012-12-01T00:00:00.000Z","2013-01-01T00:00:00.000Z","2013-02-01T00:00:00.000Z","2013-03-01T00:00:00.000Z","2013-04-01T00:00:00.000Z","2013-05-01T00:00:00.000Z","2013-06-01T00:00:00.000Z","2013-07-01T00:00:00.000Z","2013-08-01T00:00:00.000Z","2013-09-01T00:00:00.000Z","2013-10-01T00:00:00.000Z","2013-11-01T00:00:00.000Z","2013-12-01T00:00:00.000Z","2014-01-01T00:00:00.000Z","2014-02-01T00:00:00.000Z","2014-03-01T00:00:00.000Z","2014-04-01T00:00:00.000Z","2014-05-01T00:00:00.000Z","2014-06-01T00:00:00.000Z","2014-07-01T00:00:00.000Z","2014-08-01T00:00:00.000Z","2014-09-01T00:00:00.000Z","2014-10-01T00:00:00.000Z","2014-11-01T00:00:00.000Z","2014-12-01T00:00:00.000Z","2015-01-01T00:00:00.000Z","2015-02-01T00:00:00.000Z","2015-03-01T00:00:00.000Z","2015-04-01T00:00:00.000Z","2015-05-01T00:00:00.000Z","2015-06-01T00:00:00.000Z","2015-07-01T00:00:00.000Z","2015-08-01T00:00:00.000Z","2015-09-01T00:00:00.000Z","2015-10-01T00:00:00.000Z","2015-11-01T00:00:00.000Z","2015-12-01T00:00:00.000Z","2016-01-01T00:00:00.000Z","2016-02-01T00:00:00.000Z","2016-03-01T00:00:00.000Z","2016-04-01T00:00:00.000Z","2016-05-01T00:00:00.000Z","2016-06-01T00:00:00.000Z","2016-07-01T00:00:00.000Z","2016-08-01T00:00:00.000Z","2016-09-01T00:00:00.000Z","2016-10-01T00:00:00.000Z","2016-11-01T00:00:00.000Z","2016-12-01T00:00:00.000Z","2017-01-01T00:00:00.000Z","2017-02-01T00:00:00.000Z","2017-03-01T00:00:00.000Z","2017-04-01T00:00:00.000Z","2017-05-01T00:00:00.000Z","2017-06-01T00:00:00.000Z","2017-07-01T00:00:00.000Z","2017-08-01T00:00:00.000Z"],[[67.86,67.86,67.86],[61.37,61.37,61.37],[66.25,66.25,66.25],[71.8,71.8,71.8],[71.42,71.42,71.42],[73.94,73.94,73.94],[74.56,74.56,74.56],[70.38,70.38,70.38],[62.9,62.9,62.9],[58.72,58.72,58.72],[62.97,62.97,62.97],[60.85,60.85,60.85],[58.17,58.17,58.17],[61.78,61.78,61.78],[65.94,65.94,65.94],[65.78,65.78,65.78],[64.02,64.02,64.02],[70.47,70.47,70.47],[78.2,78.2,78.2],[73.98,73.98,73.98],[81.64,81.64,81.64],[94.16,94.16,94.16],[88.6,88.6,88.6],[95.95,95.95,95.95],[91.67,91.67,91.67],[101.78,101.78,101.78],[101.54,101.54,101.54],[113.7,113.7,113.7],[127.35,127.35,127.35],[139.96,139.96,139.96],[124.17,124.17,124.17],[115.55,115.55,115.55],[100.7,100.7,100.7],[68.1,68.1,68.1],[55.21,55.21,55.21],[44.6,44.6,44.6],[41.73,41.73,41.73],[44.15,44.15,44.15],[49.64,49.64,49.64],[50.35,50.35,50.35],[66.31,66.31,66.31],[69.82,69.82,69.82],[69.26,69.26,69.26],[69.97,69.97,69.97],[70.46,70.46,70.46],[77.04,77.04,77.04],[77.19,77.19,77.19],[79.39,79.39,79.39],[72.85,72.85,72.85],[79.72,79.72,79.72],[83.45,83.45,83.45],[86.07,86.07,86.07],[74,74,74],[75.59,75.59,75.59],[78.85,78.85,78.85],[71.93,71.93,71.93],[79.95,79.95,79.95],[81.45,81.45,81.45],[84.12,84.12,84.12],[91.38,91.38,91.38],[90.99,90.99,90.99],[97.1,97.1,97.1],[106.19,106.19,106.19],[113.39,113.39,113.39],[102.7,102.7,102.7],[95.3,95.3,95.3],[95.68,95.68,95.68],[88.81,88.81,88.81],[78.93,78.93,78.93],[93.19,93.19,93.19],[100.36,100.36,100.36],[98.83,98.83,98.83],[98.46,98.46,98.46],[107.08,107.08,107.08],[103.03,103.03,103.03],[104.89,104.89,104.89],[86.52,86.52,86.52],[85.04,85.04,85.04],[88.08,88.08,88.08],[96.47,96.47,96.47],[92.18,92.18,92.18],[86.23,86.23,86.23],[88.54,88.54,88.54],[91.83,91.83,91.83],[97.65,97.65,97.65],[92.03,92.03,92.03],[97.24,97.24,97.24],[93.22,93.22,93.22],[91.93,91.93,91.93],[96.36,96.36,96.36],[105.1,105.1,105.1],[107.98,107.98,107.98],[102.36,102.36,102.36],[96.29,96.29,96.29],[92.55,92.55,92.55],[98.17,98.17,98.17],[97.55,97.55,97.55],[102.88,102.88,102.88],[101.57,101.57,101.57],[100.07,100.07,100.07],[103.4,103.4,103.4],[106.07,106.07,106.07],[98.23,98.23,98.23],[97.86,97.86,97.86],[91.17,91.17,91.17],[80.53,80.53,80.53],[65.94,65.94,65.94],[53.45,53.45,53.45],[47.79,47.79,47.79],[49.84,49.84,49.84],[47.72,47.72,47.72],[59.62,59.62,59.62],[60.25,60.25,60.25],[59.48,59.48,59.48],[47.11,47.11,47.11],[49.2,49.2,49.2],[45.06,45.06,45.06],[46.6,46.6,46.6],[40.43,40.43,40.43],[37.13,37.13,37.13],[33.66,33.66,33.66],[32.74,32.74,32.74],[36.94,36.94,36.94],[45.98,45.98,45.98],[49.1,49.1,49.1],[48.27,48.27,48.27],[41.54,41.54,41.54],[44.68,44.68,44.68],[47.72,47.72,47.72],[46.83,46.83,46.83],[49.41,49.41,49.41],[53.75,53.75,53.75],[52.75,52.75,52.75],[54,54,54],[null,null,null],[null,null,null],[null,null,null],[null,null,null],[null,null,null],[null,null,null]],[[null,null,null],[null,null,null],[null,null,null],[null,null,null],[null,null,null],[null,null,null],[null,null,null],[null,null,null],[null,null,null],[null,null,null],[null,null,null],[null,null,null],[null,null,null],[null,null,null],[null,null,null],[null,null,null],[null,null,null],[null,null,null],[null,null,null],[null,null,null],[null,null,null],[null,null,null],[null,null,null],[null,null,null],[null,null,null],[null,null,null],[null,null,null],[null,null,null],[null,null,null],[null,null,null],[null,null,null],[null,null,null],[null,null,null],[null,null,null],[null,null,null],[null,null,null],[null,null,null],[null,null,null],[null,null,null],[null,null,null],[null,null,null],[null,null,null],[null,null,null],[null,null,null],[null,null,null],[null,null,null],[null,null,null],[null,null,null],[null,null,null],[null,null,null],[null,null,null],[null,null,null],[null,null,null],[null,null,null],[null,null,null],[null,null,null],[null,null,null],[null,null,null],[null,null,null],[null,null,null],[null,null,null],[null,null,null],[null,null,null],[null,null,null],[null,null,null],[null,null,null],[null,null,null],[null,null,null],[null,null,null],[null,null,null],[null,null,null],[null,null,null],[null,null,null],[null,null,null],[null,null,null],[null,null,null],[null,null,null],[null,null,null],[null,null,null],[null,null,null],[null,null,null],[null,null,null],[null,null,null],[null,null,null],[null,null,null],[null,null,null],[null,null,null],[null,null,null],[null,null,null],[null,null,null],[null,null,null],[null,null,null],[null,null,null],[null,null,null],[null,null,null],[null,null,null],[null,null,null],[null,null,null],[null,null,null],[null,null,null],[null,null,null],[null,null,null],[null,null,null],[null,null,null],[null,null,null],[null,null,null],[null,null,null],[null,null,null],[null,null,null],[null,null,null],[null,null,null],[null,null,null],[null,null,null],[null,null,null],[null,null,null],[null,null,null],[null,null,null],[null,null,null],[null,null,null],[null,null,null],[null,null,null],[null,null,null],[null,null,null],[null,null,null],[null,null,null],[null,null,null],[null,null,null],[null,null,null],[null,null,null],[null,null,null],[null,null,null],[null,null,null],[null,null,null],[null,null,null],[44.1189444260667,53.999874832939,63.8808052398114],[39.9964178033862,53.999874832939,68.0033318624919],[36.8121214596734,53.999874832939,71.1876282062046],[34.1100172541902,53.999874832939,73.8897324116879],[31.7138465538637,53.999874832939,76.2859031120144],[29.5334010405799,53.999874832939,78.4663486252982]]]},"evals":[],"jsHooks":[]}</script><!--/html_preserve-->

</div>


Take a quick look back at our previous graph using the `plot()` function.  At first glance, the dygraph might not seem so different. But, we can now make use of hovering/tooltips and, more importantly, we can zoom in on the forecasted numbers see them much more clearly. Plus, the whole world of dygraph functionality is now available to us! 

That's all for today. We have gotten some familiarity with Quandl, used `forecast()` to predict the next six months of oil prices, and done some data wrangling so we can use our old friend dygraphs. Next time, we will wrap this into a Shiny app so that users can choose their own parameters, and maybe even choose different commodities. See you then!
