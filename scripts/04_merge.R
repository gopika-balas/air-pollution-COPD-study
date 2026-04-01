library(tidyverse)
library(dplyr)
library(ggplot2)
library(skimr)
library(lubridate)

final_dataset <- selected_cohort_data %>%
  left_join(icd_patient_data, by = "ID") %>%
  left_join(selected_residential_data, by = "ID")

write_xlsx(final_dataset, "data/cleaned/final_dataset.xlsx")