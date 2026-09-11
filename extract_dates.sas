%macro extract_dates(data_in=, data_out=, fields=);

    data &data_out.;
        set &data_in.;

        /* Expanded array dimension from 3 to 4 */
        array rx[4] _temporary_;
        if _N_ = 1 then do;
            rx[1] = prxparse('/\d{4}[\/\-]\d{1,2}[\/\-]\d{1,2}/');
            rx[2] = prxparse('/\d{1,2}[\/\-][a-zA-Z0-9]{1,9}[\/\-]\d{2,4}/');
            rx[3] = prxparse('/\d{1,2}(st|nd|rd|th)?\s+(of\s+)?[a-zA-Z]{3,9}\s+\d{2,4}/i');
            /* Pattern 4: 3-letter month, 1-2 digit day, 4-digit year */
            rx[4] = prxparse('/\b[a-zA-Z]{3}\s+\d{1,2}\s+\d{4}\b/i');
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

            /* dim(rx) now evaluates to 4 automatically */
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
