/*Instructions for running this code
Step 1: Update folder macro variable to be the proper folder for the data's location
Step 2: Run macros.sas in the same folder to enable the macros
Step 3: Choose a player from on of the .ROS fles
Step 4: Run one of the three macros:
	%byMonthGraph - A summary and series plot of the players batting average in said year
	%byOpponentGraph -  A summary and bar graph of the players batting average by the opponent in said year
	%createSummary - Both above summarys
	all three macros are ran by using %chosenSummary(player=Player Name,year=Desired Year)
		Examples for all three are given below
*/

/*Code for Running Macros-----------------------------------------------*/
%let folder= M:\sta402\termproject\data;/*update this with your folder for the data*/

%createSummary(player=Kevin Millar,year=2008)/*Examples used in report for the full summary*/
/*%createSummary(player=Juan Soto,year=2022)

%byMonthGraph(player=Kevin Millar,year=2008)/*Example to only get the by month report*/

/*%byOpponentGraph(player=Juan Soto,year=2022)/*Example to only get the by opponet report*/
