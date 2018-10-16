function decomp2 = decomposition2(params,direct_results)
    % Based on direct_results, this function decomposes the difference in
    % expected MPC from the baseline, Em1 - Em0
    
    % All parameterizations with nb == 1 share nxlong
    % Recreate common agrid
    agrid = linspace(0,1,params(1).nxlong)';
    agrid = agrid.^(1/p.xgrid_par);
    agrid = p.borrow_lim + (p.xmax - p.borrow_lim) * agrid;
    
    Nparams = numel(params);
    decomp2 = cell(1,Nparams);
    
    for ip = 1:Nparams
        decomp2{ip} = struct([]);
        
        if params(ip).nb==1 && Nparams > 1
            if params(ip).freq == 1
                baseind = 1;
            elseif params(ip).freq == 4
                baseind = 2;
            end
        
            m1 = direct_results{ip}.mpcs1_a_direct{5};
            m0 = direct_results{baseind}.mpcs1_a_direct{5};
            g1 = direct_results{ip}.agrid_dist;
            g0 = direct_results{baseind}.agrid_dist;

            decomp2{ip}.Em1_less_Em0 = direct_results{ip}.avg_mpc1_agrid(5) ...
                            - direct_results{baseind}.avg_mpc1_agrid(5);
            decomp2{ip}.Em1_less_Em0_check = g1'*m1 - g0'*m0;
            decomp2{ip}.term1 = g0' * (m1 - m0);
            decomp2{ip}.term2 = m0' * (g1 - g0);
            decomp2{ip}.term3 = (m1 - m0)' * (g1 - g0);
            ME = struct();
            
            for ia = 1:numel(params(ip).abars)
                abar = params(ip).abars(ia);
                idx = agrid <= abar;
                decomp2{ip}.term3a(ia) = m0(idx)' * (g1(idx) - g0(idx));
                decomp2{ip}.term3b(ia) = m0(~idx)' * (g1(~idx) - g0(~idx));
            end
        else
            % Either not running more than one param, or can't decompose
            % for nb > 1
            decomp2{ip}.Em1_less_Em0 = NaN;
            decomp2{ip}.Em1_less_Em0_check = NaN;
            decomp2{ip}.term1 = NaN;
            decomp2{ip}.term2 = NaN;
            decomp2{ip}.term3 = NaN;
            decomp2{ip}.term3a = NaN(numel(params(ip).abars),1);
            decomp2{ip}.term3b = NaN(numel(params(ip).abars),1);
        end
        
    end
end