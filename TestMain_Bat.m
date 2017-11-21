%Test Main with the lab updates as InputDate
close all
clear all
clc
% load InputData.mat
load MG2_PV_forecast_summer;
load MG2_Load24h_15min;
load MG2_PV_real_summer;
load MG2_Load_real;

PV_24h=MG2_PV_forecast_summer';
PV_real_24h=MG2_PV_real_summer';
Pload_24h=MG2_Load24h_15min; %in W
Pload_real_24h=MG2_Load_real;

InputData.timeStart=0;
InputData.timeHorizon=6;
InputData.maximum_capacity_battery=7500; %Wh
InputData.max_batt_discharge=5000; %W
InputData.max_batt_charge=3000; %W
InputData.SoC=0.5*InputData.maximum_capacity_battery; %Wh
PriceBuy=[repmat(9.33,1,28) repmat(16.05,1,44) repmat(12.07,1,16) repmat(9.33,1,8)];
PriceSell=repmat(0.3,1,96);

% InputDataReal=InputData;
% InputDataReal.Pload=Pload_real_24h(InputData.timeStart*4+1:4*(InputData.timeStart+InputData.timeHorizon));
% InputDataReal.Ppv=PV_real_24h(InputData.timeStart*4+1:4*(InputData.timeStart+InputData.timeHorizon));
% read_time2=toc; %send to display the time it took to read the data

%AICI
for i=1:(24-6)*4
% InputData.timeStart=i/4;  
 InputData.timeStart=i;
% i=1;
%     t=InputData.timeStart+i*InputData.timeHorizon;
% % % % % InputData.Pload=Pload_24h(InputData.timeStart*4+1:4*(InputData.timeStart+InputData.timeHorizon));
% % % % % InputData.Ppv=PV_24h(InputData.timeStart*4+1:4*(InputData.timeStart+InputData.timeHorizon));
% % % % % InputData.PriceBuy=PriceBuy(InputData.timeStart*4+1:4*(InputData.timeStart+InputData.timeHorizon));
% % % % % InputData.PriceSell=PriceSell(InputData.timeStart*4+1:4*(InputData.timeStart+InputData.timeHorizon));
% % % % % [References]=MILP_microgrid_optimizationIC_Bat(InputData);
InputData.Pload=Pload_24h(i:i+23);
InputData.Ppv=PV_24h(i:i+23);
InputData.PriceBuy=PriceBuy(i:i+23);
InputData.PriceSell=PriceSell(i:i+23);
[References]=MILP_microgrid_optimizationIC_Bat(InputData);
% fprintf('sum References each row shall be equal to Pgrid:\n')
% sum(References,2)
% References
i
ReferencesOUT_EMS=References(1,:)
OUT_EMS(i,:)=ReferencesOUT_EMS;
% ReferencesOUT_EMS(i,:)=References(1,:);
% ReferencesOUT_EMS(i,:)
% ReferencesReal(i,:)=[InputDataReal.Ppv(i)/1000 -InputDataReal.Pload(i)/1000 References(1,3) References(1,4)];
ReferencesReal=[PV_real_24h(i)/1000 -Pload_real_24h(i)/1000 References(1,3) References(1,5)]
REAL(i,:)=ReferencesReal;


% ReferencesReal(i,:)
% PgridSetUp(i)=-sum(ReferencesReal(i,:),2);
Pbat_measured=-sum(ReferencesReal,2);
PbatMeasured(i)=-sum(ReferencesReal,2);
%update InputData.Ppv for the next EMS call
InputData.SoC=InputData.SoC+Pbat_measured*0.25;

InputData.Ppv(1:24)= PV_24h(i+1:i+24); 
PpvNext24points=PV_24h(i+1:i+24);
Ppv_predictedNext15min=InputData.Ppv(1);
% ReferencesReal(1,1)*1000;
InputData.Ppv(1)=(InputData.Ppv(1)+ReferencesReal(1,1)*1000)/2; %(InputData.Ppv(1)+mean(Preal1(counter3min-2:counter3min)))/2
Ppv_adjustedAvgPrevMeasNext15min=InputData.Ppv(1);

Ppv_predictedNext30min=InputData.Ppv(2);
InputData.Ppv(2)=0.5*(InputData.Ppv(2)+InputData.Ppv(1))/2+0.3*InputData.Ppv(2)+0.2*InputData.Ppv(3);
Ppv_adjustedAvgPrevMeasNext30min=InputData.Ppv(2);

%update InputData.Pload for the next EMS call
InputData.Pload(1:24)= Pload_24h(i+1:i+24);  
PloadNext24points=Pload_24h(i+1:i+24);
Pload_predictedNext15min=InputData.Pload(1);

% ReferencesReal(1,1)*1000;
InputData.Pload(1)=(InputData.Pload(1)+abs(ReferencesReal(1,2)*1000))/2;%=(InputData.Pload(1)+mean(Preal2(counter3min-2:counter3min)))/2;
Pload_adjustedAvgPrevMeasNext15min=InputData.Pload(1);

Pload_predictedNext30min=InputData.Pload(2);
InputData.Pload(2)=0.5*(InputData.Pload(2)+InputData.Pload(1))/2+0.3*InputData.Pload(2)+0.2*InputData.Pload(3); 
Pload_adjustedAvgPrevMeasNext30min=InputData.Pload(2);
%  %TO BE DELETED
%  fprintf('counter\n')
%       i
%  fprintf('check if OK: counter15min:counter15min+23 aka counter15min=2 => 2:25 \n')
%  i+1:i+1+4*InputData.timeHorizon-1
%  %END %TO BE DELETED
 
%update InputData for prices in the next call
InputData.PriceBuy=PriceBuy(i+1:i+24);
InputData.PriceSell=PriceSell(i+1:i+24);
end
% [ReferencesReal]=MILP_microgrid_optimizationIC(InputDataReal);
% fprintf('sum  ReferencesReal each row shall be equal to Pgrid:\n')
% sum(ReferencesReal,2)
% ReferencesReal
OUT_EMS
REAL
% x_time=[InputData.timeStart:1/4:InputData.timeStart+InputData.timeHorizon];
x_time=0:1/4:i/4-0.25;
 figure()
plot(x_time(1:end),OUT_EMS(:,1), '.-y',...
     x_time(1:end),OUT_EMS(:,2), '.-r',...
     x_time(1:end),OUT_EMS(:,3), '.-b',...
     x_time(1:end),OUT_EMS(:,4), '.-g',...
     x_time(1:end),OUT_EMS(:,5), '.-k');
title('EMS references')
xlabel('Time (h)')
ylabel ('Power (kW)')
legend('Ppv', 'Pload', 'Psell_neigh', 'Pbat', 'Pgrid');
figure()
plot(x_time(1:end),REAL(:,1), '.-y',...
    x_time(1:end),REAL(:,2), '.-r',...
    x_time(1:end),REAL(:,3), '.-b',...
    x_time(1:end),REAL(:,4), '.-k',...
    x_time(1:end),PbatMeasured, '.-g');
title('REAL references')
xlabel('Time (h)')
ylabel ('Power (kW)')
legend('PpvReal','PloadReal', 'PsellNeighEMS', 'PgridEMS', 'PbatCalc');

PbatMeasured


