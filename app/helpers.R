# Note: percent map is designed to work with the counties data set
# It may not work correctly with other data sets if their row order does 
# not exactly match the order in which the maps package plots counties
library(tidyverse, quietly = TRUE)
library(haven, quietly = TRUE)
library(sf, quietly = TRUE)

# Parameters
# Commuting zones in Alaska and Hawaii
CZS_AK_HI <- c(
  "34101",
  "34102",
  "34103",
  "34104",
  "34105",
  "34106",
  "34107",
  "34108",
  "34109",
  "34110",
  "34111",
  "34112",
  "34113",
  "34114",
  "34115",
  "34701",
  "34702",
  "34703",
  "35600"
)

# Albers projection for 48 contiguous US states
US_ALBERS <- "+proj=aea +lat_1=29.5 +lat_2=45.5 +lat_0=37.5 +lon_0=-96 +x_0=0 +y_0=0 +datum=WGS84 +no_defs"

# Colors used in New York Times map
NYT_COLORS <- c(
  "#740023",
  "#b63132",
  "#d27952",
  "#e9b777",
  "#fdf6a3",
  "#a2c0a1",
  "#55889e",
  "#195473",
  "#004364"
)

# Color used in New York Times map for missing values
NYT_NA_COLOR <- "#f2f2f2"

# Population URL: 
# https://factfinder.census.gov/faces/tableservices/jsf/pages/productview.xhtml?src=bkmk


#########################################################################
# Start of Data 

counties <-
  read_rds("counties_rds.rds") %>%
  mutate(county = as.numeric(GEOID)) %>% 
  filter(!str_detect(STATEFP, "02")) %>%
  filter(!str_detect(STATEFP, "15")) %>%
  st_transform(crs = US_ALBERS)

states <- 
  read_rds("states_rds.rds") %>%
  filter(!str_detect(STATEFP, "02")) %>%
  filter(!str_detect(STATEFP, "15")) %>%
  mutate(county = as.numeric("GEOID")) %>%
  st_transform(crs = US_ALBERS)


# Mobility data
mobility_dta <- 
  read_dta("online_table2.dta") 

mobility <-
  mobility_dta %>%
  mutate(
    pct_kids_p25 = pct_causal_p25_kr26,
    pct_kids_p75 = pct_causal_p75_kr26, 
    county = cty2000, 
    county_stateabbrv = str_c(county_name, stateabbrv, sep = " County, ")
  ) 

mobility_county <-
  mobility %>%
  filter(stateabbrv != "AK", stateabbrv != "HI") %>%
  left_join(counties, by = "county") %>%
  select(county, county_stateabbrv, pct_kids_p25, geometry)

# Jobs by educational attainment data: ACS_16_5YR_S2301
jobs <- 
  read_csv(
    "jobs.csv",
    na = c("(X)", "-", "**", "N")
  )

jobs_county <-
  jobs %>%
  filter(!str_detect(`GEO.display-label`, "Alaska"),  !str_detect(`GEO.display-label`, "Hawaii")) %>%
  mutate(
    county = as.numeric(GEO.id2), 
    county_state = `GEO.display-label`,
    employrate = (HC01_EST_VC44 + HC01_EST_VC45) / HC01_EST_VC43 * 100
  ) %>%
  left_join(counties, by = "county") %>%
  select(
    county, 
    county_state, 
    employrate,
    geometry
  ) %>%
  ungroup()

housing_file <- "ACS_16_5YR_DP04.csv"

# Monthly housing costs by income, ACS DP04
housing_data <- 
  read_csv(
    housing_file, 
    na = c("(X)", "-", "**", "N")
  ) 

housing_county <-
  housing_data %>%
  filter(HC01_VC159 > 500) %>%
  rowwise() %>%
  mutate(
    county = as.numeric(`GEO.id2`), 
    county_state = `GEO.display-label`,
    `pct_below_29.9` = sum(HC01_VC160, HC01_VC161, HC01_VC162)  / HC01_VC159 * 100
  ) %>%
  ungroup() %>%
  left_join(counties, by = "county") %>%
  select(county, county_state, `pct_below_29.9`, geometry) %>%
  filter(!is.na(`pct_below_29.9`)) %>%
  arrange(`pct_below_29.9`)

# Ethnic diversity by county: ACS_16_5YR_B03002
diversity_data <- 
  read_csv(
    "diversity.csv", 
    na = c("(X)", "-", "**", "N")
  ) 

diversity_county <-
  diversity_data %>%
  filter(!str_detect(`GEO.display-label`, "Alaska"),  !str_detect(`GEO.display-label`, "Hawaii")) %>%
  mutate(
    county = as.numeric(GEO.id2), 
    county_state = `GEO.display-label`,
    pct_white = HD01_VD03 / HD01_VD01 * 100, 
    diversity = 100 - pct_white
  ) %>%
  left_join(counties, by = "county") %>%
  select(county, county_state, pct_white, diversity, geometry) 

#########################################################################
# End of Data


# Merge all Data
########################################################################
# Weight function
weight_calc <- function(w1, w2, w3, w4) {
  c(w1, w2, w3, w4) / sum(w1, w2, w3, w4)
}


weights <- weight_calc(0.45, 0.25, 0.25, 0.25)

# Full data with default weights
merged_data <-
  mobility_county %>% 
  select(-county_stateabbrv) %>%
  left_join(jobs_county %>% select(-geometry), by = c("county")) %>%
  left_join(housing_county %>% select(-geometry), by = c("county", "county_state")) %>%
  left_join(diversity_county %>% select(-c(geometry, county_state, pct_white)), by = "county") %>%
  filter(!is.na(`pct_below_29.9`), !is.na(diversity)) %>%
  mutate(
    gross_rank = row_number(),
    pct_kids_p25 = pct_kids_p25 / max(pct_kids_p25) * 100
  ) %>%
  arrange(desc(pct_kids_p25, diversity), employrate, `pct_below_29.9`) %>%
  select(county, county_state, pct_kids_p25, employrate, `pct_below_29.9`, diversity, geometry) %>%
  rowwise() %>%
  mutate(
    weighted_rank = pct_kids_p25 * weights[1] + 
      employrate * weights[2] +
      `pct_below_29.9` * weights[3] +
      diversity * weights[4]
  ) %>%
  arrange(desc(weighted_rank))


###########################################################################
# End of Merge

chloroplether <- 
  function(weights, var_fill, title_main, subtitle, title_legend, caption) {
    var_fill <- enquo(var_fill)
    chloro_plot <-
      merged_data %>%
      mutate(
        weighted_rank = pct_kids_p25 * weights[1] + 
          employrate * weights[2] +
          `pct_below_29.9` * weights[3] +
          diversity * weights[4]
      ) %>%
      ggplot() +
      geom_sf(aes(fill = !!var_fill),color = "black", size = 0.01) +
      geom_sf(data = states, color = "black", fill = NA, size = 0.01) +
      scale_fill_gradientn(
        colors = NYT_COLORS,
        na.value = NYT_NA_COLOR
      ) +
      coord_sf(datum = NA) +
      guides(
        fill = guide_colorbar(
          title = title_legend,
          title.position = "top",
          title.theme = element_text(size = 8, angle = 0),
          title.hjust = .5,
          label.theme = element_text(size = 7, angle = 0),
          barwidth = 12,
          barheight = 0.4,
          direction = "horizontal"
        )
      ) +
      theme_void() +
      theme(
        legend.position = "bottom",
        legend.text = element_text(size = 6)
      ) +
      labs(
        title = title_main,
        subtitle = subtitle,
        caption = caption
      )
    
    return(chloro_plot)
  }
