%%%%%%%%% HEMS SCRIPT %%%%%%%%%
clear all;
close all;
clc;
%% Start communication with dSAPCE
[maPort,testBench]=OpenPortAPI('\MAPortConfiguration.xml'); %IC: we do not need to change here,
                                                        %might be the path but we should put everithing in the same folder and work as it is

%%My Code here: IC
% inputFileName='d:\work\_ina\H2020_MarieCurie_MSCA_IF\2016_H2020_MSCA_Irina_DCNextEve\WP3\AAU_TestLab_MILP_IC\micro_grid_dataIC_selNeigJan2016_24h.csv'; %file name where the input data for the EMS is stored
% EMStimeStart=5; %means 5 am in the morning; if we want to start at 5:15am then we need to write 5.25 (0.25 <=> 15 min time interval)
% EMStimeStop=13; %13:00 o'clock

%Calling the EMS function to get the schedule for the next time horizon
%Ppv, Pload, Pbat, Pneigh_sell are all vector of lenth equal to the
%timehorizon in h*4 (15 min rezolution)

% [Pgrid,Pneigh_buy, Ppv, Pload, Pbat, Pneigh_sell,Total_Cost_of_Operation]=EMS_MILP_IC(inputFileName, EMStimeStart, EMStimeStop);

%Scenario1: MG1: summer (load and PV - random cluster choice)
%reading 24h input data 
tic
load MG1_PV_forecast_summer30h;
load MG1_Load30h_15min;
load MG1_PV_real_summer;
load MG1_Load_real;

%PV
PV_24h=MG1_PV_forecast_summer30h';
PV_real_24h=MG1_PV_real_summer';
%load
Pload_24h=MG1_Load30h_15min; %in W
Pload_real_24h=MG1_Load_real;

% load MG2_PV_forecast_summer30h;
% load MG2_Load30h_15min;
% load MG2_PV_real_summer;
% load MG2_Load_real;

InputData.timeStart=0;
InputData.timeHorizon=6;
InputData.maximum_capacity_battery=2000; %Wh
InputData.max_batt_discharge=1000; %W
InputData.max_batt_charge=1000; %W
InputData.SoC=0.5*InputData.maximum_capacity_battery; %Wh
PriceBuy=[repmat(9.33,1,28) repmat(16.05,1,44) repmat(12.07,1,16) repmat(9.33,1,8) repmat(9.33,1,24)];
PriceSell=repmat(0.3,1,120);

%These shall be the input data for the next EMS call
% InputData.Pload=Pload_24h(InputData.timeStart*4+1:4*(InputData.timeStart+InputData.timeHorizon));
% InputData.Ppv=PV_24h(InputData.timeStart*4+1:4*(InputData.timeStart+InputData.timeHorizon));
% InputData.PriceBuy=PriceBuy(InputData.timeStart*4+1:4*(InputData.timeStart+InputData.timeHorizon));
% InputData.PriceSell=PriceSell(InputData.timeStart*4+1:4*(InputData.timeStart+InputData.timeHorizon));
read_time2=toc; %send to display the time it took to read the data

%[References]=MILP_microgrid_optimizationIC(InputData);

%These are the initial values at time 0 (EMS and real-time match)
PSF=[2/2,2/3.5,2/4,2/4]*1000;% Power Scaling factor
%References=Value(1,:).*PSF; %Pgrid is the sluck taking care of the voltage regulation and the output of the LabMeasurements
% we update at each run-time a single value for each of the 4 vars

WriteVariables(maPort,testBench,[0,0,0,0]); %IC: we do not change this line

%% Timer initialization moved from few lines down where there is the same
%header text

diff3Min = 0;diff15Min = 0;
counter3min = 0;counter15min = 0;
%IC: I think here we shall replace the vector [0,0,0,0] with 
% PV_real=MG1_PV_real_summer(InputData.timeStart+counter15min+1);
% Pload_real=MG1_Load_real(InputData.timeStart+counter15min+1);
%WriteVariables(maPort,testBench,[PV_real,Pload_real,0,0]);
%the first input from the real values from MG1_PV_real_summer.mat & MG1_Load_real.mat
%

%% Your own things before starting

%% Timer initialization
RTtimeStamp_ini = posixtime(datetime('now')); %This funciton gives you the elapsed time since 1 Jan 1970 in seconds
%RTtimeStamp_end = posixtime(datetime('now')+3/24); % date time units are days, posixtime are seconds.
lastTime3Min = posixtime(datetime('now'));
lastTime15Min = posixtime(datetime('now'));



%% Initialize Variables that you will read form the setup
L=24*4;%hours of experiment
Nread=L*5; %Data size for reading every minute for 3 days
Preal1 = zeros(1,Nread);
Preal2 = zeros(1,Nread);
Preal3 = zeros(1,Nread);
Preal4 = zeros(1,Nread);
Preal5 = zeros(1,Nread);
RTtimeStamp = zeros(1,Nread);
PbatMeasured = zeros(1,Nread);
References=zeros(1,L);

%% RUNTIME 
%show(:,1)={'Counter 1h';'Counter 5min';'WT';'PV';'Lift';'Light';'CHP';'EV';'Pac (dc)';'Pgrid (kW)'};
while (true)
    diff3Min = posixtime(datetime('now')) - lastTime3Min;
    diff15Min= posixtime(datetime('now')) - lastTime15Min;
    
    
    if(diff3Min > 2) %I do something every 10 seconds (5 minutes in simulation)
        counter3min=counter3min + 1;
       %Captures
       [ValueRead]=ReadVariables(maPort);
       Preal1(counter3min)=ValueRead.Pdc1.Value; %PV real +
       Preal2(counter3min)=ValueRead.Pdc2.Value; %Pload real -
       Preal3(counter3min)=ValueRead.Pdc3.Value; %Pneigh selling -
       Preal4(counter3min)=ValueRead.Pdc4.Value; %Pgrid (References(:,5))
       Preal5(counter3min)=ValueRead.Pdc5.Value; %Pbat_,measured
       %fprintf('we expect here Pbat_meaasured to be in kW:\n');
       PbatMeasured(counter3min)=-(Preal1(counter3min)./PSF(1)+Preal2(counter3min)./PSF(2)+Preal3(counter3min)./PSF(3)+Preal4(counter3min)./PSF(4)); %kW
       InputData.SoC=InputData.SoC+PbatMeasured(counter3min)*1000*1/20; %Wh
       
%        %IC: place all readings in a matrix ValueRead2EMS
%        ValueRead2EMS=[Preal1' Preal2' Preal3' Preal4' Preal5']; %where Preal1..5 are PV, Load on the DC side, Neigh_DCside, BT and Pgrid_dc side respectively,
%                                                             %each Preal1 ...5 has to be a column vector, where each line of it is the reading every 3 min
%                                                             %if they are not column vectors, then make the transpose HERE
%        %end IC 
       
       lastTime3Min= posixtime(datetime('now'));
       
    end
    %*********************************************************************
    %IC: average the first 3 values read from the RealTime measurements
    
    
%        if counter3min>3 
%        ValueRead2EMSAvg=mean(ValueRead2EMS);
%        end
% LETS CHANGES THIS TO THE EMS LOOP

    
    % ********************************************************************
    %Timer 5min -> Change Refernces
    if(diff15Min > 10) %I do something every 2 seconds (1 minute in simulation)
        counter15min=counter15min+1;
        % DATA CONDITIONING FOR EMS
      % we use these values to update the forecasted input in the next call of the EMS function
      %we maek the updates as follows: for the next 15 min t0 in the EMS predition is the average between what was measured in the last
      %interval (average values for 15 min) and what was predicted for the next interval
      %update the first 2 entries for next EMS call using measured data in from the RealTime platform 
      %fprintf('InputData.timeStart shall be now = to 2 \n')
      InputData.timeStart=counter15min; %update start time for the rolling planning to the next EMS call (every 15 min) aka next entry in the InputData vector
                                                            % InputData.timeStart shall be now = to 2
% %       %update InputData.Ppv for the next EMS call
% % %       InputData.Ppv(1:24)= MG2_PV_24h_summer(InputData.timeStart:InputData.timeStart+4*InputData.timeHorizon-1); 
% % %       InputData.Ppv(1)=(InputData.Ppv(1)+mean(Preal1(counter3min-2:counter3min)))/2;
% % %       InputData.Ppv(2)=0.5*(InputData.Ppv(2)+InputData.Ppv(1))/2+0.3*InputData.Ppv(2)+0.2*InputData.Ppv(3);
      
      %from Test:%update InputData.Ppv for the next EMS call
%       InputData.Pload=Pload_24h(InputData.timeStart:InputData.timeStart+4*InputData.timeHorizon-1);
%       InputData.Ppv=PV_24h(InputData.timeStart:InputData.timeStart+4*InputData.timeHorizon-1);
%       InputData.PriceBuy=PriceBuy(InputData.timeStart:InputData.timeStart+4*InputData.timeHorizon-1);
%       InputData.PriceSell=PriceSell(InputData.timeStart:InputData.timeStart+4*InputData.timeHorizon-1);
%       InputData.Ppv(1:24)= PV_24h(InputData.timeStart:InputData.timeStart+4*InputData.timeHorizon-1); 
      
%       InputData.Pload=Pload_24h(counter15min:counter15min+23);
      InputData.Ppv(1:24)=PV_24h(counter15min:counter15min+23);
      InputData.PriceBuy=PriceBuy(counter15min:counter15min+23);
      InputData.PriceSell=PriceSell(counter15min:counter15min+23);
%       InputData.Ppv(1:24)= PV_24h(counter15min:counter15min+23); 
      PpvNext24points=PV_24h(counter15min:counter15min+23);
      Ppv_predictedNext15min=InputData.Ppv(1);
%         Ppv_predictedNext15min %to be deleted
        % ReferencesReal(1,1)*1000;
        InputData.Ppv(1)=(InputData.Ppv(1)+mean(Preal1(counter3min-2:counter3min)))/2; %(InputData.Ppv(1)+mean(Preal1(counter3min-2:counter3min)))/2
        Ppv_adjustedAvgPrevMeasNext15min=InputData.Ppv(1);
        
%         Ppv_adjustedAvgPrevMeasNext15min %to be deleted

        Ppv_predictedNext30min=InputData.Ppv(2);
%         Ppv_predictedNext30min %to be deleted
        InputData.Ppv(2)=0.5*(InputData.Ppv(2)+InputData.Ppv(1))/2+0.3*InputData.Ppv(2)+0.2*InputData.Ppv(3);
        Ppv_adjustedAvgPrevMeasNext30min=InputData.Ppv(2);
%         Ppv_adjustedAvgPrevMeasNext30min %to be deleted

        %update InputData.Pload for the next EMS call
        InputData.Pload(1:24)= Pload_24h(counter15min:counter15min+23);  
        PloadNext24points=Pload_24h(counter15min:counter15min+23);
        Pload_predictedNext15min=InputData.Pload(1);
%         Pload_predictedNext15min %to be deleted

        % ReferencesReal(1,1)*1000;
        InputData.Pload(1)=(InputData.Pload(1)+abs(mean(Preal2(counter3min-2:counter3min))))/2;%=(InputData.Pload(1)+mean(Preal2(counter3min-2:counter3min)))/2;
        Pload_adjustedAvgPrevMeasNext15min=InputData.Pload(1);
%         Pload_adjustedAvgPrevMeasNext15min %to be deleted

        Pload_predictedNext30min=InputData.Pload(2);
%         Pload_predictedNext30min  %to be deleted
        InputData.Pload(2)=0.5*(InputData.Pload(2)+InputData.Pload(1))/2+0.3*InputData.Pload(2)+0.2*InputData.Pload(3); 
        Pload_adjustedAvgPrevMeasNext30min=InputData.Pload(2);
        Pload_adjustedAvgPrevMeasNext30min % to be deleted
      
                          
% % %       %update InputData.Pload for the next EMS call
% % %       InputData.Pload(1:24)= MG2_Pload_summer_24h(InputData.timeStart:InputData.timeStart+4*InputData.timeHorizon-1);  
% % %       InputData.Pload(1)=(InputData.Pload(1)+mean(Preal2(counter3min-2:counter3min)))/2;
% % %       InputData.Pload(2)=0.5*(InputData.Pload(2)+InputData.Pload(1))/2+0.3*InputData.Pload(2)+0.2*InputData.Pload(3);  
      
      %update InputData for the prices in the next call
      %(counter15min:counter15min+23)shall be for ex. if counter15min=2 => 2:25; counter15min=3 =>3:26; 
      
      %TO BE DELETED
      fprintf('counter\n')
      counter15min
%       fprintf('check if OK:  InputData.timeStart:InputData.timeStart+4*InputData.timeHorizon-1 aka counter15min=2 => 2:25 \n')
%       InputData.timeStart:InputData.timeStart+4*InputData.timeHorizon-1
      %END %TO BE DELETED
%             
%       InputData.PriceBuy=PriceBuy(InputData.timeStart*4+1:4*(InputData.timeStart+InputData.timeHorizon));
%       InputData.PriceSell=PriceSell(InputData.timeStart*4+1:4*(InputData.timeStart+InputData.timeHorizon));  
      
              %IC: I think here we shall call again the EMS with the new input
        %values, calculated above
        InputData.SoC
        [EMS_Output]=MILP_microgrid_optimizationIC(InputData);
        fprintf('EMS_Output shall be a 24x4 matrix:\n')
        EMS_Output
        
        %***************
        % I think they are wrong if References is a matrix where on each
        % column there are 4 values. 
        References(1,counter15min)=PV_real_24h(counter15min)/1000;
        References(2,counter15min)=-Pload_real_24h(counter15min)/1000;
        References(3,counter15min)=EMS_Output(1,3); %Expecting to sell
        References(4,counter15min)=EMS_Output(1,5);%Pgrid shall go as ref here

        % %         we use this one if we switch the References matrix to a Lx4
        %         References(counter15min,1)=PV_real_24h(counter15min)/1000;
        %         References(counter15min,2)=-Pload_real_24h(counter15min)/1000;
        %         References(counter15min,3)=EMS_Output(1,3);
        %         References(counter15min,4)=EMS_Output(1,4);
        
        RTtimeStamp=RTtimeStamp+60*5; %Real-time simulated, updated everytime we change power references:5min
        
        WriteVariables(maPort,testBench,References(:,counter15min)'.*PSF); %send the references to the inverters/converters
        References(:,counter15min)
        fprintf('counter15min/4:\n')
        counter15min/4
        lastTime15Min = posixtime(datetime('now'));
     end    
    %Condition for escaping while loop
    if counter15min >= L;
        break;
    end
    
end
maPort.Dispose();
clear platformHandler;
%% Post-processing
t=linspace(0,L/4,Nread);
figure()
plot(t,Preal1./PSF(1),'c')
hold on
plot(t,Preal2./PSF(2),'r')
plot(t,Preal3./PSF(3),'b')
plot(t,Preal4./PSF(4),'k')
plot(t,PbatMeasured,'g')
title('Battery Regulation')
legend('PV','Load','Neig','Grid','BT')


