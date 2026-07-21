/*=============================================================================
  MACRO: %extract_dates
  
  PURPOSE: 
  Extracts dates from messy, free-text character variables and converts 
  them into standard numeric SAS dates (formatted as DATE9.). It uses a 
  "Regex Waterfall" to identify various date structures (ISO, slashes/hyphens, 
  and verbose text) while ignoring timestamps and surrounding text.
  
  PARAMETERS:
  data_in  - The name of the input dataset.
  data_out - The name of the output dataset to be created.
  fields   - The column name(s) to process. Can be a single column, or 
             multiple columns delimited by spaces or pipes (|).
             
  EXAMPLES:
  
Scenario A: Passing a single column
  %extract_dates(
      data_in=WORK.raw_data, 
      data_out=WORK.cleaned_data, 
      fields=start_date
  );
  
Scenario B: Passing multiple columns using pipes
  %let date_cols = start_date | end_date | updated_date;
  %extract_dates(
      data_in=WORK.raw_data, 
      data_out=WORK.cleaned_data, 
      fields=&date_cols.
  );
  
Scenario C: Passing multiple columns using spaces
  %extract_dates(
      data_in=WORK.raw_data, 
      data_out=WORK.cleaned_data, 
      fields=start_date end_date
  );
=============================================================================*/

%macro extract_dates(data_in=, data_out=, fields=);

    data &data_out.;
        set &data_in.;

        array rx[3] _temporary_;
        if _N_ = 1 then do;
            rx[1] = prxparse('/\d{4}[\/\-]\d{1,2}[\/\-]\d{1,2}/');
            rx[2] = prxparse('/\d{1,2}[\/\-][a-zA-Z0-9]{1,9}[\/\-]\d{2,4}/');
            rx[3] = prxparse('/\d{1,2}(st|nd|rd|th)?\s+(of\s+)?[a-zA-Z]{3,9}\s+\d{2,4}/i');
        end;

        %local i col;
        %let i = 1;
        %let col = %scan(&fields., &i., %str(| )); 

        %do %while ("&col." ne "");
        length _extracted_&col. $50.;
        
            &col._num = .; 
            _extracted_&col. = "";
            _start_pos_&col. = 0;
            _match_len_&col. = 0;

            do j = 1 to dim(rx) until(_start_pos_&col. > 0);
                
                call prxsubstr(rx[j], &col., _start_pos_&col., _match_len_&col.);
                
                if _start_pos_&col. > 0 then do;
                    _extracted_&col. = substr(&col., _start_pos_&col., _match_len_&col.); 
                    
                    if j = 3 then do;
                        _extracted_&col. = prxchange('s/\b(st|nd|rd|th|of)\b//i', -1, _extracted_&col.);
                    end;
                    
                    &col._num = input(_extracted_&col., ANYDTDTE.); 
                end;
            end;

            format &col._num DATE9.; 
            drop &col. _extracted_&col. _start_pos_&col. _match_len_&col.;
            rename &col._num = &col.;

            %let i = %eval(&i. + 1);
            %let col = %scan(&fields., &i., %str(| ));
        %end;

        drop j;
    run;

%mend extract_dates;
