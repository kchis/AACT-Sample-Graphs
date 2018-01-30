/*
-----------------------------------------------------------------------------
Project:  AACT
Purpose:  Create analysis dataset to use for summary graphs
Source:   analdata.sas
Author:   K. Chiswell, Duke Clinical Research Institute
Date:     2018/01/23
-----------------------------------------------------------------------------
*/

options formdlim='-';

%let endyr = 2017;  * year when summary ends;

libname out "./";   * folder where the data set will be written;

%include "formats.sas";                            

/* --------------------------------------------------------------------------
   For most up to date connection information refer to:
   http://aact.ctti-clinicaltrials.org/connect
 -------------------------------------------------------------------------- */

%let server = aact-db.ctti-clinicaltrials.org;

*  specify the credentials for the postgres database;
libname  
    aact              
    postgres
    user="aact"
    password="aact"
    database="aact"
    server="&server"
    port=5432
    dbmax_text=32767
    preserve_tab_names=yes
    access=readonly
;


* get most recent date of NLM content;
proc sql;
    create table nlmdt as
      select
        max(nlm_download_date) as max_nlm_date
      from aact.calculated_values;
quit; 

data nlmdt;
    set nlmdt;
    call symput('nlmdt', compress(put(max_nlm_date, date9.)));
run;

/* --------------------------------------------------------------------------
   Extract records and derive variables for snapshot slides
 -------------------------------------------------------------------------- */
%macro makemissing(varname, varlabel);
* code missing values of character 0/1 variable as numeric and assign missing values to 99;
   if &varname = "" then &varname._n=99;
   else if &varname = "1" then &varname._n=1;
   else if &varname = "0" then &varname._n=0;

   label &varname._n = "&varlabel";
   format &varname._n ynuf.;
%mend makemissing;

data analdata 
     ex_type ex_year;

   set aact.studies 
      (keep = 
         nct_id 
         study_type 
         study_first_submitted_date 
         start_date start_date_type
         updated_at 
         phase 
         overall_status
         has_dmc 
         enrollment enrollment_type
         primary_completion_date primary_completion_date_type 
         completion_date completion_date_type 
         results_first_submitted_date

         /* new data elements */
         /* many of these added for Final Rule implementation in Jan 2017 */
         is_fda_regulated_drug
         is_fda_regulated_device
         is_unapproved_device
         is_ppsd
         is_us_export
         
         /* other newish data elements */
         plan_to_share_ipd
       );

   * --- derivations ---;   

   * download_date;
   download_date = input("&nlmdt", date9.);
   format download_date date9.;
   label download_date = 'Date when content was released from ClinicalTrials.gov';

   * registration year;
   reg_year = year(study_first_submitted_date);
   label reg_year = "Year study registered at ClinicalTrials.gov";

   * registration month;
   reg_month = month(study_first_submitted_date);
   label reg_month = "Month study registered at ClinicalTrials.gov";

   * registration year_month as character;
   length reg_year_month $7;
   reg_year_month = put(reg_year, 4.)||"-"||put(reg_month, 2.);
   label reg_year_month = "Year-Month study registered at ClinicalTrials.gov";

   * date when AACT was updated;
   aact_date = datepart(updated_at);
   format aact_date date9.;
   label aact_date = "Date when record was updated in AACT";

   * categorize missing values of has_dmc;
   if has_dmc='' then dmc=99;
   else dmc=input(has_dmc, best8.);
   label dmc = 'DMC appointed';
   format dmc ynuf.;

   * create numeric code for overall_status (for ordering on graphs);
   if overall_status='Not yet recruiting' then overall_statusn=1;
   else if overall_status='Recruiting' then overall_statusn=2;
   else if overall_status='Enrolling by invitation' then overall_statusn=3;
   else if overall_status='Active, not recruiting' then overall_statusn=4;
   else if overall_status='Suspended' then overall_statusn=5;
   else if overall_status='Terminated' then overall_statusn=6;
   else if overall_status='Completed' then overall_statusn=7;
   else if overall_status='Withdrawn' then overall_statusn=8;
   else if overall_status='Unknown status' then overall_statusn=99;
   label overall_statusn = 'Overall Study Status';
   format overall_statusn statusf.;

   * group phase variable for graphs;
   if phase='Early Phase 1' then phaseg=0;
   else if phase = 'Phase 1' then phaseg=1;
   else if phase in ('Phase 1/Phase 2', 'Phase 2') then phaseg=2;
   else if phase in ('Phase 2/Phase 3', 'Phase 3') then phaseg=3;
   else if phase = 'Phase 4' then phaseg=4;
   else if phase = 'N/A' then phaseg=99;
   label phaseg = 'Study Phase';
   format phaseg phasef.;

   * categorize missing values of final rule variables;
   %makemissing(varname=is_fda_regulated_drug, varlabel=Studies a US FDA regulated drug product);
   %makemissing(varname=is_fda_regulated_device, varlabel=Studies a US FDA regulated device product);
   %makemissing(varname=is_unapproved_device, varlabel=Device product not approved or cleared);
   %makemissing(varname=is_ppsd, varlabel=Pediatric post market surveillance of device product);
   %makemissing(varname=is_us_export, varlabel=Product manufactured in and exported from US);   
   
   * make numeric version of plan_to_share_ipd;
   plan_to_share_ipd_n=.;
   label plan_to_share_ipd_n = 'Plan to share Individual Participant Data';
   format plan_to_share_ipd_n ynduf.;
   if plan_to_share_ipd = "No" then plan_to_share_ipd_n=0;
   else if plan_to_share_ipd = "Yes" then plan_to_share_ipd_n=1;
   else if plan_to_share_ipd = "Undecided" then plan_to_share_ipd_n=2;
   else if plan_to_share_ipd = "" then plan_to_share_ipd_n=99;


   * --- define variables for time to study completion analysis ---;

   comp_term = .;  * study has completed/terminated follow up for primary endpoint;
   mntopcom_mod = .;  * months from start to primary completion date;
   label comp_term = 'Study completed/terminated'
         mntopcom_mod = 'Months from study start to completion of follow up for primary endpoint'
      ;

   * if study was completed or terminated or primary or completion date set to Actual, then count as completed;
   * calculate number of months from study start to completion of primary endpoint;
   if overall_status in ('Terminated', 'Completed') 
      or primary_completion_date_type='Actual' 
      or completion_date_type='Actual' then do;

      comp_term=1;

      if start_date>. then do;
   
         if primary_completion_date>. then 
            mntopcom_mod= ( month(primary_completion_date) + 12*year(primary_completion_date) ) - 
                          ( month(start_date) + 12*year(start_date) ) + 1;

         else if completion_date>. then 
            mntopcom_mod= ( month(completion_date) + 12*year(completion_date) ) - 
                          ( month(start_date) + 12*year(start_date) ) + 1;

         end;
      end;

   * if study was still in progress at download date;
   * calculate number of months from study start to download date;
   else if overall_status in ('Recruiting', 'Enrolling by invitation', 'Active, not recruiting','Suspended','Unknown status') 
        then do;

        comp_term=0;

        if start_date>. then 
            mntopcom_mod= ( month(download_date) + 12*year(download_date) ) - 
                          ( month(start_date) + 12*year(start_date) ) + 1;

        end;

   * note that studies that are withdrawn or not yet recruiting, or starting after download date are excluded from this analysis;
   if overall_status in ('Not yet recruiting','Withdrawn') or start_date >= download_date then do;
      comp_term=.;
      mntopcom_mod=.;
      end;
  

   * --- define variables for time to results reporting analysis ---;

   results_reported=.;
   mntores_mod=.;
   label results_reported = 'Study has reported results'
         mntores_mod = 'Months from primary completion to results reporting'
      ;


   *  restrict to studies that were completed or terminated prior download_date;
   if overall_status in ('Terminated', 'Completed') then do;

      if results_first_submitted_date >. then do;

          results_reported=1;

         if primary_completion_date>. then 
            mntores_mod= ( month(results_first_submitted_date) + 12*year(results_first_submitted_date) ) - 
                         ( month(primary_completion_date) + 12*year(primary_completion_date) ) +1;

         else if completion_date>. then 
            mntores_mod= ( month(results_first_submitted_date) + 12*year(results_first_submitted_date) ) - 
                         ( month(completion_date) + 12*year(completion_date) ) +1;

         end;


      else if results_first_submitted_date =.  then do;

          results_reported=0;

         if primary_completion_date>. then 
            mntores_mod= ( month(download_date) + 12*year(download_date) ) - 
                         ( month(primary_completion_date) + 12*year(primary_completion_date) ) +1;

         else if completion_date>. then 
            mntores_mod= ( month(download_date) + 12*year(download_date) ) - 
                         ( month(completion_date) + 12*year(completion_date) ) +1;


         end;

   end;

   * if study has results but results reporting is prior to completion then set the time to variable to 1;
   if results_reported=1 and . < mntores_mod < 1 then mntores_mod=1;

   * if study does not have results but primary completion date > download date, set the time variable to 1;
   * these studies are all terminated, but primary completion date doesnt reflect termination date;
   if results_reported=0 and . < mntores_mod < 1 then mntores_mod=1;   


   * --- exclusions ---;
   if lowcase(study_type) ^= 'interventional' then output ex_type;
   else if . < reg_year < 2008 or reg_year > &endyr then output ex_year;

   else output analdata;

   run;


* --- AACT calculated values ---;
proc sort data=analdata nodupkey;
   by nct_id;
   run;

proc sort data=aact.calculated_values 
      (keep=nct_id nlm_download_date )
   out=calculated_values nodupkey;
   by nct_id;
   run;

* --- sponsors and collaborators ---;
data lead collab;
   set aact.sponsors;
   if lead_or_collaborator="lead" then output lead;
   else if lead_or_collaborator="collaborator" then output collab;
   keep nct_id agency_class;
   run;

proc sort data=lead nodupkey;
   by nct_id;
   run;

* reduce collaborator info to one record per nct_id;
proc sort data=collab nodupkey;
   by nct_id agency_class;
   run;

data collab1;
   set collab;
   by nct_id agency_class;

   retain c_ind c_nih c_usf c_oth;

   if first.nct_id then do;
      c_ind=0; c_nih=0; c_usf=0; c_oth=0;
      end;

   if agency_class='Industry' then c_ind=1;
   else if agency_class='NIH' then c_nih=1;
   else if agency_class='U.S. Fed' then c_usf=1;
   else if agency_class='Other' then c_oth=1;

   if last.nct_id then output;

   keep nct_id c_:;
   run;

* --- intervention types ---;
proc sort data=aact.interventions (keep=nct_id intervention_type)
      out=interv nodupkey;
   by nct_id intervention_type;
   run;

data interv1;
   set interv;
   by nct_id intervention_type;
   
   retain device procedure drug biologic behavioral diet other;
   
   if first.nct_id then do;
      device=0; procedure=0; drug=0; biologic=0; behavioral=0; diet=0; other=0;
      end;

   if intervention_type='Device' then device=1;
   else if intervention_type='Procedure' then procedure=1;
   else if intervention_type='Drug' then drug=1;
   else if intervention_type='Biological' then biologic=1;
   else if intervention_type='Behavioral' then behavioral=1;
   else if intervention_type='Dietary Supplement' then diet=1;
   else if intervention_type ^= '' then other=1;

   if last.nct_id then do;
      
      * define intervention hierarchy;
      if device=1 then intervg=1;
      else if procedure=1 then intervg=2;
      else if biologic=1 then intervg=3;
      else if drug=1 then intervg=4;
      else if behavioral=1 then intervg=5;
      else if diet=1 then intervg=6;
      else if other=1 then intervg=7;
      label intervg = 'Intervention type (mutually exclusive grouping)';
      format intervg intervf.;

      * intervention hierarchy with larger groupings;
      if device=1 then intervh=1;
      else if procedure=1 then intervh=1;
      else if biologic=1 then intervh=2;
      else if drug=1 then intervh=2;
      else if behavioral=1 then intervh=3;
      else if diet=1 then intervh=3;
      else if other=1 then intervh=4;
      label intervh = 'Intervention type (grouped)';
      format intervh intervh.;

      output;
      end;

   run;


* --- site locations ---;
* (exclude info from removed countries) ;
data countries;
   set aact.countries;
   run;

proc sort data=countries  
      out=countries nodupkey;
   where removed ^= '1';   
   by nct_id name;
   run;

data countries1;
   set countries;
   by nct_id name;

   retain us_site nonus_site;
   
   if first.nct_id then do;
      us_site=0;  nonus_site=0;
      end;

   if name='United States' then us_site=1;
   else if name ^='' then nonus_site=1;

   if last.nct_id then do;
      if us_site=1 and nonus_site=0 then siteloc=1;
      else if us_site=1 and nonus_site=1 then siteloc=2;
      else if us_site=0 and nonus_site=1 then siteloc=3;
      label siteloc = 'Geographical Location of Study Facilities';
      format siteloc sitelocf.;

      label us_site = 'Study Facilities Located in U.S.A.';
      format us_site us_sitef.;

      output;
      end;

      keep nct_id us_site nonus_site siteloc;

   run;
   
* --- new gender eligibility info ---;
proc sql;
   create table eligibilities as
   select a.nct_id, a.gender, a.gender_based
   from aact.eligibilities a
   order by a.nct_id;
   run;

* --- combine data and make other derivations ---;
data analdata;
   merge analdata (in=in1) 
         calculated_values (in=in2)
         lead
         collab1
         interv1 (keep=nct_id intervg intervh)
         countries1
     ;   
   by nct_id;
   if in1;

   label nlm_download_date = "Date when study was extracted to NLM API"
         phase = "Study phase"
       ;

   * funding source - this version does not consider US Fed;
   if agency_class='Industry' then funding=1;
   else if agency_class='NIH' or c_nih=1 then funding=2;
   else if c_ind=1 then funding=1;
   else funding=4;
   format funding fundf.;
   label funding = "Funding Source (derived from Lead and Collaborator info)";

   * funding source - this version does include US Fed;
   if agency_class='Industry' or (agency_class='Other' and c_ind=1 and c_nih=0) then fundingo=1;
   else if agency_class='NIH' or (agency_class='Other' and c_nih=1) then fundingo=2;
   else if agency_class='U.S. Fed' or (agency_class='Other' and c_usf=1) then fundingo=3;
   else if agency_class='Other' or c_oth=1 then fundingo=4;
   format fundingo fundof.;
   label fundingo = "Funding Source (derived from Lead and Collaborator info, taking into account US Fed sources)";

   * missing site location info;
   if siteloc=. then siteloc=99;

   run;


title 'Confirm that derivations from source are still OK';
proc freq data=analdata;
   tables phaseg * phase /list missing nopercent;
   tables overall_statusn * overall_status / list missing nopercent;
   tables funding * fundingo / list missing nopercent; 
   tables intervh * intervg / list missing nopercent;
   tables siteloc * us_site * nonus_site / list missing nopercent;
   tables plan_to_share_ipd * plan_to_share_ipd_n / list missing nopercent;
   run;
title;


* get date when AACT most recently updated;
proc sql;
    create table aactdt as
      select
        max(aact_date) as max_aact_date
      from analdata;
quit; 

data aactdt;
    set aactdt;
    call symput('aactdt', compress(put(max_aact_date, date9.)));
run;


/* --------------------------------------------------------------------------
   Summarize exclusions from dataset
 -------------------------------------------------------------------------- */
options orientation=landscape nodate;

ods pdf body="./exclusions_for_graphs_interventional_trials.pdf" style=journal;

title1 j=c "Total number of studies extracted, by study_type";
footnote1 j=l "Extracted from &server (AACT) most recently updated on &aactdt, and based on content publicly released by NLM on &nlmdt..";
footnote2 j=l "Summaries generated by:  %sysget(PWD)/%sysfunc(scan(&SYSPROCESSNAME,2)).sas on &sysdate &systime..";

proc freq data=aact.studies;
   tables study_type;
   run;

ods startpage = now;

title1 j=c "Summary of sequential study exclusions applied to create analysis data used for graphs";
title3 j=c "Exclude non-interventional studies";
footnote1;
proc freq data=ex_type;
   tables study_type / missing nopercent;
   run;

title3 j=c "Exclude interventional studies registered <2008 and >&endyr";
footnote1 j=l "Extracted from &server (AACT) most recently updated on &aactdt, and based on content publicly released by NLM on &nlmdt..";
footnote2 j=l "Summaries generated by:  %sysget(PWD)/%sysfunc(scan(&SYSPROCESSNAME,2)).sas on &sysdate &systime..";

proc freq data=ex_year;
   tables reg_year / missing nopercent;
   run;

ods pdf close;
title;

/* --------------------------------------------------------------------------
   Save permanent dataset
 -------------------------------------------------------------------------- */
data out.analdata (label = "Dataset extracted from AACT for graphical summary");
   set analdata;

   countv = 1;
   label countv = 'Variable used to count studies';

   drop agency_class c_: has_dmc overall_status nonus_site;

   run;
  
proc contents data=out.analdata;
run;

proc print data=out.analdata (obs=10) width=min;
run;

