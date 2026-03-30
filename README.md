# Air pollution and COPD study

## Project Overview & Objective

This repository contains materials for a retrospective cohort study assessing the association between long-term air pollution exposure (as measured by Air Quality Index) and the incidence of COPD among U.S. adults using EHR data. 
It includes the data cleaning plan, raw and cleaned datasets, annotated R scripts, and supporting documentation required to produce a merged, reproducible, analysis-ready dataset (with participant-level, diagnostic, and residential variables). 

## Project Structure

```
air-pollution-COPD-study/
├── data/
│   ├── raw/
│   │   ├── cohort-data.csv # Data containing individual ID, demographic, lifestyle/health status factors, and follow-up information
│   │   ├── icd-data.csv # EHR data with ID, entry date, and diagnosis information
│   │   └── residential-data.csv # Residential history including address and start/end dates
│   └── cleaned/
│       └── final-COPD-study-data.csv # final cleaned and merged analysis-ready dataset
├── scripts/
│   ├── 01_clean_cohort.R # script to clean cohort-data.csv
│   ├── 02_clean_icd.R # script to clean icd-data.csv
│   ├── 03_clean_residential.R # script to clean residential-data.csv
│   └── 04_merge_data.R # script to produce a merged dataset from cleaned cohort, icd, and residential data
├── documentation/
│   ├── pre_analysis_data_dictionary.pdf # data dictionary explaining all variables in the raw datasets
│   ├── data_cleaning_plan.pdf # detailed data cleaning plan including applied inclusion / exclusion criteria, data quality checks, and notes on missingness and transformations
│   ├── data_cleaning_plan.Rmd # associated R markdown file
│   └── final_data_dictionary.pdf # data dictionary explaining all variables in analysis-ready dataset (final-COPD-study-data.csv)
├── outputs/ # intermediate datasets (pre-merging), plots and tables for checking distributions and data quality
└── README.md # quick overview of project structure and data cleaning workflow
```

## Data Sources

 1. cohort-data.csv contains participant-level information including demographic info, lifestyle info and follow-up dates
 2. icd-data.csv contains diagnostic codes recording comorbidities and COPD diagnoses over time
 3. residential-data.csv contains county-level residential history for each participant, recording address periods with start and end dates

Note that the Air Quality Index dataset is standalone and not included here currently.

## Inclusion / Exclusion Criteria

To be included in the study, participants must meet the following eligibility criteria at their index date:

1. Cohort entry date falls within the index period (January 1, 2005 to December 31, 2010)
2. Age 40 years or older at index date
3. Residential data available in the 10 years prior to the index date (long-term exposure is of interest)
  (exposure assessment period from January 1, 1995)
4. EHR linkage in the year prior to and at least 30 days after the index date

## Variables and Covariates Overview 

Across the three datasets, the following information is available:

1. Demographic: participant ID, socioeconomic status
2. Lifestyle/health status: smoking status, BMI
3. Residential: county, residence start and end dates

Note: Refer to pre_analysis_data_dictionary.pdf within documentation/ to access data dictionary of variables included in the raw pre-analysis cohort, icd, and residential datasets

## Data Cleaning Workflow Overview

Steps 1 to 5 were carried out as part of the data cleaning workflow.

Refer to documentation/data_cleaning_plan.pdf for detailed notes on data cleaning and preparation. A high level overview is presented here.

Goal: To transform raw datasets into analysis ready merged dataset that adhere to documented inclusion / exclusion criteria and data quality checks.

1. Each of the three raw datasets (cohort, icd, and residential data) were checked for data quality
2. Inclusion criteria were appropriately applied and observations matching criteria were filtered for
3. All three datasets were merged appropriately into one dataset
4. Final dataset was checked against the data quality indicators outlined in step A.
5. Creation of data dictionary corresponding to finalised dataset 
  

## Reproducibility

R version used was R version 4.5.1 (2025-06-13).
The following R packages need to be installed:
tidyverse, dplyr, ggplot2

### Steps to reproduce the analysis-ready dataset

1. Open air-pollution-COPD-study.Rproj and use as working directory. All scripts use relative paths.
2. Place raw datasets in data/raw
3. Run the scripts in numbered order from 01 to 04:
  3.1. 01_clean_cohort.R
  3.2. 02_clean_icd.R
  3.3. 03_clean_residential.R
  3.4. 04_merge_data.R
4. Save final cleaned dataset in data/cleaned/final-COPD-study-data.csv
5. Save any intermediate outputs such as intermediate datasets (pre-merging)summary tables and plots to outputs/
6. To generate data cleaning PDF, render the R markdown file  documentation/data_cleaning_plan.Rmd

