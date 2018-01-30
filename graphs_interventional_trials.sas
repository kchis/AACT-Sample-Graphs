/*
-----------------------------------------------------------------------------
Project:  AACT
Purpose:  Create some graphs showing characteristics of interventional studies over time
Source:   graphs_interventional_trials.sas
Author:   K. Chiswell, Duke Clinical Research Institute
Date:     2018/01/23

Note:  Run this program after running analdata.sas
-----------------------------------------------------------------------------
*/

options formdlim='-' 
        missing="" nofmterr
;


%let server = aact-db.ctti-clinicaltrials.org;

%let endyr = 2017;  * year when summary ends;

libname in "./" access=readonly;  * folder where analysis data is stored;
                            
%include "formats.sas";


/* --------------------------------------------------------------------------
   Analysis data
 -------------------------------------------------------------------------- */
data analdata;
   set in.analdata;
   run;

* get maximum nlm download date, date when AACT most recently updated, and number of studies and store as macro variable;
* this indicates when the records were current compared to ClinicalTrials.gov;
proc sql;
    create table nlmdt as
      select
        max(nlm_download_date) as max_nlm_date,
        max(aact_date) as max_aact_date,
        sum(study_type='Interventional') as numstudies,
        sum(siteloc=99) as numnosite,
        sum(siteloc in (1,2,3)) as numwisite,
        sum((comp_term > .) and (mntopcom_mod > .) and (phaseg > 0) ) as num2c,
        sum( (mntores_mod >.) and (results_reported >.) and (phaseg > 1) 
               and (intervg in (1, 3, 4)) and (us_site=1) and ( overall_statusn in (6, 7) ) ) as num2r
      from analdata;
quit; 

data nlmdt;
    set nlmdt;
    call symput('nlmdt', compress(put(max_nlm_date, date9.)));
    call symput('aactdt', compress(put(max_aact_date, date9.)));
    call symput('ns', compress(put(numstudies, best9.)));    
    call symput('nns', compress(put(numnosite, best9.)));    
    call symput('nws', compress(put(numwisite, best9.)));    
    call symput('nc', compress(put(num2c, best9.)));    
    call symput('nr', compress(put(num2r, best9.)));    
run;

/* --------------------------------------------------------------------------
   get Kaplan Meier event rates for graphs
 -------------------------------------------------------------------------- */

* for time to study completion or termination;
%let tt_evt=mntopcom_mod;
%let evt=comp_term;
%let group=phaseg;


ods listing close;
ods output productlimitestimates=kmrates;    
proc lifetest data=analdata method=pl ;
    where &evt > . and &tt_evt > . and phaseg>0 ; 

    strata &group;
    time &tt_evt * &evt (0);
    run;
ods listing;

data kmrates;
    set kmrates;
    if survival >.;
    kmrate = round (100 * (1 - survival), 0.01);
    run;
    
proc sort data=kmrates;
    by &group &tt_evt kmrate;
    run;
   


* for time to results reporting;
%let tt_evt=mntores_mod;
%let evt=results_reported;
%let group=funding;

ods listing close;
ods output productlimitestimates=kmrates2;    
proc lifetest data=analdata method=pl ;
    where phaseg>1 and intervg in (1, 3, 4) and us_site=1
      and overall_statusn in (6, 7)
      and &evt >. and &tt_evt >.;
    strata &group;
    time &tt_evt * &evt (0);
    run;
ods listing;

data kmrates2;
    set kmrates2;
    if survival >.;
    kmrate = round (100 * (1 - survival), 0.01);
    run;
    
proc sort data=kmrates2;
    by &group &tt_evt kmrate;
    run;



/* --------------------------------------------------------------------------
   Summaries - output graphics directly to pdf file
 -------------------------------------------------------------------------- */
options orientation=landscape nodate;

ods listing close;

ods pdf body="./graphs_interventional_trials.pdf" 
   nogtitle nogfootnote style=journal
   ;


* --- Registration by Funding ---;
title1 j=c "Summary of interventional studies registered at ClinicalTrials.gov from 2008-&endyr";

title2 j=c "Study Registration, Summarized by Source of Funding";

footnote1 j=l "Summaries based on &ns interventional studies.";
footnote2 j=l "Source of funding is derived from lead and collaborator information. If the lead sponsor was from industry or the study had industry collaborators without National Institutes of Health (NIH) involvement, the study was categorized as industry funded; if the NIH was involved as a sponsor or collaborator and the lead sponsor was not from industry, the study was classed as NIH funded; all other studies were classed as funded by nonindustry, non-NIH sources.";
footnote3 j=l "Extracted from &server (AACT) most recently updated on &aactdt, and based on content publicly released by NLM on &nlmdt..";
footnote4 j=l "Summaries generated by:  %sysget(PWD)/%sysfunc(scan(&SYSPROCESSNAME,2)).sas on &sysdate &systime..";

proc sgplot data=analdata
   nocycleattrs;
   styleattrs datacolors=(blue red orange green)
              datacontrastcolors=(blue red orange green)
              datalinepatterns=(solid shortdash dashdashdot mediumdash)
              datasymbols=(diamondfilled squarefilled starfilled circlefilled)
              ; 
   vline reg_year /
      response = countv
      stat = sum
      markers
      group = funding 
      ;
   yaxis label = 'Number of studies';
   run;


* --- Study Phase ---;
title2 j=c "Study Phase";

footnote1 j=l "Summaries based on &ns interventional studies.";
footnote2 j=l "Extracted from &server (AACT) most recently updated on &aactdt, and based on content publicly released by NLM on &nlmdt..";
footnote3 j=l "Summaries generated by:  %sysget(PWD)/%sysfunc(scan(&SYSPROCESSNAME,2)).sas on &sysdate &systime..";

proc sgplot data=analdata;
   hbar phase /
      fill nooutline
      stat = freq
      fillattrs = (color=blue transparency=0.5)
      ;
   xaxis label = 'Number of studies';
   yaxis display = (nolabel);
   run;


* --- Study Phase (grouped) ---;
title2 j=c "Study Phase (grouped)";

footnote1 j=l "Summaries based on &ns interventional studies. ";
footnote2 j=l "Extracted from &server (AACT) most recently updated on &aactdt, and based on content publicly released by NLM on &nlmdt..";
footnote3 j=l "Summaries generated by:  %sysget(PWD)/%sysfunc(scan(&SYSPROCESSNAME,2)).sas on &sysdate &systime..";

proc sgplot data=analdata;
   hbar phaseg /
      fill nooutline
      stat = freq
      fillattrs = (color=blue transparency=0.5)
      ;
   xaxis label = 'Number of studies';
   yaxis display = (nolabel);
   run;


* --- Registration by Phase (grouped) ---;
title2 j=c "Study Registration, Summarized by Phase (grouped)";

footnote1 j=l "Summary based on interventional trials, excluding Early Phase 1 trials.";
footnote2 j=l "Extracted from &server (AACT) most recently updated on &aactdt, and based on content publicly released by NLM on &nlmdt..";
footnote3 j=l "Summaries generated by:  %sysget(PWD)/%sysfunc(scan(&SYSPROCESSNAME,2)).sas on &sysdate &systime..";

proc sgplot data=analdata (where=(phaseg>0))
   nocycleattrs;
   styleattrs datacolors=(blue red orange green black)
              datacontrastcolors=(blue red orange green black)
              datalinepatterns=(solid shortdash dashdashdot mediumdash dashdotdot)
              datasymbols=(diamondfilled squarefilled starfilled circlefilled trianglefilled)
              ; 
   vline reg_year /
      response = countv
      stat = sum
      markers
      group = phaseg
      ;
   yaxis label = 'Number of studies';
   run;


* --- Intervention Types (grouped) ---;
title2 j=c "Study Intervention Type";

footnote1 j=l "A study can have more than one intervention type. Studies grouped into mutually exclusive categories according to the following hierarchy:  Device, Procedure, Biological, Drug, Behavioral, Dietary Supplement, Other (including diagnostic, radiation, genetic, and other intervention types).";
footnote2 j=l "Summaries based on &ns interventional studies.";
footnote3 j=l "Extracted from &server (AACT) most recently updated on &aactdt, and based on content publicly released by NLM on &nlmdt.";
footnote4 j=l "Summaries generated by:  %sysget(PWD)/%sysfunc(scan(&SYSPROCESSNAME,2)).sas on &sysdate &systime";

proc sgplot data=analdata;
   hbar intervg /
      fill nooutline
      stat = freq
      fillattrs = (color=blue transparency=0.5)
      ;
   xaxis label = 'Number of studies';
   yaxis display = (nolabel);
   run;


* --- Registration by Intervention Types (grouped) ---;
title2 j=c "Study Registration, Summarized by Intervention Types (grouped)";

footnote1 j=l "A study can have more than one intervention type. Studies grouped into mutually exclusive categories according to the following hierarchy:  Device/Procedure, Biological/Drug, Behavioral/Dietary Supplement, or Other (including diagnostic, radiation, genetic, and other intervention types).";
footnote2 j=l "Summaries based on &ns interventional studies.";
footnote3 j=l "Extracted from &server (AACT) most recently updated on &aactdt, and based on content publicly released by NLM on &nlmdt..";
footnote4 j=l "Summaries generated by:  %sysget(PWD)/%sysfunc(scan(&SYSPROCESSNAME,2)).sas on &sysdate &systime..";

proc sgplot data=analdata
   nocycleattrs;
   styleattrs datacolors=(blue red orange green black)
              datacontrastcolors=(blue red orange green black)
              datalinepatterns=(solid shortdash dashdashdot mediumdash dashdotdot)
              datasymbols=(diamondfilled squarefilled starfilled circlefilled trianglefilled)
              ; 
   vline reg_year /
      response = countv
      stat = sum
      markers
      group = intervh
      ;
   yaxis label = 'Number of studies';
   run;


* --- Registration by US FDA-regulated drug product ---;
title2 j=c "Study Registration, Summarized by Whether Trial Studies US FDA-regulated Drug Product";

footnote1 j=l "Summaries based on &ns interventional studies.";
footnote2 j=l "Extracted from &server (AACT) most recently updated on &aactdt, and based on content publicly released by NLM on &nlmdt..";
footnote3 j=l "Summaries generated by:  %sysget(PWD)/%sysfunc(scan(&SYSPROCESSNAME,2)).sas on &sysdate &systime..";

proc sgplot data=analdata
   nocycleattrs;
   styleattrs datacolors=(blue red orange green)
              datacontrastcolors=(blue red orange green)
              datalinepatterns=(solid shortdash dashdashdot mediumdash)
              datasymbols=(diamondfilled squarefilled starfilled circlefilled)
              ; 
   vline reg_year /
      response = countv
      stat = sum
      markers
      group = is_fda_regulated_drug_n 
      ;
   yaxis label = 'Number of studies';
   run;


* --- Registration by US FDA-regulated drug product (for >=2016) ---;
title2 j=c "Study Registration, Summarized by Whether Trial Studies US FDA-regulated Drug Product";

footnote1 j=l "This graph restricted to interventional studies registered >=2016";
footnote2 j=l "Extracted from &server (AACT) most recently updated on &aactdt, and based on content publicly released by NLM on &nlmdt..";
footnote3 j=l "Summaries generated by:  %sysget(PWD)/%sysfunc(scan(&SYSPROCESSNAME,2)).sas on &sysdate &systime..";

proc sgplot data=analdata (where=(reg_year >= 2016))
   nocycleattrs;
   styleattrs datacolors=(blue red orange green)
              datacontrastcolors=(blue red orange green)
              datalinepatterns=(solid shortdash dashdashdot mediumdash)
              datasymbols=(diamondfilled squarefilled starfilled circlefilled)
              ; 
   vline reg_year_month /
      response = countv
      stat = sum
      markers
      group = is_fda_regulated_drug_n 
      ;
   yaxis label = 'Number of studies';
   run;


* --- Registration by US FDA-regulated device product ---;
title2 j=c "Study Registration, Summarized by Whether Trial Studies US FDA-regulated Device Product";

footnote1 j=l "Summaries based on &ns interventional studies.";
footnote2 j=l "Extracted from &server (AACT) most recently updated on &aactdt, and based on content publicly released by NLM on &nlmdt..";
footnote3 j=l "Summaries generated by:  %sysget(PWD)/%sysfunc(scan(&SYSPROCESSNAME,2)).sas on &sysdate &systime..";

proc sgplot data=analdata
   nocycleattrs;
   styleattrs datacolors=(blue red orange green)
              datacontrastcolors=(blue red orange green)
              datalinepatterns=(solid shortdash dashdashdot mediumdash)
              datasymbols=(diamondfilled squarefilled starfilled circlefilled)
              ; 
   vline reg_year /
      response = countv
      stat = sum
      markers
      group = is_fda_regulated_device_n 
      ;
   yaxis label = 'Number of studies';
   run;


* --- Registration by US FDA-regulated device product (for >=2016) ---;
title2 j=c "Study Registration, Summarized by Whether Trial Studies US FDA-regulated Device Product";

footnote1 j=l "This graph restricted to interventional studies registered >=2016";
footnote2 j=l "Extracted from &server (AACT) most recently updated on &aactdt, and based on content publicly released by NLM on &nlmdt..";
footnote3 j=l "Summaries generated by:  %sysget(PWD)/%sysfunc(scan(&SYSPROCESSNAME,2)).sas on &sysdate &systime..";

proc sgplot data=analdata (where=(reg_year >= 2016))
   nocycleattrs;
   styleattrs datacolors=(blue red orange green)
              datacontrastcolors=(blue red orange green)
              datalinepatterns=(solid shortdash dashdashdot mediumdash)
              datasymbols=(diamondfilled squarefilled starfilled circlefilled)
              ; 
   vline reg_year_month /
      response = countv
      stat = sum
      markers
      group = is_fda_regulated_device_n 
      ;
   yaxis label = 'Number of studies';
   run;


* --- Registration by Site Location ---;
title2 j=c "Study Registration, Summarized by Study Site Locations (U.S and Rest of World (R.O.W.))";

footnote1 j=l "Summaries based on &ns interventional studies. Site Location based on facility addresses, and excludes locations that were previously removed from the study record. Central Contact information is not considered.";
footnote2 j=l "Extracted from &server (AACT) most recently updated on &aactdt, and based on content publicly released by NLM on &nlmdt..";
footnote3 j=l "Summaries generated by:  %sysget(PWD)/%sysfunc(scan(&SYSPROCESSNAME,2)).sas on &sysdate &systime..";

proc sgplot data=analdata 
   nocycleattrs;
   styleattrs datacolors=(blue red orange green black)
              datacontrastcolors=(blue red orange green black)
              datalinepatterns=(solid shortdash dashdashdot mediumdash dashdotdot)
              datasymbols=(diamondfilled squarefilled starfilled circlefilled trianglefilled)
              ; 
   vline reg_year /
      response = countv
      stat = sum
      markers
      group = siteloc
      ;
   yaxis label = 'Number of studies';
   run;


* --- Study Status for studies missing location in years >=2014  ---;
title4 j=c "Study Status for Studies Missing Location Information in 2014-&endyr";

footnote1 j=l "Summaries based on &nns interventional studies with missing site location information.";
footnote2 j=l "Extracted from &server (AACT) most recently updated on &aactdt, and based on content publicly released by NLM on &nlmdt..";
footnote3 j=l "Summaries generated by:  %sysget(PWD)/%sysfunc(scan(&SYSPROCESSNAME,2)).sas on &sysdate &systime..";

proc freq data=analdata;
   where reg_year >= 2014 and siteloc=99;
   tables overall_statusn * reg_year / nopercent norow;
   run;


* --- Registration by U.S. Location and Funding ---;
title2 j=c "Study Registration, Summarized by U.S. Location and Funding";

footnote1 j=l "Summaries based on &nws interventional studies with information about site locations (&nns studies without information about site locations are excluded from these figures). Funding source is derived from lead and collaborator information.";
footnote2 j=l "Extracted from &server (AACT) most recently updated on &aactdt, and based on content publicly released by NLM on &nlmdt..";
footnote3 j=l "Summaries generated by:  %sysget(PWD)/%sysfunc(scan(&SYSPROCESSNAME,2)).sas on &sysdate &systime..";

proc sgpanel data=analdata (where=(us_site >.))
   nocycleattrs;
   styleattrs datacolors=(blue red orange green black)
              datacontrastcolors=(blue red orange green black)
              datalinepatterns=(solid shortdash dashdashdot mediumdash dashdotdot)
              datasymbols=(diamondfilled squarefilled starfilled circlefilled trianglefilled)
              ; 
   panelby us_site / layout=columnlattice novarname sort=descending spacing=10;
   vline reg_year /
      response = countv
      stat = sum
      markers
      group = funding
      ;
   rowaxis label = 'Number of studies';
   run;


* --- Study Status ---;
title2 j=c "Study Status as Reported at ClinicalTrials.gov on &nlmdt";

footnote1 j=l "Summaries based on &ns interventional studies.";
footnote2 j=l "Extracted from &server (AACT) most recently updated on &aactdt, and based on content publicly released by NLM on &nlmdt..";
footnote3 j=l "Summaries generated by:  %sysget(PWD)/%sysfunc(scan(&SYSPROCESSNAME,2)).sas on &sysdate &systime..";

proc sgplot data=analdata;
   hbar overall_statusn /
      fill nooutline
      stat = freq
      fillattrs = (color=blue transparency=0.5)
      ;
   xaxis label = 'Number of studies';
   yaxis display = (nolabel);
   run;



* --- Registration by Appointment of a DMC ---;
title2 j=c "Study Registration, Summarized by Appointment of a Data Monitoring Committee (DMC)";

footnote1 j=l "Summaries based on &ns interventional studies.";
footnote2 j=l "Extracted from &server (AACT) most recently updated on &aactdt, and based on content publicly released by NLM on &nlmdt..";
footnote3 j=l "Summaries generated by:  %sysget(PWD)/%sysfunc(scan(&SYSPROCESSNAME,2)).sas on &sysdate &systime..";

proc sgplot data=analdata
   nocycleattrs;
   styleattrs datacolors=(blue red orange green)
              datacontrastcolors=(blue red orange green)
              datalinepatterns=(solid shortdash dashdashdot mediumdash)
              datasymbols=(diamondfilled squarefilled starfilled circlefilled)
              ; 
   vline reg_year /
      response = countv
      stat = sum
      markers
      group = dmc 
      ;
   yaxis label = 'Number of studies';
   run;



* --- Study Size (Median Enrollment) by Registration Year and Phase ---;
title2 j=c "Study Size (Median Enrollment), Summarized by Registration Date and Phase";

footnote1 j=l "Figure excludes Early Phase 1 studies. For completed/terminated studies the actual enrollment is reported. For ongoing studies the planned enrollment is reported.";
footnote2 j=l "Figure excludes studies missing enrollment information. For completed/terminated studies the actual enrollment is reported. For ongoing studies the planned enrollment is reported.";
footnote3 j=l "Extracted from &server (AACT) most recently updated on &aactdt, and based on content publicly released by NLM on &nlmdt..";
footnote4 j=l "Summaries generated by:  %sysget(PWD)/%sysfunc(scan(&SYSPROCESSNAME,2)).sas on &sysdate &systime..";

proc sgplot data=analdata (where=(enrollment>. and phaseg>0))
   nocycleattrs;
   styleattrs datacolors=(blue red orange green black)
              datacontrastcolors=(blue red orange green black)
              datalinepatterns=(solid shortdash dashdashdot mediumdash dashdotdot)
              datasymbols=(diamondfilled squarefilled starfilled circlefilled trianglefilled)
              ; 
   vline reg_year /
      response = enrollment
      stat = median
      markers
      group = phaseg
      ;
   yaxis label = 'Number of participants';
   run;



* --- KM curve for study completion/termation;
title2 'Time to Completion of Data Collection for Primary Endpoint (or Termination), Summarized by Phase (grouped)';

footnote1 j=l "Cumulative % of studies completing/terminated is estimated by Kaplan Meier method. Time is censored at the date when content was downloaded from ClinicalTrials.gov. Analysis is restricted to &nc interventional studies that are not Early Phase 1, withdrawn, studies not yet recruiting, and studies with start date after date content was downloaded from ClinicalTrials.gov.";
footnote2 j=l "Extracted from &server (AACT) most recently updated on &aactdt, and based on content publicly released by NLM on &nlmdt..";
footnote3 j=l "Summaries generated by:  %sysget(PWD)/%sysfunc(scan(&SYSPROCESSNAME,2)).sas on &sysdate &systime..";

proc sgplot data=kmrates (where=(kmrate>. )) aspect=0.8 pad=0 nocycleattrs;

    styleattrs datacontrastcolors=("blue" "red" "orange" "green" "black") 
              datalinepatterns=(solid shortdash dashdashdot mediumdash dashdotdot);

    step x=mntopcom_mod y=kmrate / justify=left group = phaseg name='failure' ;
    
    keylegend 'failure' /  location=inside position=bottomright noborder across=1 down=4 ;
    
    *** truncate time axis at 132 months;
    xaxis label="Months from study start" min=0  max=120 values=(0 12 24 36 48 60 72 84 96 108 120 132);   
    yaxis label="% Studies" min=0 max=100;

    run;



* --- KM curves for results reporting ---;
title2 'Time to Posting of Summary Results at ClinicalTrials.gov, Summarized by Source of Funding';

footnote1 j=l "Cumulative % of studies reporting results is estimated by Kaplan Meier method. Time is censored at the date when content was downloaded from ClinicalTrials.gov. Analysis is restricted to &nr interventional studies in Phase>1, with at least one US site and a drug/biological/device intervention, that were listed as Completed/Terminated when content was downloaded from ClinicalTrials.gov. Studies are excluded from analysis if they are missing both the primary completion and completion dates. Funding source is derived from lead and collaborator information.";
footnote2 j=l "Extracted from &server (AACT) most recently updated on &aactdt, and based on content publicly released by NLM on &nlmdt..";
footnote3 j=l "Summaries generated by:  %sysget(PWD)/%sysfunc(scan(&SYSPROCESSNAME,2)).sas on &sysdate &systime..";

proc sgplot data=kmrates2 (where=(kmrate>.)) nocycleattrs;

    styleattrs datacontrastcolors=("blue" "red" "orange" "green" "black") 
              datalinepatterns=(solid shortdash dashdashdot mediumdash dashdotdot);

    step x=mntores_mod y=kmrate / justify=left group = funding name='failure' ;
    
    keylegend 'failure' /  location=inside position=bottomright noborder across=1 down=4 ;
    
    *** truncate time axis at 108 months (9 years);
    xaxis label="Months from primary completion date" min=0  max=96 values=(0 12 24 36 48 60 72 84 96 108);   
    yaxis label="% Studies" min=0 max=100;

    run;


* --- Registration by Plan to Share IPD ---;
title2 j=c "Study Registration, Summarized by Whether Trial has Plan to Share Individual Participant Data";

footnote1 j=l "Summaries based on &ns interventional studies.";
footnote2 j=l "Extracted from &server (AACT) most recently updated on &aactdt, and based on content publicly released by NLM on &nlmdt..";
footnote3 j=l "Summaries generated by:  %sysget(PWD)/%sysfunc(scan(&SYSPROCESSNAME,2)).sas on &sysdate &systime..";

proc sgplot data=analdata
   nocycleattrs;
   styleattrs datacolors=(blue red orange green)
              datacontrastcolors=(blue red orange green)
              datalinepatterns=(solid shortdash dashdashdot mediumdash)
              datasymbols=(diamondfilled squarefilled starfilled circlefilled)
              ; 
   vline reg_year /
      response = countv
      stat = sum
      markers
      group = plan_to_share_ipd_n
      ;
   yaxis label = 'Number of studies';
   run;

ods listing;         

ods pdf close;


