/*==============================================================================
 * MACRO:           %assign_strata
 * PURPOSE:         Dynamically assigns numeric stratum IDs to a dataset based 
 *                  on user-defined lists of values. It evaluates a target column,
 *                  assigns matching records to their respective group integer 
 *                  (1, 2, 3, etc.), and automatically assigns any unmatched 
 *                  records to a final N+1 group. Includes a frequency audit 
 *                  table and outputs a pre-sorted dataset.
 *
 * PARAMETERS:
 * data_in        - The source dataset to evaluate.
 * data_out       - The output dataset name (will be sorted by Stratum_ID).
 * target_col     - The column to evaluate for grouping.
 * group1_vals to 
 * group10_vals   - (Optional) Comma-separated lists of values for each group. 
 *                  Values should be wrapped in single quotes.
 *
 * --- USAGE EXAMPLES ---
 * 1. Binary Split (Target vs. Everything Else)
 * %assign_strata(
 *     data_in     = work.raw_demographics,
 *     data_out    = work.strata_demographics,
 *     target_col  = Region,
 *     group1_vals = 'North', 'South'
 * );
 * Note: 'North' and 'South' are assigned to Stratum 1. Any other regions 
 * present in the data (like 'East' or 'West') automatically get assigned 
 * to Stratum 2.
 *
 * 2. Multi-Group Categorization (Three specific groups + Catch-all)
 * %assign_strata(
 *     data_in     = work.inventory_log,
 *     data_out    = work.strata_inventory,
 *     target_col  = Item_Category,
 *     group1_vals = 'Electronics', 'Computers',
 *     group2_vals = 'Furniture',
 *     group3_vals = 'Office Supplies', 'Paper Goods'
 * );
 * Note: Any item categories not explicitly listed above (like 'Cleaning 
 * Supplies' or 'Breakroom Snacks') automatically get assigned to Stratum 4.
 *============================================================================*/

%macro assign_strata(
    data_in=, 
    data_out=, 
    target_col=,
    group1_vals=, 
    group2_vals=, 
    group3_vals=, 
    group4_vals=, 
    group5_vals=,
    group6_vals=, 
    group7_vals=, 
    group8_vals=, 
    group9_vals=, 
    group10_vals=
);

    %local i active_groups final_group;
    
    %let active_groups = 0;

    %do i = 1 %to 10;
        %if %length(&&group&i._vals) > 0 %then %let active_groups = &i.;
    %end;

    %let final_group = %eval(&active_groups. + 1);

    data &data_out.;
        set &data_in.;
        
        Stratum_ID = &final_group.;
        
        %do i = 1 %to &active_groups.;
            if upcase(&target_col.) in (%upcase(&&group&i._vals)) then Stratum_ID = &i.;
        %end;
    run;

    title "Audit: Stratification Mapping for &target_col.";
    proc freq data=&data_out.;
        tables &target_col. * Stratum_ID / list missing nocum nopercent;
    run;
    title;

    proc sort data=&data_out.;
        by Stratum_ID;
    run;

%mend assign_strata;
