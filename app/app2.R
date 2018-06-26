# Load packages ----
library(shiny)
library(maps)
library(mapproj)
library(tidyverse)

# Load data ----
counties <- readRDS("counties.rds")
# Data
data <- read_csv("merged_data.csv") %>%
  as.data.frame()


# Source helper functions -----
source("helpers.R")

# User interface ----
ui <- fluidPage(
  titlePanel("Mapping the American Dream"),
  
  sidebarLayout(
    sidebarPanel(
      helpText("Adjust the weight of different factors in the American
               Dream."),
      
      sliderInput("k1", 
                  label = "Intergenerational Income Mobility",
                  min = 0, max = 100, value = 50),
      
      sliderInput("k2", 
                  label = "Job Availability by Educational Level",
                  min = 0, max = 100, value = 25),
      
      sliderInput("k3", 
                  label = "Affordability by Home Mortgage",
                  min = 0, max = 100, value = 25),
      
      sliderInput("k4", 
                  label = "Ethnic Diversity",
                  min = 0, max = 100, value = 25)
    ),
    
    mainPanel(plotOutput("map", width = "100%"))
    
  )
)

# Weight function
weight_calc <- function(w1, w2, w3, w4) {
  c(w1, w2, w3, w4) / sum(w1, w2, w3, w4)
}


# Server logic ----
server <- function(input, output) {
  
  dataInput <- reactive({
    
    weights <- weight_calc(input$k1, input$k2, input$k3, input$k4)
    # recalc merged data
    
    
  })
  
  finalInput <- reactive({
    if (!input$adjust) return(dataInput())
    adjust(dataInput())
    
})


output$map <- renderPlot({
  
  
  dataInput <- reactive({
    
    weights <- weight_calc(input$k1, input$k2, input$k3, input$k4)
    
    chloroplether(
      finalInput, # Needs to be full data instead of just the ranking weights
      # weights, 
      weighted_rank,
      title_main = "Mapping the American Dream Index" , 
      subtitle = "A County Ranking by Income Mobility, Accessible Jobs\nAffordable Housing, and Ethnic Diversity",
      title_legend = "Personalized American Dream Index (%)", 
      caption = "Source: Raj Chetty Lab, ACS 5-Year Surveys"
    )
    
  })
  
})
}


# Run app ----
shinyApp(ui, server)