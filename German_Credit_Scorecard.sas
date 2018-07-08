/*
---------------------------------
EVALUATE SAS EM SCORECARD RESULTS
---------------------------------
*/

* Date:    11/22/16 ;
* Author:  Yanni Papadakis ;

* SAS EM Diagram Directory (Workspace) ;

%let wspath = %str(/dnbusr3/data12/Projects/Custom/ExampleScoreCard/Workspaces/EMWS1);

libname ws "&wspath";

%macro print_properties(path);
title2 'SAS EM Node Active Properties';
title3 'Excludes Properties With Missing Values';
filename fset "&wspath./&path./PROPERTIES.xml";
data tmp;
length string $ 200 var $ 80 property value $ 40;
retain printable 0;
infile fset ;
input ;
pos_start = index(_infile_,'<_ROOT_');
pos_end = index(_infile_,'>');
if pos_start > 0 then do;
	printable = 1;
	string = substr(_infile_ , pos_start+7);
	end;
else string = _infile_;
if printable then do;
	if pos_start = 0 and pos_end > 0 then do;
		if pos_end > 1 then string = substr(string,1,pos_end-1);
		else string = '';
		printable = 0;
		end;
	var = ' ';
	do i=1 to 20 until(var eq "");
		var = scan(string, i, " ");
		if var ne ' ' then do;
			property = scan(var,1,'=');
			value = scan(var,-1,'=');
			output ;
			end;
		end;
	end;
run;
proc print data=tmp;
where property ne '' and value not in('""','"."');
var property value;
run;
%mend print_properties;

* Contents ;
title  'SAS EM Results' ;
title2 'Table of Contents' ;
data contents;
retain section ;
length level $ 1 section $ 50 subsection $ 50;
input ;
level = substr(_infile_,1,1);
if level = '1' then do;
	s_index + 1;
	section = substr(_infile_,3);
	subsection = 'Properties';
	end;
else if level = '2' then subsection = substr(_infile_,3);
datalines;
1 Data Source Node
2 Available Variables
1 SAS Code Node
2 SAS Commands Applied to Input Data
1 Partition Node
2 Partition Results
1 Interactive Grouping Node
2 Predictor Order by Information Value
2 One-Way Segmentation
1 Scorecard Node
2 Scorecard Table
2 Variables Forced In (If Any)
2 Stepwise Selection
2 Logistic Regression Results
2 Captured Events
2 Model Fit Statistics
2 Predictors Available for Selection
2 Score Distribution
2 Capture Rate
2 ROC Plot
run;
proc report data=contents;
columns s_index section subsection;
define s_index / order '';
define section / group '';
define subsection / '';
run;



* Data Source (Ids) Node ;

title 'Data Source Node' ;

%print_properties(Ids)

title2 'Available Variables';
proc report data=ws.ids_variableset ;
columns obs role drop name level ;
define role / group ;
*define drop / group ;
define drop / across ;
define obs / 'Obs';
*compute after drop ;
*count = 0;
*endcomp;
compute obs ;
	count+1 ;
	obs=count ;
endcomp ;
run;

/*
* SAS Code (EMCODE) Node ;

title 'SAS Code Node' ;

%print_properties(EMCODE)

title2 'SAS Commands Applied to Input Data';
filename fcode "&wspath./EMCODE/EMTRAINCODE.sas";
data tmp;
length command $ 200;
infile fcode ;
input ;
command = _infile_;
run;
proc print data=tmp;
label command = 'SAS Command' ;
run;
*/

* Partition (Part) Node ;

title 'Partition Node' ;

%print_properties(Part)

title2 'Partition Results';
title3 'Target Variables Stats';
proc report data=ws.part_class ;
format count comma9. percent 9.2;
columns data variable value count percent ;
define data / group ;
define value / group ;
break after data / summarize suppress skip;
run;

title3 'Variables with Role in Partition in Addition to Target';
proc print data=ws.part_variableset label;
where not missing(partitionrole);
id name;
var partitionrole;
run;

* Interactive Grouping (IGN) Node ;

title 'Interactive Grouping Node' ;

%print_properties(IGN)

title2 'Predictor Order by Information Value';
proc print data=ws.ign_resultstable ;
id infovalOrder ;
var display_Var _gini_ _infoval_ procLevel _role_ _new_Role_ ;
run;

title2 'One-Way Segmentation';
proc report data=ws.ign_woedata;
columns display_var _group_ _label_ groupresprate displayWOE ;
define display_var / group ;
run;

* Scorecard Node ;

title 'Scorecard Node' ;

%print_properties(Scorecard)
* Are Variables Forced In? ;
data _null_;
set tmp;
if property = 'Force' then do;
	len = find(value,'"',2);
	value_number = substr(value,2,len-2);
	put len value_number;
	call symput('n_forced_in',value_number);
	end;
run;
%put &n_forced_in;

title2 'Scorecard Table';
proc report data=ws.scorecard_scorecard ;
where _group_ ^= -2;
format _woe_ 9.3 _event_rate_ 7.2 _percent_ 7.2 _estimate_ 9.5 ;
label _woe_ = 'WOE' _event_rate_ = 'Bad Pct' scorecard_points = 'Points' _percent_ = 'Pop Pct' ;
columns _estimate_ _variable_ _group_ _label_ SCORECARD_POINTS _woe_ _event_rate_ _percent_  ;
define _estimate_ / order noprint missing ;
define _variable_ / group missing ;
run;

title2 'Variables Forced In (If Any)';
proc print data=ws.scorecard_modelorder;
where key <= &n_forced_in ;
id key;
var variable ;
run;

title2 'Stepwise Selection';
proc means data=ws.scorecard_emestimate noprint;
where _type_ = 'PARMS' and _chosen_ ^= 'VERROR';
var Intercept WOE_: ;
output out=vcount n= ;
proc transpose data=vcount(drop=_freq_ _type_) out=tmp(where=(col1 > 0));
run;
proc sql noprint;
select _name_ into :mvars separated by ' ' from tmp;
quit;
proc print data=ws.scorecard_emestimate ;
where _type_ = 'PARMS' and _chosen_ ^= 'VERROR';
id _step_ ;
var &mvars _aic_ _nobs_;
run;

title2 'Logistic Regression Results';
title3 'Logistic Regression Fit';
proc print data=ws.scorecard_outterms ;
format coefficient 12.5 tvalue 9.2 pvalue 8.4 ;
id term ;
run;
title3 'Individual Factor Stats';
proc report data=ws.scorecard_stattable ;
format _gini_ 9.2 _infoval_ 7.3;
columns _variable_ _gini_ _infoval_ infovalOrder ;
define infovalOrder  / order id;
run;

title2 'Captured Events';
proc print data=ws.scorecard_capturedevent ;
by datarole ;
id _score_bucket_ ;
var cumPercentEventCount cumPercentSample ;
sum percentEventCount percentSample  ;
run;

title2 'Model Fit Statistics';
proc print data=ws.scorecard_emreportfit ;
format train validate test 6.3 ;
where stat in('_AUR_','_Gini_','_KS_');
id stat ;
var train validate test ;
run;

title2 'Predictors Available for Selection';
proc report data=ws.scorecard_emtrainvariable ;
where substr(name,1,4) = 'WOE_' and role = 'INPUT';
columns use obs name level ;
define use / order ;
compute after use ;
count = 0;
endcomp;
compute obs ;
	count+1 ;
	obs=count ;
endcomp ;
run;

title2 'Score Distribution';
proc print data=ws.scorecard_emrank label;
format gain 7.1 lift liftc 7.2 resp respc 8.3 n comma9. _meanp_ 12.4;
by datarole;
id decile ;
var gain lift liftc resp respc n _meanp_ ;
run;


title2 'Capture Rate';
proc sort data=ws.scorecard_kstable out=tmp;
by dataRole bucket;
data tmp;
retain n n_bad n_good;
set tmp;
by datarole;
if first.datarole then do;
	n = _cumulative_count_;
	n_bad = _cumulative_event_count_;
	n_good = _cumulative_non_event_count_;
	cum_pop_pct = 0;
	cum_bad_pct = 0;
	end;
pop_pct = _count_ / n;
bad_pct = _event_count_ / n_bad;
good_pct = _non_event_count_ / n_good;
cum_pop_pct + pop_pct;
cum_bad_pct + bad_pct;
bad_rate = _event_count_ / _count_;
rename _count_=total _event_count_=bad _non_event_count_=good;
run;
proc print data=tmp label;
format cum_bad_pct cum_pop_pct bad_rate em_pd _low_pred_threshold_ _high_pred_threshold_ percent9.2;
by datarole;
id _score_bucket_ ;
var bad good total cum_bad_pct cum_pop_pct bad_rate em_pd _low_pred_threshold_ _high_pred_threshold_;
run;

title2 'ROC Plot';
data tmp;
set ws.scorecard_roctable;
if datarole = 'TRAIN' then pchar = 'T';
else if datarole = 'VALID' then pchar = 'V';
else if datarole = 'TEST' then pchar = 'O';
run;
proc gplot data=tmp ;
plot sensitivity * oneminusspecificity  = pchar / href=0 to 1 by 0.2 vref=0 to 1 by 0.2;
run;


title ;