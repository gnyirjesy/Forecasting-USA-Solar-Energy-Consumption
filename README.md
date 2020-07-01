# Forecasting USA Solar Energy Consumption


## Table of contents
* [General info](#general-info)
* [Technologies](#technologies)
* [Setup](#setup)
* [Features](#features)
* [Results](#results)
* [Status](#status)
* [Contact](#contact)
* [Acknowledgements](#acknowledgements)

## General info
The goal of this project is to develop a forecasting model to predict solar energy consumption over the next 10 years. The consumption information can be used to help solar energy suppliers scale production to meet this demand.

## Technologies
* RStudio

## Setup
The following R packages were used for this project:

* jsonlite_1.7.0
* httr_1.4.1  
* dplyr_1.0.0
* Metrics_0.1.4
* zoo_1.8-8
* forecast_8.12
* kableExtra_1.1.0
* knitr_1.28

_*Data was collected by the [U.S. Energy Information Administration](https://www.eia.gov/opendata/qb.php?category=711302&sdid=TOTAL.SOTCBUS.A) and pulled through an API call in the code._

## Features
The following forecasting methods are explored in this project:
 
* Naive
* ARIMA
* ARIMA with Fourier components
* ETS

## Results
The table below shows that the ETS model had the best performance for this data set; the MAPE, RMSE, MAE, and MASE were all lowest with this model. The ARIMA model had the least bias, but higher values for the other metrics. The models are over-predicting the energy consumption, as can be seen from the positive bias values. 

![Forecast_Summary](Forecast_Summary_Stats.png)

The plot below shows the ETS forecast for United States solar energy consumption over the next 10 years.
<img src="Forecast_Plot.PNG" />

## Status
Project is: _complete_

## Contact
Created by [Gabrielle Nyirjesy](https://www.linkedin.com/in/gabrielle-nyirjesy) - feel free to contact me!

## Acknowledgements
* Data was collected by the [U.S. Energy Information Administration](https://www.eia.gov/opendata/qb.php?category=711302&sdid=TOTAL.SOTCBUS.A)
