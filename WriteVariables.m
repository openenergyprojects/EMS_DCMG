function WriteVariables(maPort,testBench,Value)
%IC: Value is the vector with the input refernece powers for the LabTest
%Value(1) is Ppv always >0
%Value(2) is Pload always <0
% Value(3) is Pneigh_sell always <0
% Value(4) is Pbat could be >0  when discharging and <0 when charging

% PathPphev = 'Model Root/TEST/SOC estimation/Constant/Value';
PathToWrite = 'Model Root/TEST/PowerControl1/Pdc_ref1/Value'; %Path of the block in the sdf file where value.Ppv will go
%Variables values
maPort.Write(PathToWrite, testBench.ValueFactory.CreateFloatValue(Value(1))); %Write Initial variables into dSPACE, you need the path and the value

PathToWrite = 'Model Root/TEST/PowerControl2/Pdc_ref2/Value'; %Path of the block in the sdf file where value.Pload will go
%Variables values
maPort.Write(PathToWrite, testBench.ValueFactory.CreateFloatValue(Value(2))); %Write Initial variables into dSPACE, you need the path and the value

PathToWrite = 'Model Root/TEST/PowerControl3/Pdc_ref3/Value'; %Path of the block in the sdf file where value.Pneigh_sell will go
%Variables values
maPort.Write(PathToWrite, testBench.ValueFactory.CreateFloatValue(Value(3))); %Write Initial variables into dSPACE, you need the path and the value

PathToWrite = 'Model Root/TEST/PowerControl4/Pdc_ref4/Value'; %Path of the block in the sdf file where value.Pbat will go
%Variables values
maPort.Write(PathToWrite, testBench.ValueFactory.CreateFloatValue(Value(4))); %Write Initial variables into dSPACE, you need the path and the value

%IC comment: Value shall be a matrix with 4 rows and 4*#Hours+1 columns(rows are:Pbat,Pneigh_sell, Ppv, Pload):
                               % 2 rows for reference points form the EMS (Pbat, Pneigh_sell); 
                               %and 2 entries/rows from the random generator of PV and load profiles
                               %matching the cluster to emulate possible differneces between the actual and the forecasted data
                              
end