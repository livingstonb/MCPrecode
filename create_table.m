function T = create_table(params,direct_results,norisk_results,sim_results,decomps,checks,exceptions)
    Nrows = 46;

    % Rownames
    rows = {'Beta (Annualized)'
            'Mean gross annual income'
            'Stdev log annual gross income'
            'Stdev log annual net income'
            'Mean assets'
            'Fraction with a == 0'
            'Fraction with a <= 0.5% mean ann gross lab inc'
            'Fraction with a <= 1% mean ann gross lab inc'
            'Fraction with a <= 2% mean ann gross lab inc'
            'Fraction with a <= 5% mean ann gross lab inc'
            'Fraction with a <= 10% mean ann gross lab inc'
            'Wealth, 10th percentile'
            'Wealth, 25th percentile'
            'Wealth, 50th percentile'
            'Wealth, 75th percentile'
            'Wealth, 90th percentile'
            'Wealth, 95th percentile'
            'Wealth, 99th percentile'
            'Wealth, top 10% share'
            'Wealth, top 1% share'
            'Gini coefficient'
            'Mean annual MPC (size = -1e-5)'
            'Mean annual MPC (size = -0.01)'
            'Mean annual MPC (size = -0.1)'
            'Mean annual MPC (size = 1e-5)'
            'Mean annual MPC (size = 0.01)'
            'Mean annual MPC (size = 0.1)'
            'Mean quarterly MPC (size = -1e-5)'
            'Mean quarterly MPC (size = -0.01)'
            'Mean quarterly MPC (size = -0.1)'
            'Mean quarterly MPC (size = 1e-5)'
            'Mean quarterly MPC (size = 0.01)'
            'Mean quarterly MPC (size = 0.1)'
            'Decomp around 0 (size 0.01), RA MPC'
            'Decomp around 0 (size 0.01), HtM Effect'
            'Decomp around 0 (size 0.01), Non-HtM, constraint'
            'Decomp around 0 (size 0.01), Non-HtM, inc risk'
            'Decomp around 0.01 (size 0.01), RA MPC'
            'Decomp around 0.01 (size 0.01), HtM Effect'
            'Decomp around 0.01 (size 0.01), Non-HtM, constraint'
            'Decomp around 0.01 (size 0.01), Non-HtM, inc risk'
            'Decomp around 0.05 (size 0.01), RA MPC'
            'Decomp around 0.05 (size 0.01), HtM Effect'
            'Decomp around 0.05 (size 0.01), Non-HtM, constraint'
            'Decomp around 0.05 (size 0.01), Non-HtM, inc risk'
            'Failed one or more checks'
            };

    % Iterate over parameterizations
    names = {};
    tablearray = zeros(Nrows,numel(params));
    for ip = 1:numel(params)
        p = params(ip);

        if numel(fieldnames(exceptions{ip})) == 1
            % Exception was thrown for this parameterization
            column = NaN(Nrows,1);
        elseif sum(ismember({'NoEGPConv','NoBetaConv'},checks{ip})) > 0
            % Some sort of code failure
            column = NaN(Nrows,1);
        else
            % Annual and quarterly MPCs
            if p.freq == 1
                mpcs_A = direct_results{ip}.avg_mpc1(:);
                mpcs_Q = NaN(6,1);
            else
                mpcs_A = direct_results{ip}.avg_mpc4(:);
                mpcs_Q = direct_results{ip}.avg_mpc1(:);
            end

            column = [
                direct_results{ip}.beta_annualized      % Annualized beta
                direct_results{ip}.mean_grossy_A        % Mean annual gross labor income
                direct_results{ip}.stdev_loggrossy_A    % Stdev log annual gross income
                direct_results{ip}.stdev_lognety_A      % Stdev log annual net income
                direct_results{ip}.mean_a               % Mean assets
                direct_results{ip}.constrained(1)       % Fraction with a < eps * mean ann gross inc
                direct_results{ip}.constrained(2)
                direct_results{ip}.constrained(3)
                direct_results{ip}.constrained(4)
                direct_results{ip}.constrained(5)
                direct_results{ip}.constrained(6)
                direct_results{ip}.wpercentiles(1)      % Wealth percentiles
                direct_results{ip}.wpercentiles(2)
                direct_results{ip}.wpercentiles(3)
                direct_results{ip}.wpercentiles(4)
                direct_results{ip}.wpercentiles(5)
                direct_results{ip}.wpercentiles(6)
                direct_results{ip}.wpercentiles(7)
                direct_results{ip}.top10share           % Top 10% wealth share
                direct_results{ip}.top1share            % Top 1% wealth share
                direct_results{ip}.wealthgini           % Gini coefficient
                mpcs_A(1)                               % Annual MPCs
                mpcs_A(2)
                mpcs_A(3)
                mpcs_A(4)
                mpcs_A(5)
                mpcs_A(6)
                mpcs_Q(1)                               % Quarterly MPCs (if freq = 4)
                mpcs_Q(2)
                mpcs_Q(3)
                mpcs_Q(4)
                mpcs_Q(5)
                mpcs_Q(6)
                decomps{ip}(1).term1                    % Decomposition around a=0
                decomps{ip}(1).term2  
                decomps{ip}(1).term3               
                decomps{ip}(1).term4
                decomps{ip}(2).term1                    
                decomps{ip}(2).term2
                decomps{ip}(2).term3
                decomps{ip}(2).term4
                decomps{ip}(3).term1                    
                decomps{ip}(3).term2
                decomps{ip}(3).term3
                decomps{ip}(3).term4
                numel(checks{ip})>0];                
        end
        
        % Add column name
        names{end+1} = p.name;

        % Add this column to table
        tablearray(:,ip) = column;    
    end
    
    T = array2table(tablearray,'VariableNames',names);
    T.Properties.RowNames = rows;
    writetable(T,'/Users/brianlivingston/Documents/table.xls');

end