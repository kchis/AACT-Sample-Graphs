# AACT-Sample-Graphs
This repository includes example graphs summarizing characteristics of interventional trials in ClinicalTrials.gov, 2008-2017

Using the programs shared in this repository, I have summarized selected characteristics and time trends in interventional trials registered at ClinicalTrials.gov between 2008-2017 using the database for Aggregate Analysis of ClinicalTrials.gov (AACT), available at http://aact.ctti-clinicaltrials.org/.  I accessed the live AACT database and generated graphical summaries of the trial portfolio using SAS v. 9.4 on a Linux operating system. SAS code and output fiiles are shared in this repository.

Description of programs:
-  formats.sas:  This program defines SAS formats and is sourced by other SAS programs.
-  analdata.sas:  This program extracts records and variables from AACT and outputs a permanent SAS dataset 'analdata.sas7bdat' that is used to create the graphs. This program also outputs a summary of the number of studies excluded from the analysis to the file 'exclusions_for_graphs_interventional_trials.pdf'. 
-  graphs_interventional_trials.sas:  This program reads the dataset 'analdata.sas7bdat' created by 'analdata.sas' and outputs a graphical summary of the characteristics of interventional trials registered with ClinicalTrials.gov during the period of interest. This program creates the output file 'graphs_interventional_trials.pdf'.

Run programs in this order:  formats.sas -> analdata.sas -> graphs_interventional_trials.sas.

CAUTION:  Because AACT is a live database, the output created when the above programs are re-run will likely be slightly different than the results displayed in the output files included in this repository.
