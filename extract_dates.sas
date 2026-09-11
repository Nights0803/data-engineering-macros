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

        length _ext $50.;
        drop _ext _pos _len j;

        %local i col col_label;
        %let i = 1;
        %let col = %scan(&fields., &i., %str(| )); 

        %do %while ("&col." ne "");
            %let col_label = %sysfunc(tranwrd(&col., _, %str( )));
        
            _dt_&i. = .; 
            _ext = "";
            _pos = 0;
            _len = 0;

            do j = 1 to dim(rx) until(_pos > 0);
                
                call prxsubstr(rx[j], &col., _pos, _len);
                
                if _pos > 0 then do;
                    _ext = substr(&col., _pos, _len); 
                    
                    if j = 3 then do;
                        _ext = prxchange('s/\b(st|nd|rd|th|of)\b//i', -1, _ext);
                    end;
                    
                    _dt_&i. = input(_ext, ANYDTDTE.); 
                end;
            end;

            format _dt_&i. DATE9.; 
            label _dt_&i. = "&col_label.";
            drop &col.;
            rename _dt_&i. = &col.;

            %let i = %eval(&i. + 1);
            %let col = %scan(&fields., &i., %str(| ));
        %end;

    run;

%mend extract_dates;
