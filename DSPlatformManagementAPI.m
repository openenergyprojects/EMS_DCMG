% DSPlatformManagementAPI.m
% This class is an example how to use the dSPACE Platform Management API,
% provided by the dSPACE Python Extensions 1.8.
%
% Copyright 2015 by dSPACE GmbH

classdef DSPlatformManagementAPI < handle
    properties
        platformManagement;
    end

    methods
        % Constructs a DSPlatformManagementAPI object.
        % Creates an active-x COM server for using the DSPlatformManagement API.
        function obj = DSPlatformManagementAPI(varargin)
            obj.platformManagement = actxserver('DSPlatformManagementAPI2');
            obj.RefreshPlatformConnections();
        end

        % Refreshes the platform connections of the platform management.
        % This is necessary for every platform access to get the current platform configuration.
        function RefreshPlatformConnections(obj)
            obj.platformManagement.RefreshPlatformConfiguration();
        end

        % Creating platform connection to a single processor board
        %
        % boardname is the platform identifier (e. g. 'SCALEXIO', 'ds1007', ...)
        % boardtype is the platform type (see 'dSPACE_PlatformManagement_Automation_PlatformType.m')
        % connectionType is the platform connection type (see 'dSPACE_PlatformManagement_Automation_InterfaceConnectionType.m')
        % portAddress is the port address of the board (e. g. 0 for SCALEXIO, 0x300 for ds1005, ...)
        % ipAddresses are the ip addresses of the board (e. g. {'10.0.0.1'}, ...)
        function CreatePlatformConnection(obj, boardName, boardType, connectionType, portAddress, ipAddresses)
            if (~isempty(strfind(lower(boardName), 'multiprocessor')))
                throw(MException('DSPlatformManagementAPI:CreatePlatformConnection', 'Use "CreateMultiprocessorConnection" for a Multiprocessor platform'));
            end

            try
                % check whether the platform is already registered
                usedPlatform = GetUsedPlatform(obj, boardName);

                if (isempty(usedPlatform))
                    % platform not found - register it

                    % create an registration information for the given board type
                    switch (boardType)
                        case {dSPACE_PlatformManagement_Automation_PlatformType.SCALEXIO}
                            registrationInfo = obj.platformManagement.CreatePlatformRegistrationInfo(uint32(dSPACE_PlatformManagement_Automation_PlatformType.SCALEXIO));

                        case {dSPACE_PlatformManagement_Automation_PlatformType.DS1005}
                            registrationInfo = obj.platformManagement.CreatePlatformRegistrationInfo(uint32(dSPACE_PlatformManagement_Automation_PlatformType.DS1005));

                        case {dSPACE_PlatformManagement_Automation_PlatformType.DS1006}
                            registrationInfo = obj.platformManagement.CreatePlatformRegistrationInfo(uint32(dSPACE_PlatformManagement_Automation_PlatformType.DS1006));

                        case {dSPACE_PlatformManagement_Automation_PlatformType.DS1007}
                            registrationInfo = obj.platformManagement.CreatePlatformRegistrationInfo(uint32(dSPACE_PlatformManagement_Automation_PlatformType.DS1007));

                        case {dSPACE_PlatformManagement_Automation_PlatformType.DS1103}
                            registrationInfo = obj.platformManagement.CreatePlatformRegistrationInfo(uint32(dSPACE_PlatformManagement_Automation_PlatformType.DS1103));

                        case {dSPACE_PlatformManagement_Automation_PlatformType.DS1104}
                            registrationInfo = obj.platformManagement.CreatePlatformRegistrationInfo(uint32(dSPACE_PlatformManagement_Automation_PlatformType.DS1104));

                        case {dSPACE_PlatformManagement_Automation_PlatformType.MABX}
                            registrationInfo = obj.platformManagement.CreatePlatformRegistrationInfo(uint32(dSPACE_PlatformManagement_Automation_PlatformType.MABX));

                        case {dSPACE_PlatformManagement_Automation_PlatformType.DS1202}
                            registrationInfo = obj.platformManagement.CreatePlatformRegistrationInfo(uint32(dSPACE_PlatformManagement_Automation_PlatformType.DS1202));

                        case {dSPACE_PlatformManagement_Automation_PlatformType.VEOS}
                            registrationInfo = obj.platformManagement.CreatePlatformRegistrationInfo(uint32(dSPACE_PlatformManagement_Automation_PlatformType.VEOS));

                        otherwise
                            throw(MException('DSPlatformManagementAPI:CreatePlatformConnection', ['Unsupported board type: ', boardType]));
                    end

                    if (   (boardType ~= dSPACE_PlatformManagement_Automation_PlatformType.DS1007) ...
                        && (boardType ~= dSPACE_PlatformManagement_Automation_PlatformType.DS1202) ...
                        && (boardType ~= dSPACE_PlatformManagement_Automation_PlatformType.SCALEXIO) ...
                        && (boardType ~= dSPACE_PlatformManagement_Automation_PlatformType.VEOS))
                        if (boardType ~= dSPACE_PlatformManagement_Automation_PlatformType.MABX)
                            registrationInfo.ConnectionType = connectionType;
                        end

                        registrationInfo.PortAddress = portAddress;
                        registrationInfo.NetClient = char(ipAddresses(1));
                    else
                        for ipAddress = ipAddresses
                            childInfo = registrationInfo.RegistrationInfos.Add();
                            childInfo.IPAddress = char(ipAddress);
                        end
                    end

                    obj.platformManagement.RegisterPlatform(registrationInfo);
                end
            catch e
                rethrow(e);
            end
        end

        % Creating platform connection to a multiprocessor board
        %
        % boardname is the platform identifier (e. g. 'Multiprocessor', ...)
        % boardtype is the subplatform type (see 'dSPACE_PlatformManagement_Automation_PlatformType.m')
        % connectionType is the platform connection type (see 'dSPACE_PlatformManagement_Automation_InterfaceConnectionType.m')
        % portAddress is the port address of the board (e. g. 0x300 for ds1005, ...)
        % ipAddress is the ip address of the board (e. g. '10.0.0.1', ...)
        % numMemberApplications is the number of member applications of the multiprocessor system
        function CreateMultiprocessorConnection(obj, boardName, boardType, connectionType, portAddress, ipAddress, numMemberApplications)
            if (isempty(strfind(lower(boardName), 'multiprocessor')))
                throw(MException('DSPlatformManagementAPI:CreatePlatformConnection', 'Use "CreatePlatformConnection" for everything else except Multiprocessor'));
            end

            try
                % check whether the platform is already registered
                usedPlatform = GetUsedPlatform(obj, boardName);

                if (isempty(usedPlatform))
                    % platform not found - register it
                    registrationInfo = obj.platformManagement.CreatePlatformRegistrationInfo(uint32(dSPACE_PlatformManagement_Automation_PlatformType.MultiProcessor));
                    registrationInfo.ConnectionType = connectionType;
                    registrationInfo.NetClient      = ipAddress;

                    % register each member
                    for appIndex = (0:numMemberApplications - 1)
                        platformInfo = [];

                        switch (boardType)
                            case {dSPACE_PlatformManagement_Automation_PlatformType.DS1005}
                                platformInfo = registrationInfo.Add(uint32(dSPACE_PlatformManagement_Automation_PlatformType.DS1005));

                            case {dSPACE_PlatformManagement_Automation_PlatformType.DS1006}
                                platformInfo = registrationInfo.Add(uint32(dSPACE_PlatformManagement_Automation_PlatformType.DS1006));

                            otherwise
                                throw(MException('DSPlatformManagementAPI:CreateMultiprocessorConnection', ['Unsupported board type: ', boardType]));
                        end

                        % calculate port address with the given start address, e. g. starting at 0x300, next value is 0x310
                        platformInfo.PortAddress = portAddress + (appIndex * 16);
                        clear platformInfo;
                    end

                    if (registrationInfo.RegisterInfos.Count > 0)
                       obj.platformManagement.RegisterPlatform(registrationInfo);
                    end
                end
            catch e
                rethrow(e);
            end
        end

        % Loading an application to a specific platform
        %
        % sdfFilePath is the path to the application, which will be loaded (e. g. 'C:\test.sdf')
        % platformIdentifier is the name of the platform, where the application will be loaded
        function LoadApplicationSdfFile(obj, sdfFilePath, platformIdentifier)
            try
                % check whether the platform is registered
                usedPlatform = GetUsedPlatform(obj, platformIdentifier);

                if (isempty(usedPlatform))
                    throw(MException('DSPlatformManagementAPI:LoadApplicationSdfFile', ['Cannot find platform: ', platformIdentifier]));
                else
                    usedPlatform.LoadRealtimeApplication(sdfFilePath);
                end
            catch e
                rethrow(e);
            end
        end

        % Starts the application on the given platform
        %
        % platformIdenifier is the name of the platform (e. g. 'SCALEXIO', 'ds1005', ...)
        function StartApplication(obj, platformIdentifier)
            try
                % check whether the platform is registered
                usedPlatform = GetUsedPlatform(obj, platformIdentifier);

                if (isempty(usedPlatform))
                    throw(MException('DSPlatformManagementAPI:StartApplication', ['Cannot find platform: ', platformIdentifier]));
                else
                    % check whether the system is single- or multiprocessor
                    if (~isempty(usedPlatform.RealTimeApplication))
                        if (   obj.ComparePlatformType(usedPlatform.Type, dSPACE_PlatformManagement_Automation_PlatformType.DS1007) ...
                            && obj.ComparePlatformType(usedPlatform.Type, dSPACE_PlatformManagement_Automation_PlatformType.DS1202) ...
                            && obj.ComparePlatformType(usedPlatform.Type, dSPACE_PlatformManagement_Automation_PlatformType.SCALEXIO) ...
                            && obj.ComparePlatformType(usedPlatform.Type, dSPACE_PlatformManagement_Automation_PlatformType.VEOS))
                            % check if the application is already running
                            if (obj.CompareApplicationState(usedPlatform.RealTimeApplication.State, dSPACE_PlatformManagement_Automation_ApplicationState.Running))
                                usedPlatform.RealTimeApplication.Start();
                            end
                        else
                            usedPlatform.LoadRealtimeApplication(usedPlatform.RealTimeApplication.FullPath);
                        end
                    else
                        throw(MException('DSPlatformManagementAPI:StartApplication', ['Cannot find real time application on platform: ', platformIdentifier]));
                    end
                end
            catch e
                rethrow(e);
            end
        end

        % Stops the application on the given platform
        %
        % platformIdenifier is the name of the platform (e. g. 'SCALEXIO', 'ds1005', ...)
        function StopApplication(obj, platformIdentifier)
            try
                % check whether the platform is registered
                usedPlatform = GetUsedPlatform(obj, platformIdentifier);

                if (isempty(usedPlatform))
                    throw(MException('DSPlatformManagementAPI:StartApplication', ['Cannot find platform: ', platformIdentifier]));
                else
                    % check whether the system has a application to stop
                    % and check for multiprocessor
                    if (~isempty(usedPlatform.RealTimeApplication))
                        if (   obj.ComparePlatformType(usedPlatform.Type, dSPACE_PlatformManagement_Automation_PlatformType.DS1007) ...
                            && obj.ComparePlatformType(usedPlatform.Type, dSPACE_PlatformManagement_Automation_PlatformType.DS1202) ...
                            && obj.ComparePlatformType(usedPlatform.Type, dSPACE_PlatformManagement_Automation_PlatformType.SCALEXIO) ...
                            && obj.ComparePlatformType(usedPlatform.Type, dSPACE_PlatformManagement_Automation_PlatformType.VEOS))
                            if (obj.CompareApplicationState(usedPlatform.RealTimeApplication.State, dSPACE_PlatformManagement_Automation_ApplicationState.Stopped))
                                usedPlatform.RealTimeApplication.Stop();
                            end
                        else
                            usedPlatform.StopRTP();
                        end
                    else
                        throw(MException('DSPlatformManagementAPI:StartApplication', ['Cannot find real time application on platform: ', platformIdentifier]));
                    end
                end
            catch e
                rethrow(e);
            end
        end

        % Gets the application informations on the given platform
        %
        % platformIdenifier is the name of the platform (e. g. 'SCALEXIO', 'ds1005', ...)
        function applicationInfo = GetApplInfo(obj, platformIdentifier)
            applicationInfo = [];

            % check whether the platform is registered
            usedPlatform = GetUsedPlatform(obj, platformIdentifier);

            if (isempty(usedPlatform))
                throw(MException('DSPlatformManagementAPI:GetApplInfo', ['Cannot find platform: ', platformIdentifier]));
            else
                % check for application
                if (~isempty(usedPlatform.RealTimeApplication))
                    applicationInfo = struct('name', usedPlatform.RealTimeApplication.Name, ...
                                             'date', usedPlatform.RealTimeApplication.BuildDateTime, ...
                                             'board', usedPlatform.UniqueName, ...
                                             'type', usedPlatform.Type);
                end
            end
        end

        % Gets all platform informations which are currently registered
        function boardInfo = GetBoardInfo(obj)
            boardInfo = [];

            % refresh platform connections to get all current platforms
            obj.RefreshPlatformConnections();

            % get all registered platforms
            platforms = obj.platformManagement.Platforms;

            if (platforms.Count ~= 0)
                % iterate over platforms and get the board information
                for platformIndex = (0:platforms.Count - 1)
                    platform = platforms.Item(int32(platformIndex));

                    tempInfos{platformIndex + 1} = struct('name', platform.UniqueName, ...
                                                          'type', platform.Type);
                end

                boardInfo = cell2mat(tempInfos);
            end
        end

        % Checks whether the application is running on the given platform
        %
        % platformIdenifier is the name of the platform (e. g. 'SCALEXIO', 'ds1005', ...)
        function running = IsApplRunning(obj, platformIdentifier)
            running = false;

            % check whether the platform is registered
            usedPlatform = GetUsedPlatform(obj, platformIdentifier);

            if (isempty(usedPlatform))
                throw(MException('DSPlatformManagementAPI:GetApplInfo', ['Cannot find platform: ', platformIdentifier]));
            else
                % check for application
                if (~isempty(usedPlatform.RealTimeApplication))
                    running = true;

                    % check for SCALEXIO, only platform that supports a state to check
                    if (obj.ComparePlatformType(usedPlatform.Type, dSPACE_PlatformManagement_Automation_PlatformType.SCALEXIO))
                        if (obj.CompareApplicationState(usedPlatform.RealTimeApplication.State, dSPACE_PlatformManagement_Automation_ApplicationState.Running))
                            running = true;
                        else
                            running = false;
                        end
                    end
                end
            end
        end
    end

    methods (Access = private)
        function usedPlatform = GetUsedPlatform(obj, platformIdentifier)
            usedPlatform = [];

            % refresh interface connections
            obj.RefreshPlatformConnections();

            % get all registered platforms
            platforms = obj.platformManagement.Platforms;

            if (platforms.Count ~= 0)
                % iterate over platforms
                for platformIndex = (0:platforms.Count - 1)
                    platform = platforms.Item(int32(platformIndex));

                    % check platform name
                    if (strcmpi(platform.UniqueName, platformIdentifier))
                        usedPlatform = platform;
                        break;
                    end
                end
            end
        end

        function result = ComparePlatformType(obj, apiType, enumType)
            result = strcmpi(apiType, ['PlatformType_', char(enumType)]);
        end

        function result = CompareApplicationState(obj, apiState, enumState)
            result = strcmpi(apiState, ['ApplicationState_', char(enumState)]);
        end
    end
end