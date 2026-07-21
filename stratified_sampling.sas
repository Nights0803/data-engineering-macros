/*==============================================================================
 * MACRO:           %stratified_sampling
 * PURPOSE:         Executes a Stratified Simple Random Sample (SRS) using a 
 *                  precision and exception rate calculation. It dynamically 
 *                  scales across any number of groups (strata), implements 
 *                  automatic 100% sampling for exceptionally small sub-populations, 
 *                  caps maximum samples at 73 per stratum, and outputs two distinct 
 *                  tables using a binary integer flag.
 *
 * PARAMETERS:
 * data_in          - The full population dataset (MUST be sorted by strata_col).
 * data_out_full    - Output table containing all records with a new 'In_Sample' 
 *                    (1/0) binary column.
 * data_out_sample  - Output table containing ONLY the sampled records (In_Sample=1).
 * strata_col       - The column defining the groups (can be numeric or character).
 * risk_level       - HIGH, MODERATE, or LOW (Drives Z-score and small pop thresholds).
 * seed             - (Optional) Static random seed for perfect reproducibility.
 *
 * --- USAGE EXAMPLE ---
 * %stratified_sampling(
 *     data_in         = work.stratified_dataset,
 *     data_out_full   = work.population_flagged,
 *     data_out_sample = work.sample_only,
 *     strata_col      = Stratum_ID,
 *     risk_level      = HIGH,
 *     seed            = 12345
 * );
 *============================================================================*/

%macro stratified_sampling(
    data_in=, 
    data_out_full=, 
    data_out_sample=, 
    strata_col=, 
    risk_level=HIGH, 
    seed=12345
);

    %local clean_risk Z threshold;
    %let clean_risk = %upcase(%sysfunc(strip(&risk_level.)));

    %if &clean_risk. = HIGH %then %do;
        %let Z = 1.9599639845;
        %let threshold = 10;
    %end;
    %else %if &clean_risk. = MODERATE %then %do;
        %let Z = 1.644853627;
        %let threshold = 9;
    %end;
    %else %if &clean_risk. = LOW %then %do;
        %let Z = 1.2815515655;
        %let threshold = 8;
    %end;
    %else %do;
        %put WARNING: Invalid Risk Level (&clean_risk.). Defaulting to HIGH.;
        %let Z = 1.9599639845;
        %let threshold = 10;
    %end;

    %put NOTE: Executing Stratified Sample. Risk: &clean_risk. | Z-Score: &Z. | Seed: &seed.;

    proc sql noprint;
        create table _temp_strata_counts as
        select &strata_col., count(*) as N
        from &data_in.
        group by &strata_col.;
    quit;

    data _temp_strata_sizes;
        set _temp_strata_counts;
        
        E = 0.05;
        P = 0.05;
        Z = &Z.;
        
        if N < &threshold. then _NSIZE_ = N;
        else do;
            Numerator = N * (Z**2) * E * (1 - E);
            Denominator = (Z**2) * E * (1 - E) + (P**2) * (N - 1);
            
            _NSIZE_ = ceil(Numerator / Denominator);
            
            if _NSIZE_ > 73 then _NSIZE_ = 73;
            if _NSIZE_ > N then _NSIZE_ = N;
        end;
        
        keep &strata_col. _NSIZE_;
    run;

    proc surveyselect 
        data=&data_in. 
        sampsize=_temp_strata_sizes 
        method=srs 
        seed=&seed.
        outall
        out=_temp_sampled_raw
        noprint;
        strata &strata_col.;
    run;

    data &data_out_sample. &data_out_full.;
        set _temp_sampled_raw (rename=(Selected=In_Sample));
        
        label In_Sample = "Sample Indicator (1=Yes, 0=No)";
        
        drop SelectionProb SamplingWeight;
        
        if In_Sample = 1 then output &data_out_sample.;
        output &data_out_full.;
    run;

    proc sql;
        drop table _temp_strata_counts, _temp_strata_sizes, _temp_sampled_raw;
    quit;

    %put NOTE: Stratified Sampling Complete. Full Data: &data_out_full. | Sample Only: &data_out_sample.;

%mend stratified_sampling;
