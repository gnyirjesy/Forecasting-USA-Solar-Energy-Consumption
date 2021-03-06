## ----setup, include=FALSE-----------------------------------------------------
#Install packages
library(httr)
library(jsonlite)
library(dplyr)
library(Metrics)
library(zoo)
library(knitr)
library(kableExtra)
library(scales)
library(forecast)


## ----function-definitions-----------------------------------------------------
#Function to convert a PERIOD_ID (YYYYMM) to a date (MM/01/YYYY)
period_to_date <- function(col){
  DATE <- as.Date(paste(as.numeric(col) %% 100, 1,
                                  round(as.numeric(col) %/% 100,0),
                                  sep = "/"), "%m/%d/%Y")
  return(DATE)
}

#Function to pull data using API call
API_request <- function(API_call, API_key){
  res = GET(sub('YOUR_API_KEY_HERE', API_key, API_call))
  data = fromJSON(rawToChar(res$content))
  consumption_data <- as.data.frame(data$series$data)
  consumption_data <- consumption_data %>% 
    rename(PERIOD_ID = X1,
      TRILLION_BTU = X2)
  consumption_data$DATE <- period_to_date(consumption_data$PERIOD_ID)
  return(consumption_data)
}

#Function to run naive model
naive_model <- function(ts_train, ts_test){
  require(forecast)
  model <- naive(ts_train, level=c(80,95), h=12)
  plot(model, xlab="Date", ylab="Trillion Btu")
  lines(ts_test, col='red')
  data_eval <- data.frame(actual_data=as.matrix(ts_test),
                          date=as.Date(as.yearmon(time(ts_test))))
  data_eval <- cbind(data_eval, predicted = model$mean)
  return(list(aicc = model$aicc, model = model, data_eval = data_eval))
}

#Function to run ARIMA model without external regressors
arima_model <- function(ts_train, ts_test){
  require(forecast)
  model <- auto.arima(ts_train,
                          stepwise = FALSE,
                          approximation = FALSE,
                          seasonal = FALSE,
                          ic = 'aicc')
  forecast_data <- forecast(model, level=c(80,95), h= 12)
  plot(forecast_data, xlab="Date", ylab="Trillion Btu")
  lines(ts_test, col='red')
  data_eval <- data.frame(actual_data=as.matrix(ts_test),
                          date=as.Date(as.yearmon(time(ts_test))))
  data_eval <- cbind(data_eval, predicted = forecast_data$mean)
  return(list(aicc = model$aicc, model = model, data_eval = data_eval))
}

#Function to run ARIMA model with Fourier component of different external regressors and pull out best performing forecast by aicc
best_fourier <- function(ts_train, ts_test){
  require(forecast)
  models <- lapply(seq(1,6), function(j){
    try(auto.arima(ts_train,
                   xreg = fourier(ts_train, K=j),
                   seasonal = FALSE,
                   stepwise = FALSE,
                   approximation = FALSE,
                   ic = 'aicc'))
  })
  best_forecast <- which.min(sapply(models, function(x){x[['aicc']]}))
  forecast_data <- forecast(models[[best_forecast]], level=c(80,95),
                                xreg = fourier(ts_train, K=best_forecast,
                                               h= 12))
  plot(forecast_data, xlab="Date", ylab="Trillion Btu")
  lines(ts_test, col='red')
  data_eval <- data.frame(actual_data=as.matrix(ts_test),
                          date=as.Date(as.yearmon(time(ts_test))))
  data_eval <- cbind(data_eval, predicted = forecast_data$mean)
  return(list(aicc = models[[best_forecast]]$aicc,
              model = models[[best_forecast]], k= best_forecast,
              data_eval = data_eval))
}

# Function to run ETS model
ets_model <- function(ts_train, ts_test){
  require(forecast)
  model <- ets(ts_train)
  forecast_data <- forecast(model, level=c(80,95), h= 12)
  plot(forecast_data, xlab="Date", ylab="Trillion Btu")
  lines(ts_test, col='red')
  data_eval <- data.frame(actual_data=as.matrix(ts_test),
                          date=as.Date(as.yearmon(time(ts_test))))
  data_eval <- cbind(data_eval, predicted = forecast_data$mean)
  return(list(aicc = model$aicc, model = model, data_eval = data_eval))
}

#Function to get model metrics
get_metrics <- function(data_eval){
  model_MAPE <- mape(data_eval$actual, data_eval$predicted)
  model_RMSE <- round(rmse(data_eval$actual, data_eval$predicted), 2)
  model_MAE <- round(mae(data_eval$actual, data_eval$predicted), 2)
  model_MASE <- round(mase(data_eval$actual, data_eval$predicted), 2)
  model_bias <- round(bias(data_eval$actual, data_eval$predicted),2)
  metrics <- list(model_MAPE, model_RMSE, model_MASE, model_MAE, model_bias)
  names(metrics) <- c('MAPE', 'RMSE', 'MAE', 'MASE', 'Bias')
  metrics <- as.data.frame(metrics)
  metrics$MAPE <- percent(metrics$MAPE, accuracy = 0.01)
  return(metrics)
}

#Create summary table of all metrics results
metrics_summary <- function(dfNames) {
  do.call(rbind, lapply(dfNames, function(x) {
    cbind(Model = strsplit(x,'_')[[1]][1], get(x))
  }))
}


## ----data-pull----------------------------------------------------------------
api_key = 'b7369a57166eee9b3612e8774f172306'
solar <- API_request("http://api.eia.gov/series/?api_key=YOUR_API_KEY_HERE&series_id=TOTAL.SOTCBUS.M", api_key)


## ----data-cleaning, warning=FALSE---------------------------------------------
solar$TRILLION_BTU <- as.numeric(solar$TRILLION_BTU)
solar$TRILLION_BTU[is.na(solar$TRILLION_BTU)] <- 0
solar <- solar[order(solar$DATE),]
first_value <- which.max(solar$TRILLION_BTU > 0)
solar <- solar %>% slice(first_value:n())


## ----plot-full-data, fig.align="center"---------------------------------------
plot(solar$DATE, solar$TRILLION_BTU, type = 'l', xlab="Date", ylab="Trillion Btu")


## ----train-test-split---------------------------------------------------------
#split where there are 12 remaining months left
cut_loc <- which(solar$DATE > seq(max(solar$DATE), length=2, by="-1 years")[2])
train_data <- solar[-cut_loc,]
test_data <- solar[cut_loc,]


## ----time series creation-----------------------------------------------------
start_year_train = as.numeric(format(as.Date(min(train_data$DATE), format="%d/%m/%Y"),"%Y"))
start_month_train = as.numeric(format(as.Date(min(train_data$DATE), format="%d/%m/%Y"),"%m"))
ts_train <- ts(train_data$TRILLION_BTU,
               start = c(start_year_train, start_month_train), frequency = 12)

start_year_test = as.numeric(format(as.Date(min(test_data$DATE), format="%d/%m/%Y"),"%Y"))
start_month_test = as.numeric(format(as.Date(min(test_data$DATE), format="%d/%m/%Y"),"%m"))
ts_test <- ts(test_data$TRILLION_BTU,start = c(start_year_test, start_month_test), frequency=12)


## ----ts-decomposition, fig.align="center"-------------------------------------
fit <- stl(ts_train, s.window="period")
plot(fit)


## ----seasonal-plot, fig.align="center"----------------------------------------
# additional plots
seasonplot(ts_train)


## ----naive-plot, fig.align="center"-------------------------------------------
naive_results <- naive_model(ts_train, ts_test)


## ----naive-metrics------------------------------------------------------------
naive_metrics <- get_metrics(naive_results$data_eval)
kable(as.data.frame(naive_metrics) %>% select_all, caption = "Naive Forecast Metrics") %>% kable_styling(full_width = F, bootstrap_options = c("condensed"))


## ----arima-plot, fig.align="center"-------------------------------------------
best_arima_result <- arima_model(ts_train, ts_test)


## ----arima-metrics------------------------------------------------------------
arima_metrics <- get_metrics(best_arima_result$data_eval)
kable(as.data.frame(arima_metrics) %>% select_all, caption = "ARIMA Forecast Metrics") %>% kable_styling(full_width = F, bootstrap_options = c("condensed"))


## ----Fourier-plot, fig.align="center"-----------------------------------------
best_fourier_result <- best_fourier(ts_train, ts_test)


## ----Fourier-metrics----------------------------------------------------------
fourier_metrics <- get_metrics(best_fourier_result$data_eval)
kable(as.data.frame(fourier_metrics) %>% select_all, caption = "ARIMA/Fourier Forecast Metrics") %>% kable_styling(full_width = F, bootstrap_options = c("condensed"))


## ----ETS-plot, fig.align="center"---------------------------------------------
best_ets_result <- ets_model(ts_train, ts_test)


## ----ETS-metrics--------------------------------------------------------------
ets_metrics <- get_metrics(best_ets_result$data_eval)
kable(as.data.frame(ets_metrics) %>% select_all, caption = "ETS Forecast Metrics") %>% kable_styling(full_width = F, bootstrap_options = c("condensed"))


## ----summary-stats------------------------------------------------------------
summary_stats <- metrics_summary(c('naive_metrics', 'arima_metrics', 'fourier_metrics', 'ets_metrics'))
kable(as.data.frame(summary_stats) %>% select_all, caption = "Summary Forecast Metrics") %>% kable_styling(full_width = F, bootstrap_options = c("condensed", "striped")) %>%
  row_spec(which(summary_stats$RMSE == min(summary_stats$RMSE)),
           bold = T, color = "white", background = "green") %>%
  column_spec(1, bold=T)


## ----final-forecast, fig.align="center"---------------------------------------
forecast_data <- forecast(best_ets_result$model, level=c(80,95), h= 120)
plot(forecast_data, xlab="Date", ylab="Trillion Btu")

