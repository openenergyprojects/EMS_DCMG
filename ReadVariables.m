function [ValueOut]=ReadVariables(maPort)
%ValueOut is a vector of 5 measurements taken from the LabTestExperiment,
%aka: Ppv, Pload, Pneigh_sell, Pbat, and Pgrid
%we need to set up a path for each variable that we import/read from the measurements taken from the LabTestExperiment 

%variable paths
PathToRead = 'Model Root/TEST/PowerControl1/5Hz Filter/Out1'; %Ppv

ValueOut.Pdc1 = maPort.Read(PathToRead);

%variable paths
PathToRead = 'Model Root/TEST/PowerControl2/5Hz Filter/Out1'; %Pload

ValueOut.Pdc2 = maPort.Read(PathToRead);

%variable paths
PathToRead = 'Model Root/TEST/PowerControl3/5Hz Filter/Out1'; %Pneig_sell

ValueOut.Pdc3= maPort.Read(PathToRead);

%variable paths
PathToRead = 'Model Root/TEST/PowerControl4/5Hz Filter/Out1'; %Pbat

ValueOut.Pdc4 = maPort.Read(PathToRead);

%variable paths
PathToRead = 'Model Root/TEST/Data acquisition/5Hz Filter/Out1'; %Pgrid - the sluck inverter

ValueOut.Pdc5 = maPort.Read(PathToRead);
end