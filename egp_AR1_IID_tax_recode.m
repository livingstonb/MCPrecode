% Endogenous Grid Points with AR1 + IID Income
% Cash on Hand as State variable
% Includes NIT and discount factor heterogeneity
% Greg Kaplan 2017

clear;
close all;

path = '/Users/brianlivingston/Documents/GitHub/MPCrecode';
addpath([path '/Auxiliary Functions']);
cd(path);

%% PARAMETERS

%returns
r  = 0.005;
R = 1+ r;

%demographics
dieprob     = 1/50;

% preferences
risk_aver   = 1;
beta        = 0.97365; %if not iterating on discount rate
temptation = 0.0;

betaL = 0.90; %guesses if iterating on discount rate;
betaH = 1/(R*(1-dieprob));

%warm glow bequests: bequest_weight = 0 is accidental
bequest_weight = 0; %0.07;
bequest_luxury = 2; %0.01;

% income risk: AR(1) + IID in logs
LoadIncomeProcess = 0;
nyT         = 5; %transitory component (not a state variable) (set to 1 for no Transitory Shocks)

%only relevant if LoadIncomeProcess==0
sd_logyT   = sqrt(0.2431);  %0.20; %relevant if nyT>1
lambdaT = 1; % arrival rate of shocks;

nyP         = 9; %11 persistent component
sd_logyP    = sqrt(0.0047); %0.1950;
rho_logyP   = 0.9947;

nyF     = 1;
sd_logyF    = 0;

% cash on hand / savings grid
nx          = 50;
xmax        = 40;  %multiple of mean gross labor income
xgrid_par   = 0.4; %1 for linear, 0 for L-shaped
borrow_lim  = 0;

%government
labtaxlow       = 0.0; %proportional tax
labtaxhigh      = 0; %additional tax on incomes above threshold
labtaxthreshpc   = 0.99; %percentile of earnings distribution where high tax rate kicks in

savtax          = 0; %0.0001;  %tax rate on savings
savtaxthresh    = 0; %multiple of mean gross labor income


%discount factor shocks;
nb = 1;  %1 or 2
betawidth = 0.065; % beta +/- beta width
betaswitch = 1/50; %0;

% computation
max_iter    = 1e4;
tol_iter    = 1.0e-4;
Nsim        = 100000;
Tsim        = 200;

targetAY = 12.0;
maxiterAY = 20;
tolAY = 1.0e-4;

%mpc options
mpcfrac{1}  = 1.0e-10; %approximate thoeretical mpc
mpcfrac{2}  = 0.01; % 1 percent of average gross labor income: approx $500
mpcfrac{3}  = 0.10; % 5 percent of average gross labor income: approx $5000

N = nyP*nyF*nx*nb;

%% OPTIONS
IterateBeta = 0;
Display     = 1;
MakePlots   = 1;
ComputeMPC  = 1;
SolveDeterministic = 1;

%% INCOME GRIDS

%persistent income: rowenhurst
if LoadIncomeProcess == 1
    logyPgrid = load('QuarterlyIncomeDynamics/TransitoryContinuous/logyPgrid.txt');
    yPdist = load('QuarterlyIncomeDynamics/TransitoryContinuous/yPdist.txt');
    yPtrans = load('QuarterlyIncomeDynamics/TransitoryContinuous/yPtrans.txt');
    nyP = length(logyPgrid);
    
elseif nyP>1
    [logyPgrid, yPtrans, yPdist] = rouwenhorst(nyP, -0.5*sd_logyP^2, sd_logyP, rho_logyP);
else
    logyPgrid = 0;
    yPdist = 1;
    yPtrans = 1;
end    
logyPgrid = logyPgrid';
yPgrid = exp(logyPgrid);
yPcumdist = cumsum(yPdist,1);
yPcumtrans = cumsum(yPtrans,2);
    

% transitory income: disretize normal distribution
% if nyT>1
%     width = fzero(@(x)discrete_normal(nyT,-0.5*sd_logyT^2 ,sd_logyT ,x),2);
%     [~,logyTgrid,yTdist] = discrete_normal(nyT,-0.5*sd_logyT^2 ,sd_logyT ,width);
% elseif nyT==1
%     logyTgrid = 0;
%     yTdist = 1;
% end
% yTgrid = exp(logyTgrid);


% transitory income: disretize normal distribution
if LoadIncomeProcess == 1
    sig2T = load('QuarterlyIncomeDynamics/TransitoryContinuous/sig2T.txt');
    lambdaT = load('QuarterlyIncomeDynamics/TransitoryContinuous/lambdaT.txt');
end

if nyT>1
    
    %moments of mixture distribution
    lmu2 = lambdaT.*sd_logyT^2;
    lmu4 = 3.*lambdaT.*(sd_logyT^4);

    %fit thjose moments
    optionsNLLS = optimoptions(@lsqnonlin,'Display','Off');
    lpar = lsqnonlin(@(lp)discretize_normal_var_kurt(lp,nyT,lmu2,lmu4),[2 0.1],[],[],optionsNLLS);
    [lf,lx,lp] = discretize_normal_var_kurt(lpar,nyT,lmu2,lmu4);
    logyTgrid = lx;
    yTdist = lp;
    yTcumdist = cumsum(yTdist,1);
    
%     width = fzero(@(x)discrete_normal(nyT,-0.5*sd_logyT^2 ,sd_logyT ,x),2);    
%     [~,logyTgrid,yTdist] = discrete_normal(nyT,-0.5*sd_logyT^2 ,sd_logyT ,width);

elseif nyT==1
    logyTgrid = 0;
    yTdist = 1;
end
yTgrid = exp(logyTgrid);

% fixed effect
if nyF>1
    width = fzero(@(x)discrete_normal(nyF,-0.5*sd_logyF^2 ,sd_logyF ,x),2);
    [~,logyFgrid,yFdist] = discrete_normal(nyF,-0.5*sd_logyF^2 ,sd_logyF ,width);
elseif nyF==1
    logyFgrid = 0;
    yFdist = 1;
end
yFgrid = exp(logyFgrid);
yFcumdist = cumsum(yFdist,1);

% check if yFgrid is row vector like yPgrid, if not, need to rewrite code
assert(size(yFgrid,1)==1);

% transition probabilities for yP-yF combined grid
ytrans = kron(eye(nyF),yPtrans);

%% DISCOUNT FACTOR

if IterateBeta == 0
    maxiterAY = 1;    
end

if IterateBeta == 1
    beta = (betaH + betaL)/2;
end

%initial discount factor grid
if  nb == 1
    betagrid = beta;
    betadist = 1;
    betatrans = 1;
elseif nb ==2 
    betagrid = [beta-betawidth;beta+betawidth];
    betadist = [0.5;0.5];
    betatrans = [1-betaswitch betaswitch; betaswitch 1-betaswitch]; %transitions on average once every 40 years;
else
    error('nb must be 1 or 2');
end
betacumdist = cumsum(betadist);
betacumtrans = cumsum(betatrans,2);


%% ASSET AND INCOME GRIDS

sgrid = linspace(0,1,nx)';
sgrid = sgrid.^(1./xgrid_par);
sgrid = borrow_lim + (xmax-borrow_lim).*sgrid;

sgrid_wide = repmat(sgrid,1,nyP*nyF*nb);
ns = nx;

% construct matrix of y combinations
ymat = reshape(repmat(yPgrid,ns,1),ns*nyP,1);
ymat = repmat(ymat,nyF,1) .* reshape(repmat(yFgrid,nyP*ns,1),nyP*ns*nyF,1);
ymat = repmat(ymat,nb,1)*yTgrid';

ymatdist = reshape(repmat(yPdist',ns,1),ns*nyP,1);
ymatdist = repmat(ymatdist,nyF,1) .* reshape(repmat(yFdist',nyP*ns,1),nyP*ns*nyF,1);
ymatdist = repmat(ymatdist,nb,1)*yTdist';


% ymat = repmat(yPgrid',nyF,1).*reshape(repmat(yFgrid',nyP,1),nyF*nyP,1)...
%         *yTgrid';
% ymatdist = repmat(yPdist,nyF,1).*reshape(repmat(yFdist,nyP,1),nyF*nyP,1)...
%         *yTdist';

% find mean y
ymat_yvals = ymat(1:ns:ns*nyF*nyP,:);
ymatdist_pvals = ymatdist(1:ns:ns*nyF*nyP,:);
temp = sortrows([ymat_yvals(:) ymatdist_pvals(:)],1);
ysortvals = temp(:,1);
ycumdist = cumsum(temp(:,2));
meany = ymat_yvals(:)'*ymatdist_pvals(:);
totgrossy = meany;

% find tax threshold on labor income
if numel(ysortvals)>1
    labtaxthresh = lininterp1(ycumdist,ysortvals,labtaxthreshpc);
else
    labtaxthresh = 0;
end    

totgrossyhigh = max(ymat_yvals(:)-labtaxthresh,0)'*ymatdist_pvals(:);
lumptransfer = labtaxlow*totgrossy + labtaxhigh*totgrossyhigh;
netymat = lumptransfer + (1-labtaxlow)*ymat - labtaxhigh*max(ymat-labtaxthresh,0);
netymat_yvals = netymat(1:ns:ns*nyF*nyP,:);
meannety = netymat_yvals(:)'*ymatdist_pvals(:);

% xgrid, indexed by beta,yF,yP,x
% cash on hand grid: different min points for each value of (iyP)
xgrid = sgrid_wide(:) + min(netymat,[],2);

%% UTILITY FUNCTION, BEQUEST FUNCTION

if risk_aver==1
    u = @(c)log(c);
    beq = @(a) bequest_weight.* log(a+ bequest_luxury);
else    
    u = @(c)(c.^(1-risk_aver)-1)./(1-risk_aver);
    beq = @(a) bequest_weight.*((a+bequest_luxury).^(1-risk_aver)-1)./(1-risk_aver);
end    

u1 = @(c) c.^(-risk_aver);
u1inv = @(u) u.^(-1./risk_aver);

beq1 = @(a) bequest_weight.*(a+bequest_luxury).^(-risk_aver);


%% EGP Iteration

% initial guess for consumption function
con = r * xgrid;

% Expectations operator (conditional on yT)
Emat = kron(betatrans,kron(ytrans,speye(nx)));

% discount factor matrix
betastacked = reshape(repmat(betagrid',nyP*nyF*nx,1),N,1);
betamatrix = spdiags(betastacked,0,N,N);

% next period's, cash-on-hand as function of saving

xgrid_wide = reshape(xgrid,ns,nyP*nyF*nb);

% RUN ITERATIONS TO FIND POLICY FUNCTION
[con_opt,sav,cdiff] = find_policy(con,ns,nyP,nyF,nyT,nb,netymat,...
                            xgrid_wide,dieprob,betastacked,Emat,yTdist,...
                            sgrid_wide,savtax,savtaxthresh,...
                            u1inv,u1,borrow_lim,N,max_iter,tol_iter,r);
con = con_opt;

%% Stationary Distribution
sav_wide = reshape(sav,nx,N/nx);
state_dist = find_stationary(dieprob,ytrans,yPdist,nyP,nyF,nx,betatrans,...
                                N,xgrid_wide,sav_wide,sgrid,borrow_lim,...
                                xmax,r,nyT,netymat,yTdist);

mean_s = sav' * state_dist(:)
mean_x = xgrid' * state_dist(:)

%wealth_income = meanwealth/meany;





%% MAKE PLOTS
newdim = [nx nyP nyF nb];
con_multidim = reshape(con,newdim);
sav_multidim = reshape(sav,newdim);
xgrid_multidim = reshape(xgrid,newdim);

if MakePlots ==1 
    
 figure(1);
 
    %plot for median fixed effect
    if mod(nyF,2)==1
        iyF = (nyF+1)/2;
    else
        iyF = iyF/2;
    end
    
    % plot for first beta
    iyb = 1;
    % if nb = 1, force plot of first beta
    if nb == 1
        iyb = 1;
    end
    
    % consumption policy function
    subplot(2,4,1);
    plot(xgrid_multidim(:,1,iyF,iyb),con_multidim(:,1,iyF,iyb),'b-',xgrid_multidim(:,nyP,iyF,iyb),con_multidim(:,nyP,iyF,iyb),'r-','LineWidth',1);
    grid;
    xlim([borrow_lim xmax]);
    title('Consumption Policy Function');
    legend('Lowest income state','Highest income state');

    % savings policy function
    subplot(2,4,2);
    plot(xgrid_multidim(:,1,iyF),sav_multidim(:,1,iyF)./xgrid_multidim(:,1,iyF),'b-',xgrid_multidim(:,nyP,iyF),sav_multidim(:,nyP,iyF)./xgrid_multidim(:,nyP,iyF),'r-','LineWidth',1);
    hold on;
    plot(sgrid,ones(nx,1),'k','LineWidth',0.5);
    hold off;
    grid;
    xlim([borrow_lim xmax]);
    title('Savings Policy Function s/x');

    % consumption policy function: zoomed in
    subplot(2,4,3);
    plot(xgrid_multidim(:,1,iyF),con_multidim(:,1,iyF),'b-o',xgrid_multidim(:,nyP,iyF),con_multidim(:,nyP,iyF),'r-o','LineWidth',2);
    grid;
    xlim([0 4]);
    title('Consumption: Zoomed');

     % savings policy function: zoomed in
    subplot(2,4,4);
    plot(xgrid_multidim(:,1,iyF),sav_multidim(:,1,iyF)./xgrid_multidim(:,1,iyF),'b-o',xgrid_multidim(:,nyP,iyF),sav_multidim(:,nyP,iyF)./xgrid_multidim(:,nyP,iyF),'r-o','LineWidth',2);
    hold on;
    plot(sgrid,ones(nx,1),'k','LineWidth',0.5);
    hold off;
    grid;
    xlim([0 4]);
    title('Savings (s/x): Zoomed');
end

%% COMPUTE MPCs
if ComputeMPC ==1
    %theoretical mpc lower bound
    mpclim = R*((beta*R)^-(1./risk_aver))-1;
    Nmpcamount = numel(mpcfrac);
    %mpc amounts
    for im = 1:Nmpcamount
        mpcamount{im} = mpcfrac{im} * meany;
        xgrid_mpc{im} = xgrid + mpcamount{im};
    end
end
