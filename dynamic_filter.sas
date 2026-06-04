/*==============================================================================
 * MACRO:           %dynamic_filter
 * PURPOSE:         Dynamically generates a WHERE clause to filter a dataset 
 * based on a paired list of columns and values. 
 * Supports single/multi-values, subqueries, cross-column 
 * (OR) logic natively, and raw SQL injection.
 *
 * PARAMETERS:
 * indata         - The source dataset to filter.
 * outdata        - The output dataset name. Can overwrite indata.
 * cols           - A pipe-separated list of column names. Multiple columns 
 * separated by a comma will trigger OR logic for that value.
 * vals           - A pipe-separated list of values, lists, or subqueries.
 * delim          - The delimiter used to separate column/value pairs (Default: |)
 * custom_where   - (Optional) A raw SQL condition appended to the end of the 
 * WHERE clause. Ideal for date ranges, mathematical 
 * evaluations, or functions where indexing must be preserved.
 *
 * --- USAGE EXAMPLES ---
 * 1. The Standard 1:1 Filter 
 * %let dycols = Department_Name | Record_Status;
 * %let dyvals = 'Sales' | 'Active';
 *
 * 2. Multiple Values in a Single Column
 * %let dycols = Department_Name | Record_Status;
 * %let dyvals = 'Sales', 'Marketing' | 'Active', 'Pending';
 *
 * 3. Dataset-Driven Subquery
 * %let dycols = Employee_ID | Record_Status;
 * %let dyvals = select emp_id from work.audit_list | 'Active';
 *
 * 4. Multi-Column Search (OR Logic via Comma-Separated Columns)
 * %let dycols = Primary_Owner, Secondary_Owner, Reviewer;
 * %let dyvals = select emp_id from work.user_roster;
 *
 * 5. Mixed Logic (Single Col + Multi-Col + Hardcoded + Subquery)
 * %let dycols = Priority_Level | Primary_Owner, Secondary_Owner;
 * %let dyvals = 'High', 'Urgent' | select emp_id from work.active_users;
 *
 * 6. Multi-Field Lookup (Using UNION to combine columns for a single target)
 * %let dycols = Priority_Level | Primary_Owner;
 * %let dyvals = 'High', 'Urgent' | select emp_id from work.active_users union select backup_id from work.active_users;
 *
 * 7. Raw SQL Injection (e.g., Date Ranges for Performance)
 * %let dycols = Record_Status;
 * %let dyvals = 'Processed';
 * %dynamic_filter(
 * indata       = work.source_data,
 * outdata      = work.filtered_data,
 * cols         = &dycols.,
 * vals         = &dyvals.,
 * custom_where = transaction_date >= '01MAY2026'd and transaction_date < '01JUN2026'd
 * );
 *============================================================================*/

%macro dynamic_filter(indata=, outdata=, cols=, vals=, delim=%str(|), custom_where=);
    %local i j num_cols current_col_chunk current_val num_subcols subcol;
    
    %let num_cols=%sysfunc(countw(%bquote(&cols.), &delim.));

    proc sql noprint;
        create table &outdata. as
        select *
        from &indata.
        where 1=1 
        %do i=1 %to &num_cols.;
            %let current_col_chunk=%qscan(%bquote(&cols.), &i., &delim.);
            %let current_val=%qscan(%bquote(&vals.), &i., &delim.);
            %let num_subcols=%sysfunc(countw(%bquote(&current_col_chunk.), %str(,)));
            
            and (
            %do j=1 %to &num_subcols.;
                %let subcol=%qscan(%bquote(&current_col_chunk.), &j., %str(,));
                
                %if &j > 1 %then OR ;
                
                &subcol. IN (%unquote(&current_val.))
            %end;
            )
        %end;
        
        %if %length(&custom_where.) > 0 %then %do;
            and ( &custom_where. )
        %end;
        ; 
    quit;
%mend dynamic_filter;
