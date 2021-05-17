cd "/Users/leahkoenig/Box Sync/ETS PhD/Spring 2021/Epi 265/Data Project/Data Project 3/"
local dataproject2 = "Census2000_1%Sample.dta"

use `dataproject2', replace

local loop = 1
capture drop state
gen state=.

*Create a state variable where the numbering matches what is in the csv file

levelsof statefip 
foreach level in `r(levels)' { 
	replace state = `loop' if statefip==`level'
	local loop = `loop'+1
	}

capture la drop state
la def state 	1	"Alabama" ///
				2	"Alaska" ///
				3	"Arizona" ///
				4	"Arkansas" ///
				5	"California" ///
				6	"Colorado" ///
				7	"Connecticut" ///
				8	"Delaware" ///
				9	"District of Columbia" ///
				10	"Florida" ///
				11	"Georgia" ///
				12	"Hawaii" ///
				13	"Idaho" ///
				14	"Illinois" ///
				15	"Indiana" ///
				16	"Iowa" ///
				17	"Kansas" ///
				18	"Kentucky" ///
				19	"Louisiana" ///
				20	"Maine" ///
				21	"Maryland" ///
				22	"Massachusetts" ///
				23	"Michigan" ///
				24	"Minnesota" ///
				25	"Mississippi" ///
				26	"Missouri" ///
				27	"Montana" ///
				28	"Nebraska" ///
				29	"Nevada" ///
				30	"New Hampshire" ///
				31	"New Jersey" ///
				32	"New Mexico" ///
				33	"New York" ///
				34	"North Carolina" ///
				35	"North Dakota" ///
				36	"Ohio" ///
				37	"Oklahoma" ///
				38	"Oregon" ///
				39	"Pennsylvania" ///
				40	"Rhode Island" ///
				41	"South Carolina" ///
				42	"South Dakota" ///
				43	"Tennessee" ///
				44	"Texas" ///
				45	"Utah" ///
				46	"Vermont" ///
				47	"Virginia" ///
				48	"Washington" ///
				49	"West Virginia" ///
				50	"Wisconsin" ///
				51	"Wyoming"
la val state state 

la var statefip "State ID"
save, replace	
********************************************************************************
*****************************Setup and Var Generation***************************
********************************************************************************
import delimited using "USHistoricalData.csv", clear // import csv file developed from Maria's file
capture rename ï state
capture drop if state==.
save USHistoricalData.dta, replace // save as .dta format

merge 1:m state using "`dataproject2'" //merge with Data Project 2 ata

capture drop if adult==0 // drop if adults are still retained in dataset

*Effect of education: lowed

*Outcome: disabwrk1

*Number of children: nchild
	capture drop numchild
	gen numchild = 0 if nchild==0
	replace numchild = 1 if nchild > 0 & nchild!=4
	la var numchild "Number of children living in household"
	la def numchild 0 "None" 1 "Any"
	la val numchild numchild
	
*marstat
capture drop curmarried
gen curmarried = 0 if marst==3|marst==4|marst==5|marst==6
replace curmarried = 1 if marst==1|marst==2
la def curmarried 0 "Not currently married" 1 "Currently married"
la var curmarried "Current marital status"

*sex

*birthyear
capture drop birthyear 
gen birthyear = 2000-age

encode urban1940, gen(urban_1940)
capture drop urban1940
rename urban_1940 urban1940

*urbanprop
capture drop urbanprop
gen urbanprop = .
foreach decade in 10 20 30 40 50 60 70 {
	replace urbanprop = urban19`decade' if birthyear>=(19`decade'-5) & ///
	birthyear<(19`decade'+5)
	}
	
********************************************************************************
*********************************Mediation Analysis*****************************
********************************************************************************
*note: still working on this from here down
cls

*Estimate total effect of low education on work disability
regress disabwrk1 i.lowed birthyear urbanprop sex 

*Estimate average treatment effect 
margins, dydx(lowed)

*Estimate CDE foreach mediator
foreach m in numchild curmarried {
preserve
*a) expand
	capture drop unique
	gen unique = _n
	expand 3 
	capture drop copy
	bys unique: gen copy=_n 
*b) counterfactual when x=0
	replace lowed = 0 if copy==2
	replace `m' = 0 if copy==2
	replace disabwrk1 = . if copy==2
*c) counterfactual when x=1
	replace lowed = 1 if copy==3
	replace `m' = 0 if copy==3
	replace disabwrk1 = . if copy==3	
*d) Estimate a regression model predicting the outcome as a function of 
	*exposure, mediator, the interaction of the exposure and mediator, and the 
	*mediator-outcome confounder (C), using only the real observations.
	regress disabwrk1 lowed##`m' numchild curmarried birthyear urbanprop sex if copy==1 // include both mediators, the one in the loop will drop out
		//do we control for the second mediator? 
*e) predict counterfactual when x=0 and m=0
	capture drop cf_y_x0_m0
	predict cf_y_x0_m0 if copy==2

*f) predict counterfactual when x=1 and m=0
	capture drop cf_y_x1_m0
	predict cf_y_x1_m0 if copy==3

*g) Estimate CDE of X on Y 
	sum cf_y_x0_m0
	local mean1 = `r(mean)'
	sum cf_y_x1_m0
	local mean2 = `r(mean)'
	di "CDE (`m')" %9.2f `mean2'-`mean1'
restore
}
