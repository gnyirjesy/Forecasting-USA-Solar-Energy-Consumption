library(haven)
library(ggplot2)

#Read in data
setwd('/Users/gabbynyirjesy/Desktop/GitHub/Forecasting')
energy_data <- read.csv('AEP_hourly.csv')

#This function will extrapolate outliers in the dataset to the value
#of the 95th or 5th percentils if it is an extreme high/low
extrapolate_outliers <- function(data, col) {
  q_95 <- quantile(data$col, 0.95)
  if(length(data$col[data$col > 0.95]) > 0){
    data$col[data$col > 0.95] <- q_95
  }
  q_05 <- quantile(data$col, 0.05)
  if(length(data$col[data$col < 0.05]) > 0){
    data$col[data$col < 0.05] <- q_05
  }
  return(data)
}

energy_data_smooth <- extrapolate_outliers(energy_data, AEP_MW)
energy_data_smooth$timestamp = strptime(energy_data_smooth$Datetime, "%Y-%m-%d %H:%M:%S")
#ggplot(aes(x = timestamp, y = AEP_MW), data = energy_data_smooth) + geom_line()
plot(energy_data_smooth$timestamp, energy_data_smooth$AEP_MW, xaxt="n", type = 'l')


data(USgas, package = "TSstudio")
