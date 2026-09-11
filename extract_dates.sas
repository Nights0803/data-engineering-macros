%macro extract_dates(data_in=, data_out=, fields=);

    data &data_out.;
        set &data_in.;

        array rx[4] _temporary_;
        if _N_ = 1 then do;
            rx[1] = prxparse('/\d{4}[\/\-]\d{1,2}[\/\-]\d{1,2}/');
            rx[2] = prxparse('/\d{1,2}[\/\-][a-zA-Z0-9]{1,9}[\/\-]\d{2,4}/');
            rx[3] = prxparse('/\d{1,2}(st|nd|rd|th)?\s+(of\s+)?[a-zA-Z]{3,9}\s+\d{2,4}/i');
            rx[4] = prxparse('/\b[a-zA-Z]{3}\s+\d{1,2}\s+\d{4}\b/i');
        end;

        %local i col col_label;
        %let i = 1;
        %let col = %scan(&fields., &i., %str(| )); 

        %do %while ("&col." ne "");
            %let col_label = %sysfunc(tranwrd(&col., _, %str( )));
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
            label &col._num = "&col_label.";
            drop &col. _extracted_&col. _start_pos_&col. _match_len_&col.;
            rename &col._num = &col.;

            %let i = %eval(&i. + 1);
            %let col = %scan(&fields., &i., %str(| ));
        %end;

        drop j;
    run;

%mend extract_dates;
