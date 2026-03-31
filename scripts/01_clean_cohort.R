library(tidyverse)
library(dplyr)
library(ggplot2)
library(skimr)
library(lubridate)

# Load the raw data 
cohort_data <- read.csv("data/raw/cohort-data.csv")

# Inspect high level data characteristics using summary, str, and skim functions
summary(cohort_data)
str(cohort_data)
skim(cohort_data)
head(cohort_data)

# Already we can see some issues such an impossible age entry '345', inconsistent header names and date reporting
# Will check through all data quality indicators step by step
###------------------------------------------------------------------------------
# (Check - 1) Analyzable 
# - Data organized in predictable structure
# - First row has variable names (headers of columns)
# - All other rows contain data values (one observation per row)
# - At least one column has a unique identifier (for each row)
# - There is no usage of symbols, colours, or formatting to convey meaning
# - No combination of information in single cells


# There are 8 columns in the cohort-data, which matched the expected columns in the data dictionary
# The names of some column headers are inconsistent and need fixing, will fix as per data dictionary
# There seem to be 3080 IDs but 3088 rows which suggests some duplication

cohort_data <- cohort_data %>% 
  rename(age = Age,
         sex = SEX..1.MALE.,
         smoking_status = SMOKE,
         follow_up_date = DATE_losstofollowup,
         entry_date = entrydate)


# Checking for duplicates in the unique identifier column
nrow(cohort_data) == length(unique(cohort_data$ID))

# FALSE, indicates clearly that there are some duplicate rows

# Observe which rows are duplicated
cohort_data %>%
  group_by(ID) %>%
  filter(n() > 1) %>%        # keep only duplicate IDs
  arrange(ID, entry_date) %>% # order by ID and optionally by date
  ungroup() 

# Exact duplicates removed as they are likely to be data entry errors

cohort_data <- cohort_data %>% 
  distinct()
# Confirming no more duplicates persist, should give us TRUE
nrow(cohort_data) == length(unique(cohort_data$ID))

# There are no cells with combined information

###-----------------------------------------------------------------------------
# (Check-2) Interpretable
# - Each variable name must be unique.
# - Names must not contain spaces or special characters, with the exception of underscores (_). Avoid periods (.) or hyphens (-).
# - Names must not begin with a number.
# - Names should not exceed 32 characters.
# - Names should be meaningful and descriptive.
# - Capitalization and delimiters should be applied consistently throughout.
# - When variable names follow a structured order, apply it consistently (e.g., avoid mixing phq9_item1 and item2_phq9).

# All variable names pass check 2 after renaming in the earlier section.

###-----------------------------------------------------------------------------
# (Check - 3) Complete
# - No missing cases
# - No duplicate cases
# - Unless in long format, number of rows in dataset must match expected sample size
# - Number of columns in the dataset should total intended number
# - Cross check data with data dictionary to confirm that no expected columns are missing

# Duplicate cases (exact duplicates of full rows) have been removed already

# Checking if there are missing values in any of the columns for any observation
colSums(is.na(cohort_data) | (cohort_data == "" & !sapply(cohort_data, is.numeric)))

# No expected columns are missing, crosschecked with data dictionary
# No information on the sample size expected, so unable to validate that part

###-----------------------------------------------------------------------------

# # (Check - 4) - Valid
# - Variable types align with expectations (e.g., numeric, character, date)
# - Variable values and ranges match plan / expectation (e.g., 1–5 for Likert scales)
# - Item-level missingness follows universe rules and skip patterns

# ID is as integer which is okay and ranges from 1 to 3080
# Age is as integer but we know there are some definite outliers like 345, so visualize and flag this as problematic
# and change age to numeric as per data dictionary
boxplot(cohort_data$age)
# We can flag this observation in the flag column
cohort_data <- cohort_data %>% 
  mutate(age_flag = ifelse(age < 0 | age > 120, 
                       "outlier age", NA_character_))
cohort_data$age <- as.numeric(cohort_data$age)

# Sex should be changed to Male and Female as per data dictionary instead of 0 and 1, however there is no available information
# on the coding, so leaving it as is but changing it to a factor
cohort_data$sex <- factor(cohort_data$sex)
table(cohort_data$sex)

# BMI is numeric and ranges from 15 to 40 which is plausible
boxplot(cohort_data$bmi) 

# Socioeconomic data - checking how the entries are made and converting to factor
unique(cohort_data$socioeconomic_status)
cohort_data$socioeconomic_status <- factor(cohort_data$socioeconomic_status,
                                           levels = c("Low", "Medium", "High"))

# Smoke data - checking how the entries are made and converting to factor

unique(cohort_data$smoking_status) # we can see that there are inconsistencies in capitalization
cohort_data <- cohort_data %>% 
  mutate(smoking_status = recode(smoking_status,
                        "former" = "Former",
                        "never" = "Never",
                        "current" = "Current")) 
cohort_data$smoking_status <- factor(cohort_data$smoking_status,
                            levels = c("Never", "Former", "Current"))

# Dates are very inconsistent - some seem to be coded as MM/DD/YYYY (based on the fact that months cannot exceed 12)
# However that does not guarantee all values where days is between 1- 12 is also coded as MM/DD/YYYY - we can flag this and check with the data entry system
# if indeed all have been entered as MM/DD/YYYY (if a slash is included at all in the date). Other strings cannot be safely converted as there is no documentation on what they represent.

cohort_data$clean_entry_date <- as.Date(NA)

# Find rows that contain a slash (MM/DD/YYYY)
slash_rows <- grep("/", cohort_data$entry_date)

# Convert only those rows to Date
cohort_data$clean_entry_date[slash_rows] <- as.Date(
  cohort_data$entry_date[slash_rows],
  format = "%m/%d/%Y"
)

# Similarly for date of loss to follow up

cohort_data$clean_follow <- as.Date(NA)

# Find rows that contain a slash (MM/DD/YYYY)
slash_rows_follow <- grep("/", cohort_data$follow_up_date)
# Convert only those rows to Date
cohort_data$clean_follow[slash_rows_follow] <- as.Date(
  cohort_data$follow_up_date[slash_rows_follow],
  format = "%m/%d/%Y"
)

# Flagging unclear dates in the date_flag column, renaming clean date columns 
# with appropriate name and replacing original unformatted date columns
cohort_data <- cohort_data %>%
  mutate(
    date_flag = ifelse(is.na(clean_entry_date) | is.na(clean_follow), "dates unclear", NA),
    entry_date = clean_entry_date,
    follow_up_date = clean_follow
  ) %>%
  select(-clean_entry_date, -clean_follow)


###-----------------------------------------------------------------------------

# (Check-5) Accurate
# - Data adhere to expectations based on implicit knowledge
# - Cross check related variables for consistency
# 
# (Check-6) Consistent
# - Variables are consistently measured, formatted, or categorized within a column
# - If same variables are collected across multiple data sources, it should be measured and formatted identically 
# 
# (Check-77) De-identified
# - No direct identifiers in data
# - Assess and minimise indirect identifiers as needed

# Related variables of entry date and loss to follow up date were crosschecked to ensure chronological order
cohort_data %>%
  filter(!is.na(entry_date) & !is.na(follow_up_date) & follow_up_date < entry_date)
# Zero here ensures chronological order is maintained

# Confirming all data types are as needed per column across all columns
str(cohort_data)

# No direct de-identifiers are identified in the data 

# To check if there are any small group sizes

table(
  cohort_data$sex,
  cohort_data$socioeconomic_status,
  cohort_data$smoking_status
)

# for continuous variables - age and bmi boxplots did not identify a single outlier except 345 years age which is flagged, 
# other outlier values are clustered and therefore less 
hist(cohort_data$age, breaks = 50, main = "Age histogram", xlab = "Age")
hist(cohort_data$bmi, breaks = 50, main = "BMI histogram", xlab = "BMI")

# Age histogram with counts
age_hist <- hist(cohort_data$age, breaks = 50, main = "Age histogram", xlab = "Age")
data.frame(
  bin_start = age_hist$breaks[-length(age_hist$breaks)],
  bin_end   = age_hist$breaks[-1],
  count     = age_hist$counts
)

# Note there are no small counts in categories over 40 years which will be the included data in the final dataset

# BMI histogram with counts
bmi_hist <- hist(cohort_data$bmi, breaks = 50, main = "BMI histogram", xlab = "BMI")
data.frame(
  bin_start = bmi_hist$breaks[-length(bmi_hist$breaks)],
  bin_end   = bmi_hist$breaks[-1],
  count     = bmi_hist$counts
)

# There are no very small counts in BMI categories

# Now applying the inclusion exclusion criteria for cohort data (as applicable to this portion of the data)
# entry_date must be between January 1st 2005 and December 31st 2010
# patients must be 40 years or older at index date

selected_cohort_data <- cohort_data %>%
  filter(
    entry_date >= as.Date("2005-01-01") & entry_date <= as.Date("2010-12-31"),
    age >= 40
  )

all(is.na(selected_cohort_data$age_flag))
all(is.na(selected_cohort_data$date_flag))
# there are no entries in age or date flag for the selected cohort data so we will remove these columns

selected_cohort_data <- selected_cohort_data %>% 
  select(-age_flag,-date_flag)

