/*Macros---------------------------------------------------------*/
%macro translateHelper(team=,year=);
	run; *this allows multiple data teams to work;
	*read in roster file for the team;
	data roster&team&year;
		infile "&folder.\&team&year..ROS"
		dlm=',';
		input playerCode $ last $ first $;
		name= catx('', first, last); /*Create full name from first and last*/
		drop last first; /*variables no longer needed*/
	run;

	*add to full rosters data set;
	data rosters;
		set rosters roster&team&year;
	run;

	*saves room;
	proc delete data=roster&team&year;
	run;
%mend translateHelper;

%macro translate(year=);
	*create dataset to add all the rosters to;
	data rosters;
	run;

	*calls helper for all the teams;
	data temp;
    	set teams&year;
    	call execute(cats('%nrstr(%translateHelper(team=', code, ', year=', &year,'))'));
	run;

	*removes blank line at the beginning;
	data rosters;
		set rosters(firstobs=2);
	run;

	*combine with play data;
	proc sql;
		CREATE TABLE merged AS
		SELECT *
		FROM data&year AS a
		LEFT JOIN rosters AS b 
		ON a.player = b.playerCode;
	quit;

	*fixes columns and cleans up data set;
	data data&year;
		set merged;
		drop player playerCode;
	run;

	data data&year;
		set data&year(rename=(name=Player));
	run;

	*saves room;
	proc delete data=merged;
	run;
	proc delete data=temp;
	run;
	proc delete data=rosters;
	run;
%mend translate;

%macro readData(Team=, Year=, League=);

	data &Team&Year.data;

		infile "&folder.\&Year.&Team..EV&League"
		dlm=','
		truncover;
		
		*get inputs;
		input type $ info $ currTeam $ player $ count $ pitches $ play $;
		
		*get opponents;
		%let visitor = ;
		if type = 'play' or info = 'visteam' or info = 'date';
		if info = 'visteam' then
		do;
			call symputx('visitor', currTeam);
		end;
		if currTeam = '1' then
		do;
			opponent = symget('visitor'); 
		end;
		else
		do;
			opponent = symget('Team');
		end;
    	
		
		*get month;
		%let month = ;		
		if info = 'date' then
		do;
			call symputx('month', substr(currTeam, 6, 2));
		end;
		month = input(symget('month'), 2.);
		
		if type = 'play';

		*get +/- for batting average;
		*remove at bats that do not apply;
		if substr(play,1,1) ^= 'C'; /*interference*/
		if substr(play,1,1) ^= 'W'; /*walk*/
		if substr(play,1,1) ^= 'I'; /*intentional walk*/
		if substr(play,1,2) ^= 'HP'; /*hit by pitch*/
		if substr(play,1,2) ^= 'NP'; /*no play*/
		
		if substr(play,1,1) = 'S' then /*single*/
		do;
			outcome = 1;
		end;
		else if substr(play,1,1) = 'D' then /*double*/
		do;
			outcome = 1;
		end;
		else if substr(play,1,1) = 'T' then /*triple*/
		do;
			outcome = 1;
		end;
		else if substr(play,1,1) = 'H' then /*homerun*/
		do;
			outcome = 1;
		end;
		else
		do;
			outcome = 0;
		end;
		
		
		drop i type info currTeam count pitches play;
	run;

	*adds to year data set;
	data data&year;
		set data&year &team&year.data;
	run;

	*deletes data set to save room;
	proc delete data=&Team&Year.data;
	run;
%mend readData;

%macro createData(year=);
	
	*creates data set to add each teams data to;
	proc delete data=data&year;
	run;
	data data&year;
	run;

	*calls readData for every time thats in the list of teams for that year;
	data teams&year;
		infile "&folder.\TEAM&year"
		dlm=',';
		input Code $ League $ City $ TeamName $;
		drop City TeamName;
		call execute(cats('%nrstr(%readData(team=', code, ', year=', &year, ', league=', league, '))'));
	run;

	*gets rid of first blank observation;
	data data&year;
    	set data&year(firstobs=2);
	run;
	
	*changes player codes to their actual names;
	%translate(year=&year)
%mend createData;

%macro battingAverage(data=);
	*takes in data set adn averages the outcome which is the batting average;
	proc means data=&data noprint;
  		var outcome;
  		output out= &data.Average mean=battingAverage;
	run;
%mend battingAverage;

%macro byOpponentHelper(player=,year=,team=);
	*creates data set for given team and player in the year;
	data teamData;
		set data&year;
		if player = symget('player');
		if opponent = symget('team');
	run;

	*for if the player never played against that team it sets batting average to 0;
	proc sql noprint;
		select count(*) into :nobs
		from teamData;
	quit;
	%if &nobs = 0 %then
	%do;
		data teamData;
			player= symget('player');
			opponent= symget('team');
			month='01';
			outcome=0;
		run;
	%end;

	*gets batting average and creates data set thats just the team name and batting average;
	%battingAverage(data=teamData)
	data teamDataAverage;
		set teamDataAverage;
		opponent = symget('team');
		drop _TYPE_ _FREQ_;
	run;

	*adds to overall dataset;
	data teamAverages;
		set teamAverages teamDataAverage;
	run;

	*saves room;
	proc delete data=teamDataAverage;
	run;
	proc delete data=teamData;
	run;
%mend byOpponentHelper;

%macro byOpponentGraph(player=,year=);
	*creates dataset for that year;
	%createData(year=&year)

	*creates data set that each teams average will get added to;
	data teamAverages;
	run;

	*calls helper for each team;
	data temp;
		set teams&year;
		call execute(cats('%nrstr(%byOpponentHelper(player=&player, year=', &year, ', team=', code, '))'));
	run;

	*saves room;
	proc delete data=temp;
	run;

	*removes blank observation;
	data teamAverages;
		set teamAverages(firstobs=2);
	run;

	*creates table and plot to display data;
	title "Batting Average by Opponent for &player in &year";
	proc print data=teamAverages;
	run;

    proc sgplot data=teamAverages;
        vbar opponent / response=battingAverage;
        xaxis label="Opponent";
        yaxis label="Batting Average";
    run;
    title;

	*saves room;
	proc delete data=teamAverages;
	run;
	proc delete data=data&year;
	run;
%mend byOpponentGraph;

%macro byMonthHelper(player=,year=,month=);
	*selects data from given month and player in the year;
	data monthData;
		set data&year;
		if player = symget('player');
		if month = symget('month');
	run;

	*for if they didn't play that month;
	proc sql noprint;
		select count(*) into :nobs
		from monthData;
	quit;
	%if &nobs = 0 %then
	%do;
		data monthData;
			player= symget('player');
			opponent='';
			month= symget('month');
			outcome=0;
		run;
	%end;
	
	*gets average and creates data set with month and average;
	%battingAverage(data=monthData)
	data monthDataAverage;
		set monthDataAverage;
		month = input(symget('month'), 2.);
		drop _TYPE_ _FREQ_;
	run;

	*adds to overall data set;
	data monthAverages;
		set monthAverages monthDataAverage;
	run;

	*saves room;
	proc delete data=monthDataAverage;
	run;
	proc delete data=monthdata;
	run;
%mend byMonthHelper;

%macro byMonthGraph(player=,year=);

	*creates data for that year to use;
	%createData(year=&year)

	*creates data set to add each month to;
	data monthAverages;
	run;

	*calls helper on every month;
	%do i = 3 %to 10;
        %byMonthHelper(player=&player, year=&year, month=&i)
    %end;
	
	*removes blank observation;
	data monthAverages;
		set monthAverages(firstobs=2);
	run;

	*creates table and graph summary of data;
	title "Batting Average by Month for &player in &year";
	proc print data=monthAverages;
	run;

    proc sgplot data=monthAverages NOAUTOLEGEND;;
        series x=month y=battingAverage;
		scatter x=month y=battingAverage / markerattrs=(symbol=circlefilled);
        xaxis label="Month";
        yaxis label="Batting Average";
    run;
    title;
	
	*saves room;
	proc delete data=monthAverages;
	run;
	proc delete data=data&year;
	run;
%mend byMonthGraph;

%macro createSummary(player=,year=);

	*runs both summarys;
	%byMonthGraph(player=&player,year=&year)
	%byOpponentGraph(player=&player,year=&year)

%mend createSummary;
