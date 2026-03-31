library(tidyverse)
library(dplyr)
library(ggplot2)
library(skimr)
library(lubridate)
library(stringr)

# Load the raw data 
residential_data <- read.csv("data/raw/residential-data.csv")
summary(residential_data)

# Changing ID as abbreviation to capitals
residential_data <- residential_data %>% 
  rename(ID = id)

length(unique(residential_data$ID))
# residential data is not likely available for many participants as this is < 3080 IDs.

# column headings are otherwise consistent and meaningful
str(residential_data)

# Dates need to be transformed to date type from character, other variables are of correct type
residential_data$address_start_date <- ymd(residential_data$address_start_date)
residential_data$address_end_date <- ymd(residential_data$address_end_date)
residential_data$entry_date <- ymd(residential_data$entry_date)

str(residential_data) # all variables are of correct type now

# Checking for missing values or empty strings - no issues
colSums(is.na(residential_data))
colSums(residential_data[sapply(residential_data, is.character)] == "")

# Sense check for chronological consistency of date
# Check for rows where start date is after end date
# today’s date
today_date <- Sys.Date()


invalid_dates <- residential_data %>%
  filter(address_start_date > address_end_date |
           today_date < address_start_date |
           today_date < address_end_date)

# How many rows are invalid and flagging these
nrow(invalid_dates)
head(invalid_dates)

residential_data <- residential_data %>% 
  mutate(address_date_issue = address_start_date > address_end_date |
           today_date < address_start_date |
           today_date < address_end_date)

# removing these problematic address rows
residential_data <- residential_data %>% 
  filter(address_date_issue == FALSE) %>% 
  select(-address_date_issue)
  
# Checking for full duplicates - no issues
sum(duplicated(residential_data))



# tabulating states and counties
table(residential_data$state) # there is a problematic entry which is Country of Mexico (we are interested in US data only)

table(residential_data$county) # there is a problematic entry which is a Mexican State and then there is 
# unnecessary capitalization of SONORA

residential_data <- residential_data %>%
  mutate(
    county = str_to_title(county)  # converts "SONORA" → "Sonora"
  )
residential_data <- residential_data %>%
  filter(state != "Country of Mexico") # removed Mexico entry

# Applying part of inclusion criteria that residential data in the 10 years prior index date (entry date is available) are of interest

residential_data <- residential_data %>%
  mutate(
    window_start = entry_date - years(10),
    window_end   = entry_date,
    # flag if the address overlaps the 10-year window
    overlaps_10yr_window = (address_end_date >= window_start) & (address_start_date <= window_end)
  )

# Removing the non-overlapping address periods
residential_data <- residential_data %>% 
  filter(overlaps_10yr_window == TRUE) %>% 
  select(-overlaps_10yr_window)

# Truncating to ensure the address state date (if it starts from before the 10 year prior entry date point) begins at entry date
residential_data <- residential_data %>%
  mutate(
    address_start_date = pmax(address_start_date, entry_date - years(10)),
    address_end_date   = pmin(address_end_date, entry_date)
  ) %>% 
  select(-window_start,-window_end) %>% 
  rename(
    exposure_start_date = address_start_date,
    exposure_end_date = address_end_date
  ) %>% 
  select(-entry_date)

# Count rows per patient
address_counts <- residential_data %>%
  count(ID, name = "n_addresses")

# How many patients have more than 1 address
sum(address_counts$n_addresses > 1)

# table of counts
table(address_counts$n_addresses)

# Must also whether residential data is available for the 10 year period
# Compute total days of coverage per patient
residential_coverage <- residential_data %>%
  group_by(ID) %>%
  summarise(
    total_days = sum(as.numeric(exposure_end_date - exposure_start_date) + 1),  # +1 to include both start/end
    total_years = total_days / 365.25
  ) %>%
  ungroup()

residential_coverage %>%
  filter(total_years < 9.9) # a cutoff of 9.9 years is used to allow room for rounding approximations and considering it is very close to 10 years

residential_data <- residential_data %>%
  left_join(
    residential_coverage %>% select(ID, total_years),
    by = "ID"
  ) %>%
  mutate(
    coverage_flag = ifelse(total_years < 9.9, "insufficient coverage", "sufficient coverage")
  )

# Finally checking if there are any gaps for patients who have more than one address
residential_sorted <- residential_data %>%
  arrange(ID, exposure_start_date)

residential_continuity <- residential_sorted %>%
  group_by(ID) %>%
  mutate(
    prev_end = lag(exposure_end_date),                     # previous address end date
    gap_days = as.numeric(exposure_start_date - prev_end) - 1  # days between addresses
  ) %>%
  ungroup()

residential_continuity %>%
  filter(!is.na(gap_days) & gap_days > 0) # returns 0

# All address data for patients who moved is complete
selected_residential_data <- residential_data
