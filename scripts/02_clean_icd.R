library(tidyverse)
library(dplyr)
library(ggplot2)
library(skimr)
library(lubridate)
library(writexl)

# Load the raw data 
icd_data <- read.csv("data/raw/icd-data.csv")


# Inspect high level data characteristics using summary, str, and skim functions
# Notice that date columns need to be of correct variable type
summary(icd_data)
str(icd_data)
skim(icd_data)
head(icd_data)



# Data column headers are mostly consistently and meaningfully named, will just change id to capitalised font as it is an abbreviation to match the cohort data
# also changing icd_date to icd_diagnosis_date to be more meaningful
icd_data <- icd_data %>% 
  rename(ID = id,
         icd_diagnosis_date = icd_date)

length(unique(icd_data$ID)) # starting with 3080 patients

# Checking for fully duplicate rows
sum(duplicated(icd_data))
# there are no fully duplicate rows

# no expected columns are missing

# checking for missing values or empty strings
colSums(is.na(icd_data))
colSums(icd_data[sapply(icd_data, is.character)] == "")
# no issues identified

# ID is as integer which is okay and ranges from 1 to 3080

# Converting ehr_entry_date and icd_date to date format
icd_data$ehr_entry_date <- ymd(icd_data$ehr_entry_date)
icd_data$icd_diagnosis_date <- ymd(icd_data$icd_diagnosis_date)

# checking data types now
str(icd_data)
# aligned with expectations

# checking chronologic consistency - diagnosis date does not precede ehr_entry date


icd_data %>%
  filter(icd_diagnosis_date < ehr_entry_date)
# checked

# plotting ehr entry date vs. icd diagnoses date shows expected trend however, there might be some issues with
# certain diagnosis dates being beyond current date
ggplot(icd_data, aes(x = ehr_entry_date, y = icd_diagnosis_date)) +
  geom_point(alpha = 0.3) +
  labs(
    title = "Scatter of Cohort Entry vs ICD Diagnosis Dates",
    x = "EHR Entry Date",
    y = "ICD Diagnosis Date"
  ) +
  theme_minimal()

# today’s date
today_date <- Sys.Date()

# any dates after today
icd_data %>%
  filter(ehr_entry_date > today_date)

icd_data %>%
  filter(icd_diagnosis_date > today_date)

icd_data <- icd_data %>%
  mutate(
    future_date_flag = ifelse(icd_diagnosis_date > Sys.Date(), 
                              "diagnosis date in future", 
                              NA_character_)
  ) 


# No direct de-identifiers are identified in the data 

# To check if there are any small group sizes (few patients with select diagnoses)
unique_patient_counts <- icd_data %>%
  distinct(ID, icd_code) %>%   # only one row per patient per ICD
  count(icd_code)              # number of unique patients per ICD

unique_patient_counts
# enough patients present across various diagnoses

table(icd_data$description)
# There are no inconsistent namings in description column

# For this dataset we are only interested in particular diagnoses so we can filter for those

icd_codes_required <- c(
  "E11.9", "E11.65", "E11.3X", "E11.4X",  # Type 2 Diabetes
  "I10", "I11.9", "I12.9",                # Hypertension
  "J45.0", "J45.1", "J45.9",              # Asthma
  "J44.0", "J44.1", "J44.9"               # COPD
)

selected_icd_data <- icd_data %>% 
  filter(icd_code %in% icd_codes_required) %>%  # filtering for desired icd codes and removing problematic diagnoses future dates reduces the observations from 20201 to 18503
  filter(is.na(future_date_flag)) %>% 
  select(-future_date_flag)

# no of patients at this stage left are 1630
length(unique(selected_icd_data$ID))

# Checking for EHR linkage in the year prior and at least 30 days after index date

selected_icd_data <- selected_icd_data %>%
  left_join(
    selected_cohort_data %>% select(ID, entry_date),
    by = "ID"
  )

# applying criteria for minimum EHR linkage (1 year prior and at least 30 days after) 
selected_icd_data <- selected_icd_data %>%
  mutate(
    pre_entry_window  = icd_diagnosis_date >= (entry_date - years(1)) & icd_diagnosis_date < entry_date,
    post_entry_window = icd_diagnosis_date >= (entry_date + days(30))
  )


patients_ok <- selected_icd_data %>%
  group_by(ID) %>%
  summarise(
    has_pre  = any(pre_entry_window, na.rm = TRUE),
    has_post = any(post_entry_window, na.rm = TRUE)
  ) %>%
  filter(has_pre & has_post) %>%   # only keep patients with at least one record in each window
  pull(ID)

selected_icd_data <- selected_icd_data %>%
  filter(ID %in% patients_ok) %>% 
  select(-pre_entry_window, -post_entry_window)


length(unique(selected_icd_data$ID))

# applying the EHR linkage criteria reduced the patients to 324

####-------------------------------------------------------------


# Define ICD codes for conditions
copd_codes       <- c("J44.0", "J44.1", "J44.9")
asthma_codes     <- c("J45.0", "J45.1", "J45.9")
diabetes_codes   <- c("E11.9", "E11.65", "E11.3X", "E11.4X")
hypertension_codes <- c("I10", "I11.9", "I12.9")

# Incident COPD after entry_date
copd_incident <- selected_icd_data %>%
  filter(icd_code %in% copd_codes) %>%             
  filter(icd_diagnosis_date >= entry_date) %>%     # after study entry
  group_by(ID) %>%
  summarise(
    incident_COPD = 1,
    copd_incident_date = min(icd_diagnosis_date),
    .groups = "drop"
  )

# Comorbidities at or before entry_date
comorbidities <- selected_icd_data %>%
  group_by(ID) %>%
  summarise(
    asthma       = as.integer(any(icd_code %in% asthma_codes & icd_diagnosis_date <= entry_date)),
    diabetes     = as.integer(any(icd_code %in% diabetes_codes & icd_diagnosis_date <= entry_date)),
    hypertension = as.integer(any(icd_code %in% hypertension_codes & icd_diagnosis_date <= entry_date)),
    .groups = "drop"
  )

# Merge into patient-level dataset
icd_patient_data <- selected_icd_data %>%
  select(ID, entry_date) %>%
  distinct() %>%             # one row per patient
  left_join(copd_incident, by = "ID") %>%
  left_join(comorbidities, by = "ID") %>%
  mutate(
    incident_COPD = ifelse(is.na(incident_COPD), 0, incident_COPD)
  ) %>% 
  select(-entry_date)

# View patient-level summary
head(icd_patient_data)

write_xlsx(icd_patient_data, "outputs/icd_patient_data.xlsx")
