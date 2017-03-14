/*
-----------------------------------------------------------------------------
Project:  AACT
Purpose:  Formats for graphs
Source:   formats.sas
Author:   K. Chiswell, Duke Clinical Research Institute
Date:     2017/03/09
-----------------------------------------------------------------------------
*/

proc format;

   value fundf 
        1 = 'Industry'
        2 = 'NIH'
        4 = 'Other'
     ;

   value fundof 
        1 = 'Industry'
        2 = 'NIH'
        3 = 'Other U.S. Fed'
        4 = 'Other'
     ;

   value ynf
        0 = 'No'
        1 = 'Yes'
     ;

   value ynuf
        0 = 'No'
        1 = 'Yes'
       99 = 'Unknown'
     ;

   value intervf
        1 = 'Device'
        2 = 'Procedure'
        3 = 'Biological'
        4 = 'Drug'
        5 = 'Behavioral'
        6 = 'Dietary Supplement'
        7 = 'Other'
     ;

   value intervh
        1 = 'Device/Procedure'
        2 = 'Biological/Drug'
        3 = 'Behavioral/Dietary Supplement'
        4 = 'Other'
     ;

   value statusf
        1='Not yet recruiting'
        2='Recruiting'
        3='Enrolling by invitation'
        4='Active, not recruiting'
        5='Suspended'
        6='Terminated'
        7='Completed'
        8='Withdrawn'
        99='Unknown status'
        ;

   value phasef
        0 = 'Early Phase 1'
        1 = 'Phase 1'
        2 = 'Phase 1/2 & 2'
        3 = 'Phase 2/3 & 3'
        4 = 'Phase 4'
        99 = 'Phase N/A'
        ;

    value sitelocf
        1 = 'Sites in U.S. only'
        2 = 'Sites in U.S. and R.O.W.'
        3 = 'Sites in R.O.W. only'
        99 = 'Missing info about site countries'
        ;

    value us_sitef
        0 = 'Studies with only non-US sites'
        1 = 'Studies with at least 1 US site'
        ;
run;
