Timemachine written by Uwe Drechsel - Version 3.6

    usage: tm [-h][-f filenames][comment]
      -h     help
      -f     Filename
      -g     grep befor generating a report e.g. grep for a comment
      -i     in      
      -o     out     
      -c     comment and new login (comment is added after loggin out) 
      -x     extra worktime (doesn't count as regular workday and is marked with  *)
      -l     Lesson English (ends session with §Lesson English§)
      -b     Begin Daterange (format DD or DD.MM or DD.MM.YYYY. default: today)
      -e     Ende Daterange  (format DD or DD.MM or DD.MM.YYYY. default: today)
      -be    Begin and end daterange (format DD or DD.MM or DD.MM.YYYY. default: today)
      -s     SZE-entries 
      -t     worktime today 
      -v     open data in $EDITOR (or in vi)
      -w     week (sets range for the week of the actual year)
      -d     Debug Mode


    Installation:
        Please install perl-Date-Calc.rpm
        and touch the DATAFILE, e.g.
        touch $HOME/.tmdata

    Files:
        Timemachine uses two files: DATAFILE and COMMFILE. 
        DATAFILE=$HOME/.tmdata

        is used to store the information about logins, logouts, comments. 
        (Before the first use of timemachine you should create it by
        touch $HOME/.tmdata)

        In this file you have:
          * 
            extra worktime (doesn't count as regular workday and 
            is marked with  *)
        §+time§ and §-time§  
            are added/subtracted from the worktime
        §Urlaub--§  and §Urlaub+=123§  
            modify the vacation days 
        §Freizeitausgleich§ 
            increases the days for "Freizeitausgleich" and starts 
            a new workday
        "this is not important" 
            is ignored by timemachine, but can be used to grep for
            certain lines with the -g option


        COMMFILE=$HOME/.tmcomment

        is used to save the comment for writing it later to DATAFILE
