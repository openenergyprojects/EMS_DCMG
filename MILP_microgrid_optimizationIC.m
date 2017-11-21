function [Value]=MILP_microgrid_optimizationIC(InputData)
% clear all;
% close all;
% clc;

%input data
% initial_capacity_battery=0; % KWh
% minimum_capacity_battery=0; %KWh
% maximum_capacity_battery=8; %KWh
% 
% max_batt_discharge=3;%KW
% max_batt_charge=3; %KW
% 
% battery_effic_disch=0.95; %it cant be 1. set 0.99
% battery_effic_charge=0.95; %it cant be 1. set 0.99

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%TESLA BATTERY
%input data

maximum_capacity_battery=InputData.maximum_capacity_battery/1000; %=7.5; %KWh
initial_capacity_battery=0.15*maximum_capacity_battery; %=maximum_capacity_battery/2%KWh %S0C_@t=0 starts at 50% from the rated capacity of the battery: 
minimum_capacity_battery=0; %KWh - equivalent with the maximum DoD (depth of discharge) - rtaed value from the manufacturer
maxAllowedDisch=0.15; % in [%] from the maximum_capacity_battery
                      %one may play with this paramter in order to increase the life expectancy of the battery  
max_batt_discharge=InputData.max_batt_discharge/1000; %=5;%KW % rated power for discharge, manufecturer parameter maximum allowed
max_batt_charge=InputData.max_batt_charge/1000; %=2; %KW %5KW %rated power for charging, "------"

battery_effic_disch=0.95; % average efficiency when batt operates in discharging mode, considered const for our optimization model
battery_effic_charge=0.95; %average efficiency when batt operates in charging mode

%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%INVERTER

inverter_size=5;%KW

%discretization of the converter efficiency
efficiencies1=[0.93 0.95 0.96 0.975]; %for a typical DC/DC conveter  - e.g. power exchnage with the neighbors
efficiencies=[0.75 0.9 0.94 0.92]; %we have used four point linearization of a typical efficiency curve of an inverter
bounds_efficiency_temp=[0 10 20 30]; %percentage


%Solver option: 1:Gurobi, 2:Matlab
solver_option=1;
% tic
% % a=importdata('micro_grid_dataIC_selNeig.csv');
% % a=importdata('micro_grid_dataIC_selNeigJan2016_24h.csv'); %needs to be in the same folder as the .m file, otherwise your need to provide the full path
%                                                         %input data for estimated PV and load profiles,
%                                                         %ToU tariffs for the grid power and price of power to be sold/bougth from neighbors
% % a=importdata('micro_grid_dataIC.csv');%no selling or 0 benefit if selling
% % path_data='micro_grid_dataIC.xlsx';
% 
% 
% read_time1=toc
%end of input data
%% ***************************************************************************** 
%data processing
bet=bounds_efficiency_temp;
bounds_efficiency=[bet(1)*inverter_size/100 bet(2)*inverter_size/100 bet(3)*inverter_size/100 bet(4)*inverter_size/100]; %KW
%bounds_efficiency=[0 4 5 6];

% read the input data
% tic
% Load=xlsread(path_data,'A1:A8'); %Load (KW) per each quarter hour
% Load=Load';
% PV=xlsread(path_data,'B1:B8'); %PV generation (KW) per each quarter hour
% PV=PV';
% c=xlsread(path_data,'C1:C8'); %Price of buy 1KWh per each quarter hour
% c=c';
% k=xlsread(path_data,'D1:D8'); %Price of sell 1KWh per each quarter hour
% k=k';
% c=c/4; %Price of buy 1KW continuously for 15 mins
% k=k/4; %Price of sell 1KW continuously for 15 mins
%  
% 
% read_time=toc



% tic
% Load=xlsread(path_data,'N1:N96'); %Load (KW) per each quarter hour
% Load=Load';
% PV=xlsread(path_data,'O1:O96'); %PV generation (KW) per each quarter hour
% PV=PV';
% c=xlsread(path_data,'P1:P96'); %Price of buy 1KWh per each quarter hour
% c=c';
% k=xlsread(path_data,'Q1:Q96'); %Price of sell 1KWh per each quarter hour
% k=k';
% c=c/4; %Price of buy 1KW continually for 15 mins
% k=k/4; %Price of sell 1KW continually for 15 mins
%  
% 
% read_time=toc

%%%%%%%%%%%%%%%%%%%%
tic
% Load=xlsread(path_data,'U1:U192'); %Load (KW) per each quarter hour

%Comment 4 me: we test only for 6 h interval only starting from (5:00 am
%=4*5+1=21 to 13:00 =21+6*4=46)  in order to have the alg running in less
%than 30s
timeStart=InputData.timeStart; %=5 aka 5:00 am in the morning
timeHorizon=InputData.timeHorizon; %=6 hours time horizon - we do not change this
Load= InputData.Pload/1000;           %=a.data(timeStart*4+1:timeStart*4+1+timeHorizon*4,2);%Pload (KW) per each quarter hour
% Load=Load'; %only if it comes from a.data
% PV=xlsread(path_data,'V1:V192'); %PV generation (KW) per each quarter hour
PV=InputData.Ppv/1000; %=2*a.data(timeStart*4+1:timeStart*4+1+timeHorizon*4,3); %multiplied with e.g. 2 in front to get proportional profile for a 4kWp PV sys
% PV=PV'; only for a.data
% c=xlsread(path_data,'W1:W192'); %Price of buy 1KWh per each quarter hour
c=InputData.PriceBuy;%=a.data(timeStart*4+1:timeStart*4+1+timeHorizon*4,4);
% c=c';
% k=xlsread(path_data,'X1:X192'); %Price of selling energy to neighbors 1KWh per each quarter hour
k=InputData.PriceSell; %=a.data(timeStart*4+1:timeStart*4+1+timeHorizon*4,5);
% k=k';
c=c/4; %Price of buying 1KW continuously for 15 mins
k=k/4; %Price of selling 1KW continuously for 15 mins - to neighbors
 
read_time2=toc %send to display the time it took to read the data from the .xlsx file


num_descrit=length(efficiencies);

%end of input data
%% *****************************************************************************    
%prepare the matrixes
icb=initial_capacity_battery;

mincb=0.15*maximum_capacity_battery; %restrict battery to discharge up to e.g. 15% of the rated maximum capacity
                                      %one may play with this coeff dynamically to extend the life of the bat
% mincb=minimum_capacity_battery;
maxcb=0.9*maximum_capacity_battery;

num_of_hours=length(c);

%1D zero element matrix (time intervals)
zeros_1D=zeros(1,num_of_hours);

%2D zero element matrix (time intervals*time intervals)
zeros_2D=zeros(num_of_hours,num_of_hours);

%Create the positive diagonal matrix with 1.
v = ones(1,num_of_hours);
Diag1_pos = diag(v);

%Create the negative diagonal matrix with -1.
v = ones(1,num_of_hours);
v=v.*-1;
Diag1_neg =diag(v);

%Create the negative diagonal battery efficiency.
Diag_neg_disch_eff=Diag1_neg*battery_effic_disch;  %is not implemented yet
Diag_pos_charge_eff=Diag1_pos*(1/battery_effic_charge);
%Create the  diagonal matrix OF THE first efficiency
v = ones(1,num_of_hours);
v=v.*efficiencies(1);
Diag_eff1_pos =diag(v);
Diag_eff1_neg=-Diag_eff1_pos;

%Create the  diagonal matrix OF THE second efficiency
v = ones(1,num_of_hours);
v=v.*efficiencies(2);
Diag_eff2_pos =diag(v);
Diag_eff2_neg=-Diag_eff2_pos;

%Create the  diagonal matrix OF THE third efficiency
v = ones(1,num_of_hours);
v=v.*efficiencies(3);
Diag_eff3_pos =diag(v);
Diag_eff3_neg=-Diag_eff3_pos;

%Create the  diagonal matrix of the fourth efficiency
v = ones(1,num_of_hours);
v=v.*efficiencies(4);
Diag_eff4_pos =diag(v);
Diag_eff4_neg=-Diag_eff4_pos;

%create lower triangular matrix positive and negative
v=tril(ones(num_of_hours,num_of_hours),-1);
pos_triangular=v+Diag1_pos;
neg_triangular=-pos_triangular;
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
pos_triangular=pos_triangular/4; %for quarter hour
neg_triangular=neg_triangular/4;
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%Create the  diagonal matrix OF THE bounds efficiency 
v = ones(1,num_of_hours);
v=v.*bounds_efficiency(1);
Diag_bounds_eff1 =diag(v);

%Create the  diagonal matrix OF THE bounds efficiency 
v = ones(1,num_of_hours);
v=v.*bounds_efficiency(2);
Diag_bounds_eff2 =diag(v);

%Create the  diagonal matrix OF THE bounds efficiency 
v = ones(1,num_of_hours);
v=v.*bounds_efficiency(3);
Diag_bounds_eff3 =diag(v);

%Create the  diagonal matrix OF THE bounds efficiency 
v = ones(1,num_of_hours);
v=v.*bounds_efficiency(4);
Diag_bounds_eff4 =diag(v);
%IC added here: we consider the Load prediction being at the DC side (DC load), therefore its
%equivalent on the AC side corresponds to a lower value (due to DC/AC loss)

Pload_DC=Load;
for i=1:num_of_hours
    if Pload_DC(i)< bounds_efficiency(2)
    Load(i)=Pload_DC(i)*efficiencies(1);
    elseif Pload_DC(i)>= bounds_efficiency(2) && Pload_DC(i)< bounds_efficiency(3)
    Load(i)=Pload_DC(i)*efficiencies(2);
    elseif Pload_DC(i)>= bounds_efficiency(3) && Pload_DC(i)< bounds_efficiency(4)
    Load(i)=Pload_DC(i)*efficiencies(3);
    else    
    Load(i)=Pload_DC(i)*efficiencies(4);
    end;
end;
% fprintf('Equivalent Load at the AC side:\n')
% Load


%create the upper bound value of y1 and y2
upper_y1=max_batt_discharge+max(PV);
upper_y2=max_batt_charge*(1/battery_effic_charge);

%Create the  diagonal matrix of upper bound value of y1 
v = ones(1,num_of_hours);
v=v.*upper_y1; %very big value for ours values
Diag_upper_pos_y1 =diag(v);
Diag_upper_neg_y1 =-Diag_upper_pos_y1;

%Create the  diagonal matrix of upper bound value of y2 
v = ones(1,num_of_hours);
v=v.*upper_y2; %very big value for ours values
Diag_upper_pos_y2 =diag(v);
Diag_upper_neg_y2 =-Diag_upper_pos_y2;
%% *****************************************************************************    
 %Objective Function
%
 % F=[pgrid_pos pgrid_neg bat PDC y1:y4 B1:B4];
 F=[c k*(-1) zeros(1,num_of_hours*4) zeros(1,num_of_hours*4*num_descrit)];

intcon = 6*num_of_hours+num_of_hours*2*num_descrit+1:length(F); %binary variables
% %BOUNDS

%**********Ina***
PgridMax=5; %allow max 5KW or leave it as before %=inf;%limit the power from grid: INA added to avoid spikes in charging batery
%***********
lb=[zeros(1,2*num_of_hours) zeros(1,2*num_of_hours)  zeros(1,2*num_of_hours)  zeros(1,num_of_hours*4*num_descrit) ];
% lb=[ones(1,2*num_of_hours)*(-0.3) zeros(1,2*num_of_hours)  zeros(1,2*num_of_hours)  zeros(1,num_of_hours*4*num_descrit) ];
%we put a limit on the Pgrid to be always greater than 0.3 kW to avoid
%negative sign due to mismatch between prediction and actual, thus we
%replace lb of zeros(1,2*num_of_hours) for the Pgrid_pos with ones(1,2*num_of_hours)*(0.3)

% ub=[ones(1,2*num_of_hours)*(inf)  ones(1,num_of_hours)*(max_batt_discharge) ones(1,num_of_hours)*(max_batt_charge) ones(1,2*num_of_hours)*(inf) ones(1,num_of_hours*4*num_descrit)*(inf) ];
ub=[ones(1,2*num_of_hours)*(PgridMax)  ones(1,num_of_hours)*(max_batt_discharge) ones(1,num_of_hours)*(max_batt_charge) ones(1,2*num_of_hours)*(PgridMax) ones(1,num_of_hours*4*num_descrit)*(PgridMax) ];

 
 %Equalities Constraints
Aeq=[Diag1_pos,Diag1_neg,zeros_2D,zeros_2D,zeros_2D,Diag1_neg,Diag1_pos,Diag1_pos,Diag1_pos,Diag1_pos,zeros_2D,zeros_2D,zeros_2D,zeros_2D,zeros_2D,zeros_2D,zeros_2D,zeros_2D,zeros_2D,zeros_2D,zeros_2D,zeros_2D;
    zeros_2D,zeros_2D,Diag_neg_disch_eff,Diag_pos_charge_eff,Diag1_pos,zeros_2D,zeros_2D,zeros_2D,zeros_2D,zeros_2D,Diag1_neg,Diag1_neg,Diag1_neg,Diag1_neg,zeros_2D,zeros_2D,zeros_2D,zeros_2D,zeros_2D,zeros_2D,zeros_2D,zeros_2D ;
    zeros_2D,zeros_2D,zeros_2D,zeros_2D,zeros_2D,zeros_2D,zeros_2D,zeros_2D,zeros_2D,zeros_2D,zeros_2D,zeros_2D,zeros_2D,zeros_2D,Diag1_pos,Diag1_pos,Diag1_pos,Diag1_pos,Diag1_pos,Diag1_pos,Diag1_pos,Diag1_pos;
    ];

 beq=[Load,PV,ones(1,num_of_hours)];

 %Inequalities Constraints

 A=[zeros_2D,zeros_2D,pos_triangular,neg_triangular,zeros_2D,zeros_2D,zeros_2D,zeros_2D,zeros_2D,zeros_2D,zeros_2D,zeros_2D,zeros_2D,zeros_2D,zeros_2D,zeros_2D,zeros_2D,zeros_2D,zeros_2D,zeros_2D,zeros_2D,zeros_2D;%5constraint
     zeros_2D,zeros_2D,neg_triangular,pos_triangular,zeros_2D,zeros_2D,zeros_2D,zeros_2D,zeros_2D,zeros_2D,zeros_2D,zeros_2D,zeros_2D,zeros_2D,zeros_2D,zeros_2D,zeros_2D,zeros_2D,zeros_2D,zeros_2D,zeros_2D,zeros_2D ;%5constraint
     zeros_2D,zeros_2D,zeros_2D,zeros_2D,Diag1_neg,zeros_2D,zeros_2D,zeros_2D,zeros_2D,zeros_2D,zeros_2D,zeros_2D,zeros_2D,zeros_2D,zeros_2D,Diag_bounds_eff2,Diag_bounds_eff3,Diag_bounds_eff4,zeros_2D,zeros_2D,zeros_2D,zeros_2D;%7constraint
     zeros_2D,zeros_2D,zeros_2D,zeros_2D,zeros_2D,Diag1_neg,zeros_2D,zeros_2D,zeros_2D,zeros_2D,zeros_2D,zeros_2D,zeros_2D,zeros_2D,zeros_2D,zeros_2D,zeros_2D,zeros_2D,zeros_2D,Diag_bounds_eff2,Diag_bounds_eff3,Diag_bounds_eff4;%8constraint
    %
     zeros_2D,zeros_2D,zeros_2D,zeros_2D,zeros_2D,zeros_2D,Diag1_pos,zeros_2D,zeros_2D,zeros_2D,zeros_2D,zeros_2D,zeros_2D,zeros_2D,Diag_upper_neg_y1,zeros_2D,zeros_2D,zeros_2D,zeros_2D,zeros_2D,zeros_2D,zeros_2D; %9constraint Y1.1,B1
    zeros_2D,zeros_2D,zeros_2D,zeros_2D,zeros_2D,zeros_2D,zeros_2D,Diag1_pos,zeros_2D,zeros_2D,zeros_2D,zeros_2D,zeros_2D,zeros_2D,zeros_2D,Diag_upper_neg_y1,zeros_2D,zeros_2D,zeros_2D,zeros_2D,zeros_2D,zeros_2D; %9constraint Y1.2,B2
     zeros_2D,zeros_2D,zeros_2D,zeros_2D,zeros_2D,zeros_2D,zeros_2D,zeros_2D,Diag1_pos,zeros_2D,zeros_2D,zeros_2D,zeros_2D,zeros_2D,zeros_2D,zeros_2D,Diag_upper_neg_y1,zeros_2D,zeros_2D,zeros_2D,zeros_2D,zeros_2D; %9constraint Y1.3,B3
     zeros_2D,zeros_2D,zeros_2D,zeros_2D,zeros_2D,zeros_2D,zeros_2D,zeros_2D,zeros_2D,Diag1_pos,zeros_2D,zeros_2D,zeros_2D,zeros_2D,zeros_2D,zeros_2D,zeros_2D,Diag_upper_neg_y1,zeros_2D,zeros_2D,zeros_2D,zeros_2D; %9constraint Y1.4,B4
     %
      zeros_2D,zeros_2D,zeros_2D,zeros_2D,zeros_2D,zeros_2D,zeros_2D,zeros_2D,zeros_2D,zeros_2D,Diag1_pos,zeros_2D,zeros_2D,zeros_2D,zeros_2D,zeros_2D,zeros_2D,zeros_2D,Diag_upper_neg_y2,zeros_2D,zeros_2D,zeros_2D; %9constraint Y2.1,Z1
    zeros_2D,zeros_2D,zeros_2D,zeros_2D,zeros_2D,zeros_2D,zeros_2D,zeros_2D,zeros_2D,zeros_2D,zeros_2D,Diag1_pos,zeros_2D,zeros_2D,zeros_2D,zeros_2D,zeros_2D,zeros_2D,zeros_2D,Diag_upper_neg_y2,zeros_2D,zeros_2D; %9constraint Y2.2,Z2
     zeros_2D,zeros_2D,zeros_2D,zeros_2D,zeros_2D,zeros_2D,zeros_2D,zeros_2D,zeros_2D,zeros_2D,zeros_2D,zeros_2D,Diag1_pos,zeros_2D,zeros_2D,zeros_2D,zeros_2D,zeros_2D,zeros_2D,zeros_2D,Diag_upper_neg_y2,zeros_2D; %9constraint Y2.3,Z3
     zeros_2D,zeros_2D,zeros_2D,zeros_2D,zeros_2D,zeros_2D,zeros_2D,zeros_2D,zeros_2D,zeros_2D,zeros_2D,zeros_2D,zeros_2D,Diag1_pos,zeros_2D,zeros_2D,zeros_2D,zeros_2D,zeros_2D,zeros_2D,zeros_2D,Diag_upper_neg_y2; %9constraint Y2.4,Z4
     %
     zeros_2D,zeros_2D,zeros_2D,zeros_2D,Diag_eff1_neg,zeros_2D,Diag1_pos,zeros_2D,zeros_2D,zeros_2D,zeros_2D,zeros_2D,zeros_2D,zeros_2D,zeros_2D,zeros_2D,zeros_2D,zeros_2D,zeros_2D,zeros_2D,zeros_2D,zeros_2D; %10constraint Y1.1,X1
     zeros_2D,zeros_2D,zeros_2D,zeros_2D,Diag_eff2_neg,zeros_2D,zeros_2D,Diag1_pos,zeros_2D,zeros_2D,zeros_2D,zeros_2D,zeros_2D,zeros_2D,zeros_2D,zeros_2D,zeros_2D,zeros_2D,zeros_2D,zeros_2D,zeros_2D,zeros_2D; %10constraint Y1.2,X1
     zeros_2D,zeros_2D,zeros_2D,zeros_2D,Diag_eff3_neg,zeros_2D,zeros_2D,zeros_2D,Diag1_pos,zeros_2D,zeros_2D,zeros_2D,zeros_2D,zeros_2D,zeros_2D,zeros_2D,zeros_2D,zeros_2D,zeros_2D,zeros_2D,zeros_2D,zeros_2D; %10constraint Y1.3,X1
     zeros_2D,zeros_2D,zeros_2D,zeros_2D,Diag_eff4_neg,zeros_2D,zeros_2D,zeros_2D,zeros_2D,Diag1_pos,zeros_2D,zeros_2D,zeros_2D,zeros_2D,zeros_2D,zeros_2D,zeros_2D,zeros_2D,zeros_2D,zeros_2D,zeros_2D,zeros_2D; %10constraint Y1.4,X1
     %
     zeros_2D,zeros_2D,zeros_2D,zeros_2D,zeros_2D,Diag_eff1_neg,zeros_2D,zeros_2D,zeros_2D,zeros_2D,Diag1_pos,zeros_2D,zeros_2D,zeros_2D,zeros_2D,zeros_2D,zeros_2D,zeros_2D,zeros_2D,zeros_2D,zeros_2D,zeros_2D; %10constraint Y2.1,X2
     zeros_2D,zeros_2D,zeros_2D,zeros_2D,zeros_2D,Diag_eff2_neg,zeros_2D,zeros_2D,zeros_2D,zeros_2D,zeros_2D,Diag1_pos,zeros_2D,zeros_2D,zeros_2D,zeros_2D,zeros_2D,zeros_2D,zeros_2D,zeros_2D,zeros_2D,zeros_2D; %10constraint Y2.2,X2
     zeros_2D,zeros_2D,zeros_2D,zeros_2D,zeros_2D,Diag_eff3_neg,zeros_2D,zeros_2D,zeros_2D,zeros_2D,zeros_2D,zeros_2D,Diag1_pos,zeros_2D,zeros_2D,zeros_2D,zeros_2D,zeros_2D,zeros_2D,zeros_2D,zeros_2D,zeros_2D; %10constraint Y2.3,X2
     zeros_2D,zeros_2D,zeros_2D,zeros_2D,zeros_2D,Diag_eff4_neg,zeros_2D,zeros_2D,zeros_2D,zeros_2D,zeros_2D,zeros_2D,zeros_2D,Diag1_pos,zeros_2D,zeros_2D,zeros_2D,zeros_2D,zeros_2D,zeros_2D,zeros_2D,zeros_2D; %10constraint Y2.4,X2
     %
      %
     zeros_2D,zeros_2D,zeros_2D,zeros_2D,Diag_eff1_pos,zeros_2D,Diag1_neg,zeros_2D,zeros_2D,zeros_2D,zeros_2D,zeros_2D,zeros_2D,zeros_2D,Diag_upper_pos_y1,zeros_2D,zeros_2D,zeros_2D,zeros_2D,zeros_2D,zeros_2D,zeros_2D; %11constraint Y1.1,X1,B1
     zeros_2D,zeros_2D,zeros_2D,zeros_2D,Diag_eff2_pos,zeros_2D,zeros_2D,Diag1_neg,zeros_2D,zeros_2D,zeros_2D,zeros_2D,zeros_2D,zeros_2D,zeros_2D,Diag_upper_pos_y1,zeros_2D,zeros_2D,zeros_2D,zeros_2D,zeros_2D,zeros_2D; %11constraint Y1.2,X1,B1
     zeros_2D,zeros_2D,zeros_2D,zeros_2D,Diag_eff3_pos,zeros_2D,zeros_2D,zeros_2D,Diag1_neg,zeros_2D,zeros_2D,zeros_2D,zeros_2D,zeros_2D,zeros_2D,zeros_2D,Diag_upper_pos_y1,zeros_2D,zeros_2D,zeros_2D,zeros_2D,zeros_2D; %11constraint Y1.3,X1,B1
     zeros_2D,zeros_2D,zeros_2D,zeros_2D,Diag_eff4_pos,zeros_2D,zeros_2D,zeros_2D,zeros_2D,Diag1_neg,zeros_2D,zeros_2D,zeros_2D,zeros_2D,zeros_2D,zeros_2D,zeros_2D,Diag_upper_pos_y1,zeros_2D,zeros_2D,zeros_2D,zeros_2D; %11constraint Y1.4,X1,B1
     %
     zeros_2D,zeros_2D,zeros_2D,zeros_2D,zeros_2D,Diag_eff1_pos,zeros_2D,zeros_2D,zeros_2D,zeros_2D,Diag1_neg,zeros_2D,zeros_2D,zeros_2D,zeros_2D,zeros_2D,zeros_2D,zeros_2D,Diag_upper_pos_y2,zeros_2D,zeros_2D,zeros_2D; %11constraint Y2.1,X2,B2
     zeros_2D,zeros_2D,zeros_2D,zeros_2D,zeros_2D,Diag_eff2_pos,zeros_2D,zeros_2D,zeros_2D,zeros_2D,zeros_2D,Diag1_neg,zeros_2D,zeros_2D,zeros_2D,zeros_2D,zeros_2D,zeros_2D,zeros_2D,Diag_upper_pos_y2,zeros_2D,zeros_2D; %11constraint Y2.2,X2,B2
     zeros_2D,zeros_2D,zeros_2D,zeros_2D,zeros_2D,Diag_eff3_pos,zeros_2D,zeros_2D,zeros_2D,zeros_2D,zeros_2D,zeros_2D,Diag1_neg,zeros_2D,zeros_2D,zeros_2D,zeros_2D,zeros_2D,zeros_2D,zeros_2D,Diag_upper_pos_y2,zeros_2D; %11constraint Y2.3,X2,B2
     zeros_2D,zeros_2D,zeros_2D,zeros_2D,zeros_2D,Diag_eff4_pos,zeros_2D,zeros_2D,zeros_2D,zeros_2D,zeros_2D,zeros_2D,zeros_2D,Diag1_neg,zeros_2D,zeros_2D,zeros_2D,zeros_2D,zeros_2D,zeros_2D,zeros_2D,Diag_upper_pos_y2; %11constraint Y2.4,X2,B2
    
      zeros_2D,zeros_2D,zeros_2D,zeros_2D,Diag1_pos,zeros_2D,zeros_2D,zeros_2D,zeros_2D,zeros_2D,zeros_2D,zeros_2D,zeros_2D,zeros_2D,Diag_bounds_eff2*(-1),Diag_bounds_eff3*(-1),Diag_bounds_eff4*(-1),Diag1_neg*inverter_size,zeros_2D,zeros_2D,zeros_2D,zeros_2D;%12constraint
     zeros_2D,zeros_2D,zeros_2D,zeros_2D,zeros_2D,Diag1_pos,zeros_2D,zeros_2D,zeros_2D,zeros_2D,zeros_2D,zeros_2D,zeros_2D,zeros_2D,zeros_2D,zeros_2D,zeros_2D,zeros_2D,Diag_bounds_eff2*(-1),Diag_bounds_eff3*(-1),Diag_bounds_eff4*(-1),Diag1_neg*inverter_size;%13constraint
     ];
     
 
 b=[ones(1,num_of_hours)*(icb-mincb),ones(1,num_of_hours)*(maxcb-icb),zeros(1,2*num_of_hours),zeros(1,2*8*num_of_hours),ones(1,4*num_of_hours)*upper_y1,ones(1,4*num_of_hours)*upper_y2,zeros(1,2*num_of_hours)];
 
% %% *****************************************************************************    
%% *****************************************************************************    
%Call the solver
if solver_option==2
%Call Matlab MILP
    tic;
    options = optimoptions('intlinprog','Display','off');
    [x,fval] = intlinprog(F,intcon,A,b,Aeq,beq,lb,ub, '');
    toc;

elseif   solver_option==1
%Call Gurobi MILP
    path_Gurobi='gurobi';
     addpath(path_Gurobi) %if you choose gurobi for dispatch, then run gurobi_setup
            savepath();
    f=F;

    nargin=8;
    if nargin < 4
        error('intlinprog(f, intcon, A, b)')
    end

    if nargin > 8
        error('intlinprog(f, intcon, A, b, Aeq, beq, lb, ub)');
    end

    if ~isempty(A)
        n = size(A, 2);
    elseif nargin > 5 && ~isempty(Aeq)
        n = size(Aeq, 2);
    else
        error('No linear constraints specified')
    end

    if ~issparse(A)
        AA = sparse(A);
    end

    if nargin > 4 && ~issparse(Aeq)
        Aeqq = sparse(Aeq);
    end

    model.obj = f;
    model.vtype = repmat('C', n, 1);
    model.vtype(intcon) = 'I';

    if nargin < 5
        model.A = AA;
        model.rhs = b;
        model.sense = '<';
    else
        model.A = [AA; Aeqq];
        model.rhs = [b'; beq'];
        model.sense = [repmat('<', size(A,1), 1); repmat('=', size(Aeq,1), 1)];
    end

    if nargin < 7
        model.lb = -inf(n,1);
    else
        model.lb = lb;
    end

    if nargin == 8
       model.ub = ub;
    end

    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
  %  params.MIPGap=1e-3;
   %  params.FeasibilityTol=1e-4;
   % params.IntFeasTol=1e-3;
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    
    params.outputflag = 0;
    tic
    result = gurobi(model, params);
    toc

    if strcmp(result.status, 'OPTIMAL')
        exitflag = 1;
    elseif strcmp(result.status, 'INTERRUPTED')
        if isfield(result, 'x')
            exitflag = 2;
        else
            exitflag = 0;
        end
    elseif strcmp(result.status, 'INF_OR_UNBD')
        params.dualreductions = 0;
        result = gurobi(model, params);
        if strcmp(result.status, 'INFEASIBLE')
            exitflag = -2;
        elseif strcmp(result.status, 'UNBOUNDED')
            exitflag = -3;
        else
            exitflag = nan;
        end
    else
        exitflag = nan;
    end


    if isfield(result, 'x')
        x = result.x;
    else
        x = nan(n,1);
    end

    if isfield(result, 'objval')
        fval = result.objval;
    else
        fval = nan;
    end

end; %if

%% *****************************************************************************    
%Total COST without the battery
% Buy energy= Load -PV (if it is negative then you sell energy)

for i=1:num_of_hours
    if PV(i)< bounds_efficiency(2)
    PV_NET(i)=PV(i)*efficiencies(1);
    elseif PV(i)>= bounds_efficiency(2) && PV(i)< bounds_efficiency(3)
    PV_NET(i)=PV(i)*efficiencies(2);
    elseif PV(i)>= bounds_efficiency(3) && PV(i)< bounds_efficiency(4)
    PV_NET(i)=PV(i)*efficiencies(3);
    else    
    PV_NET(i)=PV(i)*efficiencies(4);
    end;
end;
Cost_without_battery=0;
for i=1:num_of_hours
    NET_DEMAND(i)=Load(i)-PV_NET(i);
    if NET_DEMAND(i)>=0
       Cost_without_battery=Cost_without_battery+NET_DEMAND(i)*c(i);
    else    
       Cost_without_battery=Cost_without_battery+NET_DEMAND(i)*k(i);
    end;    
end;

Cost_without_battery/100 % in Euros
fprintf('Cost_without_battery=%d in euros',Cost_without_battery/100)

%% *****************************************************************************    

Pbuy_interval=x(1:num_of_hours);
Psell_interval=x(num_of_hours+1:2*num_of_hours);
Pbattery_inter_disch=x(2*num_of_hours+1:3*num_of_hours);
Pbattery_inter_charge=x(3*num_of_hours+1:4*num_of_hours);
Px1_interval=x(4*num_of_hours+1:5*num_of_hours);
Px2_interval=x(5*num_of_hours+1:6*num_of_hours);
Py11_interval=x(6*num_of_hours+1:7*num_of_hours);
Py12_interval=x(7*num_of_hours+1:8*num_of_hours);
Py13_interval=x(8*num_of_hours+1:9*num_of_hours);
Py14_interval=x(9*num_of_hours+1:10*num_of_hours);
Py21_interval=x(10*num_of_hours+1:11*num_of_hours);
Py22_interval=x(11*num_of_hours+1:12*num_of_hours);
Py23_interval=x(12*num_of_hours+1:13*num_of_hours);
Py24_interval=x(13*num_of_hours+1:14*num_of_hours);
%ICadded the following line:
Py2_interval=Py21_interval+Py22_interval+Py23_interval+Py24_interval;

% %check on DC bus balance:
% fprintf('ckeck balance eq on the DC bus:\n')
% PV'+Pbattery_inter_disch+Py2_interval-Px1_interval-Pbattery_inter_charge

B1_interval=x(14*num_of_hours+1:15*num_of_hours);
B2_interval=x(15*num_of_hours+1:16*num_of_hours);
B3_interval=x(16*num_of_hours+1:17*num_of_hours);
B4_interval=x(17*num_of_hours+1:18*num_of_hours);
Z1_interval=x(18*num_of_hours+1:19*num_of_hours);
Z2_interval=x(19*num_of_hours+1:20*num_of_hours);
Z3_interval=x(20*num_of_hours+1:21*num_of_hours);
Z4_interval=x(21*num_of_hours+1:22*num_of_hours);



%TOTAL COST OF OPERATION
Total_Cost_of_Operation=(c*Pbuy_interval-k*Psell_interval)/100 %Euros

%% Plots here, un-comment when needed
% % % x_time=[timeStart:1/4:timeStart+timeHorizon];
% % % X=linspace(0,24,length(Load));
% % % figure(1);
% % % subplot(2,2,1)
% % % stem(X,Pbuy_interval,'BaseValue',0)
% % % title('Scheduling of Grid Energy')
% % % xlabel('Time (h)')
% % % ylabel(' Buy Grid Energy(KW)')
% % % 
% % % subplot(2,2,2)
% % % stem(X, Load)
% % % title(' Load')
% % % xlabel('Time (h)')
% % % ylabel('(KW)')
% % % 
% % % subplot(2,2,3)
% % % stem(X, c,'BaseValue',0)
% % % % hold on;
% % % % stem(-k,'BaseValue',0)
% % % title(' Tarif of grid electricity')
% % % xlabel('Time (h)')
% % % ylabel(' Tariff(cents/KW for 15min)')
% % % 
% % % subplot(2,2,4)
% % % stem(X, Pbattery_inter_disch-Pbattery_inter_charge,'BaseValue',0)
% % % title('Charge/Discharge Energy')
% % % xlabel('Time (h)')
% % % ylabel(' Charge/Discharge(KW)')
 

%TO DIA 4 EN GIA QUARTER THS WRAS
battery_power_per_hour(1)=icb-Pbattery_inter_disch(1)/4+Pbattery_inter_charge(1)/4;
for i=2:num_of_hours
battery_power_per_hour(i)=battery_power_per_hour(i-1)-Pbattery_inter_disch(i)/4+Pbattery_inter_charge(i)/4;
end;

%% Plots here: un-comment when needed
% % % figure(2);
% % % subplot(2,2,1)
% % % stem(X,battery_power_per_hour)
% % % title('Capacity level of the battery for each quarter of hour')
% % % xlabel('Time (h)')
% % % ylabel('(KWh)')
% % % 
% % % subplot(2,2,2)
% % % stem(X,PV)
% % % title('PV Generation for each quarter of hour')
% % % xlabel('Time (h)')
% % % ylabel('(KW)')
% % % 
% % % subplot(2,2,3)
% % % stem(X,Load)
% % % title(' Load')
% % % xlabel('Time (h)')
% % % ylabel('(KW)')
% % % 
% % % figure(3)
% % % plot(x_time(1:end-1),Pbuy_interval(1:end-1), '.-b',...
% % %     x_time(1:end-1),Psell_interval(1:end-1), 'o',...
% % %      x_time(1:end-1),Load(1:end-1), '.-r',...
% % %      x_time(1:end-1),PV(1:end-1), '.-y',...
% % %      x_time(1:end-1),Pbattery_inter_disch(1:end-1), '.-k', ...
% % %      x_time(1:end-1),-Pbattery_inter_charge(1:end-1), '.-g');
% % % title('Scheduling of Grid Energy')
% % % xlabel('Time (h)')
% % % ylabel ('Power (kW)')
% % % legend('Pgrid', 'Psold', 'Pload', 'Ppv', 'Pbat-Disch', 'Pbat-Charge');

Pgrid=Pbuy_interval;

for i=1:num_of_hours
    if Pgrid(i)< bounds_efficiency(2)
    Pgrid_DC(i)=Pgrid(i)*efficiencies(1);
    elseif Pgrid(i)>= bounds_efficiency(2) && Pgrid(i)< bounds_efficiency(3)
    Pgrid_DC(i)=Pgrid(i)*efficiencies(2);
    elseif Pgrid(i)>= bounds_efficiency(3) && Pgrid(i)< bounds_efficiency(4)
    Pgrid_DC(i)=Pgrid(i)*efficiencies(3);
    else    
    Pgrid_DC(i)=Pgrid(i)*efficiencies(4);
    end;
end;

% Pgrid_DC=Py2_interval; %might not be correct let's check this first
% fprintf('size of Pgrid_DC: \n')
% size(Pgrid_DC)

% Pneigh_buy is input data read from the inputData file

%Added 20171010.......
% Pneigh_sell=Psell_interval;
% fprintf('size of Pneigh_sell: \n')
% size(Pneigh_sell)
%*************************......

Ppv=PV;
% fprintf('size of Ppv: \n')
% size(Ppv)

Pbat= Pbattery_inter_disch-Pbattery_inter_charge;
% fprintf('size of Pbat: \n')
% size(Pbat)


% Pload=Load;
% for i=1:num_of_hours
%     if Pload(i)< bounds_efficiency(2)
%     Pload_DC(i)=Pload(i)*efficiencies(1);
%     elseif Pload(i)>= bounds_efficiency(2) && Pload(i)< bounds_efficiency(3)
%     Pload_DC(i)=Pload(i)*efficiencies(2);
%     elseif Pload(i)>= bounds_efficiency(3) && Pload(i)< bounds_efficiency(4)
%     Pload_DC(i)=Pload(i)*efficiencies(3);
%     else    
%     Pload_DC(i)=Pload(i)*efficiencies(4);
%     end;
% end;

% fprintf('size of Pload_DC: \n')
% size(Pload_DC)

%updated 20171010 from here till ...see...END 20171010
Pneigh_sell=Psell_interval;
Pneigh_sell_DC=Pneigh_sell;%the selling to neigh is at the DC side
% for i=1:num_of_hours
%     if Pneigh_sell(i)< bounds_efficiency(2)
%     Pneigh_sell_DC(i)=Pneigh_sell(i)*efficiencies(1);
%     elseif Pneigh_sell(i)>= bounds_efficiency(2) && Pneigh_sell(i)< bounds_efficiency(3)
%     Pneigh_sell_DC(i)=Pneigh_sell(i)*efficiencies(2);
%     elseif Pneigh_sell(i)>= bounds_efficiency(3) && Pneigh_sell(i)< bounds_efficiency(4)
%     Pneigh_sell_DC(i)=Pneigh_sell(i)*efficiencies(3);
%     else    
%     Pneigh_sell_DC(i)=Pneigh_sell(i)*efficiencies(4);
%     end;
% end;

x_time=InputData.timeStart:1/4:InputData.timeStart+InputData.timeHorizon-1/4;
x_time=x_time';
% % fprintf('size x_time:\n')
% % size(x_time)
% % fprintf('Pgrid_DC:\n')
% % size(Pgrid_DC')
% % fprintf('Pbuy_grid_AC:\n')
% % size(Pbuy_interval)
% % fprintf('Psell_neigh:\n')
% % size(Psell_interval)
% % fprintf('Pload:\n')
% % size(Load)
% % fprintf('PV:\n')
% % size(PV)
% % fprintf('Pbat:\n')
% % size(Pbattery_inter_disch)
% % 
% % figure()
% % plot(x_time(1:end),Pbuy_interval, '.-b',...
% %     x_time(1:end),-Psell_interval, 'o',...
% %      x_time(1:end),-Load', '.-r',...
% %      x_time(1:end),PV', '.-y',...
% %      x_time(1:end),Pbattery_inter_disch, '.-k', ...
% %      x_time(1:end),-Pbattery_inter_charge, '.-g');
% % title('Scheduling of Grid Energy')
% % xlabel('Time (h)')
% % ylabel ('Power (kW)')
% % legend('Pgrid', 'Psold', 'Pload', 'Ppv', 'Pbat-Disch', 'Pbat-Charge');

% fprintf('size of Pneigh_sell_DC: \n')
% size(Pneigh_sell_DC)
% Pneigh_sell_DC=Px1_interval-Pload_DC';
% Pneigh_sell=min((Ppv'-Pload_DC'+Pbat),0)
% PgridBalanceCheck=Pgrid_DC'+Ppv'-Pload_DC'-Pneigh_sell_DC'+Pbat
% Pgrid_DC
% Pgrid


% % figure()
% % plot(x_time(1:end),Pgrid_DC', '.-b',...
% %     x_time(1:end),-Pneigh_sell_DC', 'o',...
% %      x_time(1:end),-Pload_DC', '.-r',...
% %      x_time(1:end),Ppv', '.-y',...
% %      x_time(1:end),Pbattery_inter_disch, '.-k', ...
% %      x_time(1:end),-Pbattery_inter_charge, '.-g');
% % title('Scheduling of Grid Energy DC side')
% % xlabel('Time (h)')
% % ylabel ('Power (kW)')
% % legend('PgridDC', 'PneighSell', 'PloadDC', 'Ppv', 'Pbat-Disch', 'Pbat-Charge');

% fprintf('size PV:\n')
% size(Ppv')
% fprintf('size Pload_DC:\n')
% size(Pload_DC')
% fprintf('size Psell_DC:\n')
% size(Pneigh_sell_DC')
% fprintf('size Pbat:\n')
% size(Pbat)
% fprintf('size Pgrid_DC:\n')
% size(Pgrid_DC')

Value=[Ppv' -Pload_DC' -Pneigh_sell_DC Pbat Pgrid_DC'];
% figure()
% plot(x_time(1:end),Ppv', '.-y',...
%     x_time(1:end),-Pload_DC', '.-r',...
%      x_time(1:end),-Pneigh_sell_DC, '.-b',...
%      x_time(1:end),Pbat, '.-g',...
%      x_time(1:end),Pgrid_DC', '.-k');
% title('Scheduling of Grid Energy DC side')
% xlabel('Time (h)')
% ylabel ('Power (kW)')
% legend('Ppv', 'Pload', 'Psell_neigh', 'Pbat', 'Pgrid');
% x1=Px1_interval
% sum(Value,2)