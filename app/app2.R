# Load packages ----
library(shiny)
library(maps)
library(mapproj)
# library(tidyverse)


# setwd("D:/GitHub/american-dream")

# Load data ----
counties <- readRDS("D:/GitHub/american-dream/data/counties.rds")
# countiesdf <- as.data.frame(counties)


# Source helper functions -----
source("helpers2.R")

# User interface ----
ui <- fluidPage(
  titlePanel("Mapping the American Dream"),
  
  sidebarLayout(
    sidebarPanel(
      helpText("Create demographic maps with 
               information from the 2010 US Census."),
      # 
      # selectInput("var", 
      #             label = "Choose a variable to display",
      #             choices = c("Percent White", "Percent Black",
      #                         "Percent Hispanic", "Percent Asian"),
      #             selected = "Percent White"),
      
      sliderInput("rank", 
                  label = "Slide to adjust rankings: ",
                  min = 0, max = 100, value = 50
      ),
      
      mainPanel(plotOutput("map"))
    )
  )
)

# Server logic ----
server <- function(input, output) {
  output$map <- renderPlot({
    data <- switch(input$var, 
                   "Percent White" = counties$white,
                   "Percent Black" = counties$black,
                   "Percent Hispanic" = counties$hispanic,
                   "Percent Asian" = counties$asian)
    
    color <- switch(input$var, 
                    "Percent White" = "darkgreen",
                    "Percent Black" = "black",
                    "Percent Hispanic" = "darkorange",
                    "Percent Asian" = "darkviolet")
    
    legend <- switch(input$var, 
                     "Percent White" = "% White",
                     "Percent Black" = "% Black",
                     "Percent Hispanic" = "% Hispanic",
                     "Percent Asian" = "% Asian")
    
    percent_map(data, color, legend, input$rank)
  })
}

# Run app ----
shinyApp(ui, server)