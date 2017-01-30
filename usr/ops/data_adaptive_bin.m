function [ status, message ] = data_adaptive_bin( obj, selected_data )
% data_adaptive_bin bin currently selected data in provided dimensions
%   The process is irreversible, therefore new data holder will be created.
%   Data which does not fit into whole bins at the end will be discarded
%   Default mode is sum. nan* mode should be used if data contain nan

%% function complete

% assume worst
status=false;
try
    data_idx=1;% initialise counter
    askforparam=true;% always ask for the first one
    while data_idx<=numel(selected_data)
        % get the current data index
        current_data=selected_data(data_idx);
        % check for data operator
        if strmatch(obj.data(current_data).datainfo.operator,'data_adaptive_bin','exact')
            % existing data
            newdata=false;
        else
            % new data will need to be created
            newdata=true;
        end
        if askforparam % ask if it is the first one
            % check for bin dimension
            if isfield(obj.data(current_data).datainfo,'binsize')
                % use current bin dimension
                binsize=obj.data(current_data).datainfo.binsize;
            else
                % bin dimension don't exist need to get set it to full size
                binsize=[];
            end
            % check for bin calculation mode
            if isfield(obj.data(current_data).datainfo,'operator_mode')
                opmode=obj.data(current_data).datainfo.operator_mode;% default bin mode
            else
                opmode='sum';% default bin mode
            end
            % check for bin calculation mode
            if isfield(obj.data(current_data).datainfo,'calculator_mode')
                calcmode=obj.data(current_data).datainfo.calculator_mode;% default bin mode
            else
                calcmode='reduce';% default bin mode
            end
            if isfield(obj.data(current_data).datainfo,'min_threshold')
                min_threshold=obj.data(current_data).datainfo.min_threshold;% default threshold
            else
                min_threshold=5;
            end
            if isfield(obj.data(current_data).datainfo,'t_tail')
                t_tail=obj.data(current_data).datainfo.t_tail;% default threshold
            else
                t_tail=10e-9;%ns
            end
            % check mode is correct
            switch opmode
                case {'mean','nanmean','sum','nansum','max','nanmax','min','nanmin','median','nanmedian'}
                    
                otherwise
                    opmode='sum';
            end
            % need user input/confirm bin size
            % get binning information
            prompt = {'This is based on the current data (mean/sum/max/min/median and nan mode)',...
                'min threshold',...
                't_tail',...
                'Calculation Mode (reduce/same)'};
            dlg_title = cat(2,'Data bin option for',obj.data(current_data).dataname);
            num_lines = 1;
            def = {opmode,num2str(min_threshold),num2str(t_tail),calcmode};
            set(0,'DefaultUicontrolBackgroundColor',[0.3,0.3,0.3]);
            set(0,'DefaultUicontrolForegroundColor','k');
            answer = inputdlg(prompt,dlg_title,num_lines,def);
            set(0,'DefaultUicontrolBackgroundColor','k');
            set(0,'DefaultUicontrolForegroundColor','w');
            if ~isempty(answer)
                % calculation mode
                opmode=answer{1};
                min_threshold=str2double(answer{2});
                t_tail=str2double(answer{3});
                calcmode=answer{4};
                switch opmode
                    case {'mean','nanmean','sum','nansum','max','nanmax','min','nanmin','median','nanmedian'}
                        
                    otherwise
                        message=sprintf('unknown binning mode entered\n Use sum or mean\n');
                        return;
                end
                switch calcmode
                    case {'reduce','same'}
                        
                    otherwise
                        message=sprintf('unknown calcmode mode entered\n Use reduce or same\n');
                        return;
                end
                % for multiple data ask for apply to all option
                if numel(selected_data)>1
                    % ask if want to apply to the rest of the data items
                    button = questdlg('Apply this setting to: ','Multiple Selection','Apply to Rest','Just this one','Apply to Rest') ;
                    switch button
                        case 'Apply to Rest'
                            askforparam=false;
                        case 'Just this one'
                            askforparam=true;
                        otherwise
                            % action cancellation
                            askforparam=false;
                    end
                end
                status=true;
            else
                % cancel clicked don't do anything to this data item
                
            end
        else
            % user decided to apply same settings to rest
            
        end
        % ---- Calculation Part ----
        if status
            status=false;
            % decided to process
            if newdata
                parent_data=current_data;
                % add new data
                obj.data_add(cat(2,'data_adaptive_bin|',obj.data(parent_data).dataname),[],[]);
                % get new data index
                current_data=obj.current_data;
                % set parent data index
                obj.data(current_data).datainfo.parent_data_idx=parent_data;
            else
                % get parent data index
                parent_data=obj.data(current_data).datainfo.parent_data_idx;
            end
            obj.data(current_data).datainfo.operator='data_adaptive_bin';
            obj.data(current_data).datainfo.binsize=binsize;
            obj.data(current_data).datainfo.operator_mode=opmode;
            obj.data(current_data).datainfo.calculator_mode=calcmode;
            obj.data(current_data).datainfo.min_threshold=min_threshold;
            obj.data(current_data).datainfo.t_tail=t_tail;
            dim_size=obj.data(parent_data).datainfo.data_dim;
            rawdata=obj.data(parent_data).dataval;
            % work out new data size
            T=obj.data(parent_data).datainfo.T;
            t_end=find(obj.data(parent_data).datainfo.t>t_tail,1,'first');
            T_idx=1;
            new_T_idx=1;
            while T_idx<dim_size(5)
                Tbin=0;
                tailval=0;
                while tailval<min_threshold
                    if Tbin>0
                        switch opmode
                            case {'sum','nansum','mean','nanmean','median','nanmedian'}
                                tempval=eval(cat(2,opmode,'(rawdata(:,:,:,:,T_idx:T_idx+Tbin),5);'));
                            case {'max','nanmax','min','nanmin'}
                                tempval=eval(cat(2,opmode,'(rawdata(:,:,:,:,T_idx:T_idx+Tbin),[],5);'));
                        end
                    else
                        tempval=rawdata(:,T_idx);
                    end
                    tailval=tempval(t_end);
                    Tbin=Tbin+1;
                    if T_idx+Tbin>dim_size(5)
                        T_idx=dim_size(5);
                        tailval=min_threshold+1;
                    end
                end
                tempdata(:,:,:,:,new_T_idx)=tempval(:);
                tempT(new_T_idx)=T(T_idx);
                binsize(new_T_idx)=Tbin;
                new_T_idx=new_T_idx+1;
                T_idx=T_idx+1;
            end
            obj.data(current_data).dataval=tempdata;
            obj.data(current_data).datainfo.T=tempT;
            obj.data(current_data).datainfo.t=obj.data(parent_data).datainfo.t;
            obj.data(current_data).datainfo.binsize=binsize(1:end);
            status=true;
            % recalculate dimension data
            message=sprintf('data binned\n');
            %redefine data type
            obj.data(current_data).datainfo.data_dim=size(tempdata);
            obj.data(current_data).datatype=obj.get_datatype(current_data);
        else
            message=sprintf('action cancelled\n');
        end
        % increment data index
        data_idx=data_idx+1;
    end
catch exception
    if exist('waitbar_handle','var')&&ishandle(waitbar_handle)
        delete(waitbar_handle);
    end
    message=exception.message;
end