function [maPort,testBench]=OpenPortAPI(ConfgFile)
%IC: do not tuch this
demoApplName = 'four_invertersparallel.ppc';
platformIdentifier = 'ds1006';
taskName = 'HostService';
% set the testbench product name
productName = 'XIL API';
% set the testbench product version
productVersion = '2015-A';
% -------------------------------------------------------------------------------------
maPortConfigFile = [pwd, ConfgFile];
LF = char(10);
% import dSPACE XIL API .NET assemblies
NET.addAssembly('ASAM.XIL.Interfaces');
NET.addAssembly('ASAM.XIL.Implementation.TestbenchFactory');
platformHandler = DSPlatformManagementAPI();

tbFactory = ASAM.XIL.Implementation.TestbenchFactory.Testbench.TestbenchFactory();

% Create a dSPACE Testbench object; the Testbench object is the central object to access
% factory objects for the creation of all kinds of Testbench-specific objects
testBench = tbFactory.CreateVendorSpecificTestbench('dSPACE GmbH', productName, productVersion);

% Create MAPort
maPort = testBench.MAPortFactory.CreateMAPort('DemoMAPort');
maPortConfig = maPort.LoadConfiguration(maPortConfigFile);
maPort.Configure(maPortConfig, false);
maPort.StartSimulation();


end