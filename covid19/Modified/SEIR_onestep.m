function [x_new, pop_new] = SEIR_onestep(x,M,pop,ts,pop0)

[states, params] = unpack_x(x);
Mt = M(:,:,ts);
[states_new] = integrate_ODE_onestep(states, params, pop, Mt);

[beta, mu, theta, Z, alpha, D] = unpack_params(params); % each param is 1xnum_ens
pop_new = pop + sum(Mt,2)*theta - sum(Mt,1)'*theta;  % eqn 5
minfrac=0.6;
ndx = find(pop_new < minfrac*pop0);
pop_new(ndx)=pop0(ndx)*minfrac;

x_new = pack_x(states_new, params);

end

function [states_new] = integrate_ODE_onestep(states, params, pop, Mt)
% Integrates the ODE eqns 1-4 for one time step using RK4 method

[S, E, Is, Ia, ~] = unpack_states(states); % nloc * nens

% first step of RK4
first_step = true;

stats = compute_stats(S, E, Is, Ia, Mt, pop, params, first_step);
stats = sample_stats(stats);
[sk1, ek1, Isk1, iak1, ik1i] = compute_deltas(stats);

%second step
S1=S+sk1/2;
E1=E+ek1/2;
Is1=Is+Isk1/2;
Ia1=Ia+iak1/2;
first_step = false;

stats = compute_stats(S1, E1, Is1, Ia1, Mt, pop, params, first_step);
stats = sample_stats(stats);
[sk2, ek2, Isk2, iak2, ik2i] = compute_deltas(stats); 

%third step
S2=S+sk2/2;
E2=E+ek2/2;
Is2=Is+Isk2/2;
Ia2=Ia+iak2/2;

stats = compute_stats(S2, E2, Is2, Ia2, Mt, pop, params, first_step);
stats = sample_stats(stats);
[sk3, ek3, Isk3, iak3, ik3i] = compute_deltas(stats); 

%fourth step
S3=S+sk3;
E3=E+ek3;
Is3=Is+Isk3;
Ia3=Ia+iak3;

stats = compute_stats(S3, E3, Is3, Ia3, Mt, pop, params, first_step);
stats = sample_stats(stats);
[sk4, ek4, Isk4, iak4, ik4i] = compute_deltas(stats); 


%%%%% Compute final states
S_new=S+round(sk1/6+sk2/3+sk3/3+sk4/6);
E_new=E+round(ek1/6+ek2/3+ek3/3+ek4/6);
Is_new=Is+round(Isk1/6+Isk2/3+Isk3/3+Isk4/6);
Ia_new=Ia+round(iak1/6+iak2/3+iak3/3+iak4/6);
Incidence_new=round(ik1i/6+ik2i/3+ik3i/3+ik4i/6);
obs_new=Incidence_new;
states_new = pack_states(S_new, E_new, Is_new, Ia_new, obs_new);

end


function [ESenter, ESleft, EEenter, EEleft, EIaenter, EIaleft, Eexps, Eexpa, Einfs, Einfa, Erecs, Ereca] = unpack_stats(stats)
    ESenter = stats(:,:,1);
    ESleft = stats(:,:,2);
    EEenter = stats(:,:,3);
    EEleft = stats(:,:,4);
    EIaenter = stats(:,:,5);
    EIaleft = stats(:,:,6);
    Eexps = stats(:,:,7);
    Eexpa = stats(:,:,8);
    Einfs = stats(:,:,9);
    Einfa = stats(:,:,10);
    Erecs = stats(:,:,11);
    Ereca = stats(:,:,12);
end

function stats=pack_stats(ESenter, ESleft, EEenter, EEleft, EIaenter, EIaleft, Eexps, Eexpa, Einfs, Einfa, Erecs, Ereca)
    % stats is num_loc * num_ens * num_stats
    num_stats = 12; % U1...U12 in paper
    [num_loc, num_ens] = size(ESenter);
    stats = zeros(num_loc, num_ens, num_stats);
    stats(:,:,1)=ESenter; % U3 
    stats(:,:,2)=ESleft; % U4
    stats(:,:,3)=EEenter; % U7
    stats(:,:,4)=EEleft; % U8
    stats(:,:,5)=EIaenter; % U11
    stats(:,:,6)=EIaleft; % U12
    stats(:,:,7)=Eexps; % U1 
    stats(:,:,8)=Eexpa; % U2 
    stats(:,:,9)=Einfs; % U5
    stats(:,:,10)=Einfa; % U6
    stats(:,:,11)=Erecs; % U9
    stats(:,:,12)=Ereca; % U10
end
    

% S = suspectible (original name Ts)
% E = exposed (original name Te)
% IR = infected reported (original name TIs)
% IU = infected unreported (original name Tia)
function stats = compute_stats(S, E, IR, IU, Mt, pop, params, step1)
[num_loc, num_ens] = size(S);
[beta, mu, theta, Z, alpha, D] = unpack_params(params); % each param is 1xnum_ens

if step1
    ESenter=(ones(num_loc,1)*theta).*(Mt*(S./(pop-IU)));
    ESleft=min((ones(num_loc,1)*theta).*(S./(pop-IU)).*(sum(Mt)'*ones(1,num_ens)),S);
    EEenter=(ones(num_loc,1)*theta).*(Mt*(E./(pop-IU)));
    EEleft=min((ones(num_loc,1)*theta).*(E./(pop-IU)).*(sum(Mt)'*ones(1,num_ens)),E);
    EIaenter=(ones(num_loc,1)*theta).*(Mt*(IU./(pop-IU)));
    EIaleft=min((ones(num_loc,1)*theta).*(IU./(pop-IU)).*(sum(Mt)'*ones(1,num_ens)),IU);
else
    ESenter=(ones(num_loc,1)*theta).*(Mt*(S./(pop-IR)));
    ESleft=min((ones(num_loc,1)*theta).*(S./(pop-IR)).*(sum(Mt)'*ones(1,num_ens)),S);
    EEenter=(ones(num_loc,1)*theta).*(Mt*(E./(pop-IR)));
    EEleft=min((ones(num_loc,1)*theta).*(E./(pop-IR)).*(sum(Mt)'*ones(1,num_ens)),E);
    EIaenter=(ones(num_loc,1)*theta).*(Mt*(IU./(pop-IU)));
    EIaleft=min((ones(num_loc,1)*theta).*(IU./(pop-IR)).*(sum(Mt)'*ones(1,num_ens)),IU);
end

Eexps=(ones(num_loc,1)*beta).*S.*IR./pop;
Eexpa=(ones(num_loc,1)*mu).*(ones(num_loc,1)*beta).*S.*IU./pop;
Einfs=(ones(num_loc,1)*alpha).*E./(ones(num_loc,1)*Z);
Einfa=(ones(num_loc,1)*(1-alpha)).*E./(ones(num_loc,1)*Z);
Erecs=IR./(ones(num_loc,1)*D);
Ereca=IU./(ones(num_loc,1)*D);

stats = pack_stats(ESenter, ESleft, EEenter, EEleft, EIaenter, EIaleft, Eexps, Eexpa, Einfs, Einfa, Erecs, Ereca);
stats = max(stats, 0);
end

function samples = sample_stats(stats)
[nloc, nens, nstat] = size(stats);
samples = zeros(nloc, nens, nstat);
for i=1:nstat
    samples(:,:,i) = poissrnd(stats(:,:,i));
end
%{
sz = size(stats);
stats = reshape(stats, [prod(sz), 1]);
samples = poissrnd(stats);
samples = reshape(samples, sz);
%}
end

function [sk, ek, Isk, iak, ik] = compute_deltas(stats)
% each delta is nloc*nens
[ESenter, ESleft, EEenter, EEleft, EIaenter, EIaleft, Eexps, Eexpa, Einfs, Einfa, Erecs, Ereca] = unpack_stats(stats);
sk=-Eexps-Eexpa+ESenter-ESleft;
ek=Eexps+Eexpa-Einfs-Einfa+EEenter-EEleft;
Isk=Einfs-Erecs;
iak=Einfa-Ereca+EIaenter-EIaleft;
ik=Einfs;
end
    