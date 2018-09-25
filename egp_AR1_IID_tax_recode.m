function results = egp_AR1_IID_tax_recode(p)
    % Endogenous Grid Points with AR1 + IID Income
    % Cash on Hand as State variable
    % Includes NIT and discount factor heterogeneity
    % Greg Kaplan 2017

    %% INCOME GRIDS

    %persistent income: rowenhurst
    if p.LoadIncomeProcess == 1
        logyPgrid = load('QuarterlyIncomeDynamics/TransitoryContinuous/logyPgrid.txt');
        yPdist = load('QuarterlyIncomeDynamics/TransitoryContinuous/yPdist.txt');
        yPtrans = load('QuarterlyIncomeDynamics/TransitoryContinuous/yPtrans.txt');
        p.nyP = length(logyPgrid);
        logyPgrid = logyPgrid';
    elseif p.nyP>1
        [logyPgrid, yPtrans, yPdist] = rouwenhorst(p.nyP, -0.5*p.sd_logyP^2, p.sd_logyP, p.rho_logyP);
    else
        logyPgrid = 0;
        yPdist = 1;
        yPtrans = 1;
    end  

    yPgrid = exp(logyPgrid);
    yPcumdist = cumsum(yPdist,1);
    yPcumtrans = cumsum(yPtrans,2);
    
    if size(yPgrid,2)>1
        error('yPgrid is a row vector, must be column vector')
    end
    if size(yPdist,2)>1
        error('yPdist is a row vector, must be column vector')
    end
    

    % transitory income: disretize normal distribution
    if p.LoadIncomeProcess == 1
        p.sig2T = load('QuarterlyIncomeDynamics/TransitoryContinuous/sig2T.txt');
        p.lambdaT = load('QuarterlyIncomeDynamics/TransitoryContinuous/lambdaT.txt');
    end

    if p.nyT>1

        %moments of mixture distribution
        lmu2 = p.lambdaT.*p.sd_logyT^2;
        lmu4 = 3.*p.lambdaT.*(p.sd_logyT^4);

        %fit thjose moments
        optionsNLLS = optimoptions(@lsqnonlin,'Display','Off');
        lpar = lsqnonlin(@(lp)discretize_normal_var_kurt(lp,p.nyT,lmu2,lmu4),[2 0.1],[],[],optionsNLLS);
        [lf,lx,lp] = discretize_normal_var_kurt(lpar,p.nyT,lmu2,lmu4);
        logyTgrid = lx;
        yTdist = lp;
        yTcumdist = cumsum(yTdist,1);

    elseif nyT==1
        logyTgrid = 0;
        yTdist = 1;
    end
    
    yTgrid = exp(logyTgrid);
    
    if size(yTgrid,2)>1
        error('yTgrid is a row vector, must be column vector')
    end
    if size(yTdist,2)>1
        error('yTdist is a row vector, must be column vector')
    end

    % fixed effect
    if p.nyF>1
        width = fzero(@(x)discrete_normal(p.nyF,-0.5*p.sd_logyF^2 ,p.sd_logyF ,x),2);
        [~,logyFgrid,yFdist] = discrete_normal(p.nyF,-0.5*p.sd_logyF^2 ,p.sd_logyF ,width);
    elseif p.nyF==1
        logyFgrid = 0;
        yFdist = 1;
    end
    yFgrid = exp(logyFgrid);
    yFcumdist = cumsum(yFdist,1);

    if size(yFgrid,2)>1
        error('yFgrid is a row vector, must be column vector')
    end
    if size(yFdist,2)>1
        error('yFdist is a row vector, must be column vector')
    end

    % transition probabilities for yP-yF combined grid
    ytrans = kron(eye(p.nyF),yPtrans);

    % length of full xgrid
    p.N = p.nx*p.nyF*p.nyP*p.nb;

    %% DISCOUNT FACTOR

    if p.IterateBeta == 0
        p.maxiterAY = 1;
        % final beta
        beta = p.beta0;
    end

    if p.IterateBeta == 1
        % initial condition for beta iteration
        p.beta0 = (p.betaH + p.betaL)/2;
    end

    %initial discount factor grid
    if  p.nb == 1
        betadist = 1;
        betatrans = 1;
    elseif p.nb ==2 
        betadist = [0.5;0.5];
        betatrans = [1-p.betaswitch p.betaswitch; p.betaswitch 1-p.betaswitch]; %transitions on average once every 40 years;
    else
        error('nb must be 1 or 2');
    end
    betacumdist = cumsum(betadist);
    betacumtrans = cumsum(betatrans,2);


    %% ASSET AND INCOME GRIDS

    sgrid.orig = linspace(0,1,p.nx)';
    sgrid.orig = sgrid.orig.^(1./p.xgrid_par);
    sgrid.orig = p.borrow_lim + (p.xmax-p.borrow_lim).*sgrid.orig;
    sgrid.short = sgrid.orig;

    sgrid.wide = repmat(sgrid.short,[1 p.nyP p.nyF p.nb]);
    p.ns = p.nx;

    % construct matrix of y combinationsx
    ymat = repmat(yPgrid,p.nyF,1) .* kron(yFgrid,ones(p.nyP,1)) * yTgrid';

    % distribution of ymat (values are repeated nb*nx times)
    ymatdist = repmat(yPdist,p.nyF,1) .* kron(yFdist,ones(p.nyP,1)) * yTdist';

    % find mean y
    % isolate unique (yT,yF,yP) combinations
    temp = sortrows([ymat(:) ymatdist(:)],1);
    ysort = temp(:,1);
    ysortdist = temp(:,2);
    ycumdist = cumsum(ysortdist);
    meany = ymat(:)'*ymatdist(:);
    original_meany = meany;
    
    % normalize gross income to have mean 1
    if p.NormalizeY == 1
        ymat = ymat/meany;
        ysort = ysort/meany;
        meany = 1;
    end
    totgrossy = meany;

    % find tax threshold on labor income
    if numel(ysort)>1
        labtaxthresh = lininterp1(ycumdist,ysort,p.labtaxthreshpc);
    else
        labtaxthresh = 0;
    end    

    % find net income
    totgrossyhigh = max(ymat(:)-labtaxthresh,0)'*ymatdist(:);
    lumptransfer = p.labtaxlow*totgrossy + p.labtaxhigh*totgrossyhigh;
    % netymat is N by nyT matrix
    netymat = lumptransfer + (1-p.labtaxlow)*ymat - p.labtaxhigh*max(ymat-labtaxthresh,0);
    meannety = netymat(:)'*ymatdist(:);

    % xgrid, indexed by beta,yF,yP,x (N by 1 matrix)
    % cash on hand grid: different min points for each value of (iyP,iyF)
    xgrid.orig = sgrid.wide(:) + min(kron(netymat,ones(p.nx,1)),[],2);
    
    % Store income variables in a structure
    newfields = {'ymat','netymat','meany','original_meany','yPgrid',...
        'yTgrid','yFgrid','yPdist','yTdist','yFdist','yPcumtrans',...
        'yPtrans','yPcumdist','yFcumdist','yTcumdist','ytrans'};
    for i = 1:numel(newfields)
        income.(newfields{i}) = eval(newfields{i});
    end

    %% UTILITY FUNCTION, BEQUEST FUNCTION

    if p.risk_aver==1
        u = @(c)log(c);
        beq = @(a) p.bequest_weight.* log(a+ p.bequest_luxury);
    else    
        u = @(c)(c.^(1-p.risk_aver)-1)./(1-p.risk_aver);
        beq = @(a) p.bequest_weight.*((a+p.bequest_luxury).^(1-p.risk_aver)-1)./(1-p.risk_aver);
    end    

    u1 = @(c) c.^(-p.risk_aver);
    u1inv = @(u) u.^(-1./p.risk_aver);

    beq1 = @(a) p.bequest_weight.*(a+p.bequest_luxury).^(-p.risk_aver);

    %% ORGANIZE VARIABLES
    % Reshape policy functions for use later
    xgrid.wide = reshape(xgrid.orig,[p.nx p.nyP p.nyF p.nb]);

    %% MODEL SOLUTION

    if p.IterateBeta == 1
        ergodic_tol = 1e-6;
        if p.ExpandGridBetaIter == 1
            ExpandGrid = 1;
        else
            ExpandGrid = 0;
        end
        iterate_EGP = @(x) solve_EGP(x,p,...
            xgrid,sgrid,betatrans,u1,beq1,u1inv,ergodic_tol,income,ExpandGrid);

        beta_lb = 1e-3;
        if p.nb == 1
            beta_ub = p.betaH - 1e-5;
        else
            beta_ub = p.betaH - 1e-5 - betawidth;
        end
        % Max fzero iterations set to p.max_evals
        check_evals = @(x,y,z) fzero_checkiter(x,y,z,p.max_evals);
        options = optimset('TolX',1e-6,'OutputFcn',check_evals);
        [beta,~,exitflag] = fzero(iterate_EGP,[beta_lb,beta_ub],options);
        
        if exitflag ~= 1
            results = struct();
            results.issues = {'NoBetaConv'};
            return
        end
        results.beta = beta;
    end

    ergodic_tol = 1e-7;
    if p.ExpandGridF == 1
        ExpandGrid = 1;
    else
        ExpandGrid = 0;
    end
    [~,con_opt,sav_opt,conm,savm,state_dist,cdiff,xgrid.dist] = solve_EGP(beta,p,...
        xgrid,sgrid,betatrans,u1,beq1,u1inv,ergodic_tol,income,ExpandGrid);
    
    %% Store important moments
    
    if p.ExpandGridF == 1
        nn = p.nxlong;
    else
        nn = p.nx;
    end
    
    ymat_onxgrid = kron(ymat,ones(nn,1));
    netymat_onxgrid = kron(netymat,ones(nn,1));
    
    results.mean_s = savm' * state_dist;
    results.mean_x = xgrid.dist(:)' * state_dist;
    results.mean_grossy = (ymat_onxgrid*yTdist)' * state_dist;
    results.mean_loggrossy = (log(ymat_onxgrid)*yTdist)' * state_dist;
    results.mean_nety = (netymat_onxgrid*yTdist)' * state_dist;
    results.mean_lognety = (log(netymat_onxgrid)*yTdist)' * state_dist;
    results.var_loggrossy = state_dist' * (log(ymat_onxgrid) - results.mean_loggrossy).^2 * yTdist;
    results.var_lognety = state_dist' * (log(netymat_onxgrid)- results.mean_lognety).^2 * yTdist;
    
    % Error checks
    state_dist_multidim = reshape(state_dist,[nn p.nyP p.nyF p.nb]);
    con_multidim = reshape(conm,[nn p.nyP p.nyF p.nb]);
    sav_multidim = reshape(savm,[nn p.nyP p.nyF p.nb]);
    sav_wide = reshape(sav_opt,[p.nx p.nyP p.nyF p.nb]);
    mean_x_check = (1+p.r)*results.mean_s + results.mean_nety;
    temp = permute(state_dist_multidim,[2 1 3 4]);
    yPdist_check = sum(sum(sum(temp,4),3),2);
    

    %% Store problems
    results.issues = {};
    if cdiff > p.tol_iter
        results.issues = [results.issues,'NoEGPConv'];
    end
    if (results.mean_s<p.targetAY-1) || (results.mean_s>p.targetAY+1)
        results.issues = [results.issues,'BadAY'];
    end
    if abs((results.mean_x-mean_x_check)/results.mean_x)> 1e-3
        results.issues = [results.issues,'DistNotStationary'];
    end
    if abs((meannety-results.mean_nety)/meannety) > 1e-3
        results.issues = [results.issues,'BadNetIncomeMean'];
    end
    if norm(yPdist_check-yPdist) > 1e-3
        results.issues = [results.issues,'BadGrossIncDist'];
    end
    if min(state_dist) < - 0.01
        results.issues = [results.issues,'NegativeStateProbability'];
    end

    %% WEALTH DISTRIBUTION
    temp = sortrows([savm state_dist]);
    sav_sort = temp(:,1);
    state_dist_sort = temp(:,2);
    state_dist_cum = cumsum(state_dist_sort);
    
    results.frac_constrained = (savm<=p.borrow_lim)' * state_dist;
    results.frac_less5perc_labincome = (savm<0.05)' * state_dist;
    % wealth percentiles;
    percentiles = [0.1 0.25 0.5 0.9 0.99];
    wealthps = zeros(numel(percentiles),1);
    count = 1;
    for percentile = percentiles
        [~,pind] = max(percentile<state_dist_cum,[],1);
        wealthps(count) = sav_sort(pind);
        count = count + 1;
    end
    results.p10wealth = wealthps(1);
    results.p25wealth = wealthps(2);
    results.p50wealth = wealthps(3);
    results.p90wealth = wealthps(4);
    results.p99wealth = wealthps(5);
    
    binwidth = 0.25;
    bins = 0:binwidth:p.xmax;
    values = zeros(p.xmax+1,1);
    ibin = 1;
    for bin = bins
        if bin < p.xmax
            idx = (sav_sort>=bin) & (sav_sort<bin+binwidth);
        else
            idx = (sav_sort>=bin) & (sav_sort<=bin+binwidth);
        end
        values(ibin) = sum(state_dist_sort(idx));
        ibin = ibin + 1;
    end
    
    
    %% Simulate
    if p.Simulate == 1
        [simulations ssim] = simulate(p,income,labtaxthresh,sav_wide,...
    xgrid.wide,lumptransfer,betacumdist,betacumtrans);
    else
        simulations =[];
    end

    %% MAKE PLOTS
   

    if p.MakePlots ==1 

     figure(1);

        %plot for median fixed effect
        if mod(p.nyF,2)==1
            iyF = (p.nyF+1)/2;
        else
            iyF = p.nyF/2;
        end

        % plot for first beta
        iyb = 1;
        % if nb = 1, force plot of first beta
        if p.nb == 1
            iyb = 1;
        end

        % consumption policy function
        subplot(2,4,1);
        plot(xgrid.dist(:,1,iyF,iyb),con_multidim(:,1,iyF,iyb),'b-',xgrid.dist(:,p.nyP,iyF,iyb),con_multidim(:,p.nyP,iyF,iyb),'r-','LineWidth',1);
        grid;
        xlim([p.borrow_lim p.xmax]);
        title('Consumption Policy Function');
        legend('Lowest income state','Highest income state');

        % savings policy function
        subplot(2,4,2);
        plot(xgrid.dist(:,1,iyF),sav_multidim(:,1,iyF)./xgrid.dist(:,1,iyF),'b-',xgrid.dist(:,p.nyP,iyF),sav_multidim(:,p.nyP,iyF)./xgrid.dist(:,p.nyP,iyF),'r-','LineWidth',1);
        hold on;
        plot(sgrid.short,ones(p.nx,1),'k','LineWidth',0.5);
        hold off;
        grid;
        xlim([p.borrow_lim p.xmax]);
        title('Savings Policy Function s/x');

        % consumption policy function: zoomed in
        subplot(2,4,3);
        plot(xgrid.dist(:,1,iyF),con_multidim(:,1,iyF),'b-',xgrid.dist(:,p.nyP,iyF),con_multidim(:,p.nyP,iyF),'r-','LineWidth',2);
        grid;
        xlim([0 4]);
        title('Consumption: Zoomed');

         % savings policy function: zoomed in
        subplot(2,4,4);
        plot(xgrid.dist(:,1,iyF),sav_multidim(:,1,iyF)./xgrid.dist(:,1,iyF),'b-',xgrid.dist(:,p.nyP,iyF),sav_multidim(:,p.nyP,iyF)./xgrid.dist(:,p.nyP,iyF),'r-','LineWidth',2);
        hold on;
        plot(sgrid.short,ones(p.nx,1),'k','LineWidth',0.5);
        hold off;
        grid;
        xlim([0 4]);
        title('Savings (s/x): Zoomed');
        
         % gross income distribution
        subplot(2,4,5);
        b = bar(ysort,ysortdist);
        b.FaceColor = 'blue';
        b.EdgeColor = 'blue';
        grid;
        xlim([0 10]);
        title('Gross Income PMF');
        
         % asset distribution
        subplot(2,4,6);
        b = bar(bins,values);
        b.FaceColor = 'blue';
        b.EdgeColor = 'blue';
        grid;
        xlim([-0.4 10]);
        ylim([0 1]);
        title('Asset PMF, Binned');

         % simulation convergence
        if p.Simulate == 1
            subplot(2,4,7);
            plot(1:p.Tsim,mean(ssim),'b','LineWidth',2);
            grid;
            xlim([0 p.Tsim]);
            title('Mean savings (sim)');
        end
    end

    %% COMPUTE MPCs
    if p.ComputeMPC ==1
        %theoretical mpc lower bound
        mpclim = p.R*((beta*p.R)^-(1./p.risk_aver))-1;
        Nmpcamount = numel(p.mpcfrac);
        %mpc amounts
        for im = 1:Nmpcamount
            mpcamount{im} = p.mpcfrac{im} * meany;
            xgrid.mpc{im} = xgrid.dist + mpcamount{im};
        end

        results.mpcamount = mpcamount;
        
        % Create interpolants for computing mpc's
        for ib = 1:p.nb
        for iyF = 1:p.nyF
        for iyP = 1:p.nyP
                coninterp{iyP,iyF,ib} = griddedInterpolant(xgrid.dist(:,iyP,iyF,ib),con_multidim(:,iyP,iyF,ib),'linear');
        end
        end
        end
        
        % mpc functions
        for im = 1:Nmpcamount
            mpc{im} = zeros(nn,p.nyP,p.nyF,p.nb);
            % iterate over (yP,yF,beta)
            for ib = 1:p.nb
            for iyF = 1:p.nyF
            for iyP = 1:p.nyP 
                mpc{im}(:,iyP,iyF,ib) = (coninterp{iyP,iyF,ib}(xgrid.mpc{im}(:,iyP,iyF,ib))...
                    - con_multidim(:,iyP,iyF,ib))/mpcamount{im};     
            end
            end
            end
            % average mpc
            results.avg_mpc{im} = mpc{im}(:)' * state_dist;
        end
    end
    
%% Print Results
    if p.PrintStats == 1
        print_statistics(results,simulations,p);
    end
end