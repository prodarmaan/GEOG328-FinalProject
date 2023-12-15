# Loading required libraries
library(tidyverse)
library(sf)
library(dplyr)
library(leaflet)
library(classInt)

# Set working directory
setwd("")

# Loading in 911 Calls data
calls <- read.csv("filtered911Calls.csv")

# Loading in Per Capita Income data
income <- read.csv("PerCapitaIncome.csv")

# Reformatting the 'Datetime' column format for filtering compatibility
calls$Datetime <- as.POSIXct(strptime(calls$Datetime, format="%m/%d/%Y %I:%M:%S %p"))

# Filtering the 911 calls dataset to only include the relevant time frame
lowerThreshold <- as.POSIXct("2022-08-31 00:00:00", format="%Y-%m-%d %H:%M:%S", tz="UTC")
upperThreshold <- as.POSIXct("2023-08-31 00:00:00", format="%Y-%m-%d %H:%M:%S", tz="UTC")
newCalls <- filter(calls, (calls$Datetime > lowerThreshold & calls$Datetime < upperThreshold))

# Seattle Census Tracts GEOJSON 
geojson <- st_read("censusTracts.geojson")

# Format Columns
income$GEOID <- as.character(income$GEOID)
geojson$GEOID20 <- as.character(geojson$GEOID20)

# Left Join
merged <- geojson %>%
  left_join(income, by = c("GEOID20" = "GEOID"))

# Format GEOJSON
format_properties <- function(row) {
  return(list(
    OBJECTID = row$OBJECTID,
    GEOID20 = row$GEOID20,
    GROSS_ACRES = row$GROSS_ACRES,
    LAND_ACRES = row$LAND_ACRES,
    WATER_ACRES = row$WATER_ACRES,
    NAME = row$NAME,
    TRACT_NUMB = row$TRACT_NUMB,
    BASENAME = row$BASENAME,
    UVDA_AREA = row$UVDA_AREA,
    CRA_NO = row$CRA_NO,
    CRA_GRP = row$CRA_GRP,
    GEN_ALIAS = row$GEN_ALIAS,
    DETL_NAMES = row$DETL_NAMES,
    C_DISTRICT = row$C_DISTRICT,
    SHAPE_Length = row$SHAPE_Length,
    SHAPE_Area = row$SHAPE_Area,
    PCIAdjusted = row$PCIAdjusted,
    geometry = row$geometry
  ))
}

# Apply the function to each row
merged$properties <- purrr::map(1:nrow(merged), function(i) format_properties(merged[i, ]))

# Remove the original "properties" column
merged <- merged %>% select(-properties)

# Aggregating Per Capita Income data
merged <- merged %>%
  group_by(BASENAME, CRAName) %>%
  summarise(
    avg_income = mean(PCIAdjusted),
    total_population = sum(Population))

# Export the new GEOJSON to a temporary file
temp_file <- tempfile(fileext = ".geojson")
st_write(merged, temp_file, driver = "GeoJSON", delete_layer = TRUE)

# Move the temporary file to replace the original
file.rename(temp_file, "PCI.geojson")

# Finding PCI Natural Breaks

# Minimum
min <- min(merged$avg_income)

# Maximum 
max <- max(merged$avg_income)

# Natural Breaks Scheme
intervals <- classIntervals(merged$avg_income, n = 5, style = "jenks")
breaks <- intervals$brks
cat("Class Breaks:", breaks, "\n")