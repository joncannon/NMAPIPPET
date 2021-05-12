% © Jonathan Cannon, MIT, 2020
% Simulates PIPPET model with specified parameters.


function [mu_list, V_list, lambda_history, surprisal_prepost, grad_surprisal] = run_PIPPET(params)

t_max = params.tmax;
dt = params.dt;
sigma_phi = params.sigma_phi;
eta_phi = params.eta_phi;

t_list = 0:dt:ceil(t_max/dt)*dt;

mu_list = zeros(size(t_list));
mu_list(1) = params.mu_0;

V_list = zeros(size(t_list));
V_list(1) = params.V_0;

surprisal_prepost = zeros([numel(t_list), params.n_streams, 2]);

event_num = ones(1,params.n_streams);
%tap_num = 0;
%tap_thresh = params.tap_threshold;

lambda_history = cell(1, numel(params.streams));

for j = 1:params.n_streams;
    lambda_history{j} = zeros(numel(params.streams{j}.e_lambdas), numel(t_list));
    lambda_history{j}(:,1) = params.streams{j}.e_lambdas;
end

for i=2:length(t_list)
    t = t_list(i);

    t_past = t_list(i-1);
    V_past = V_list(i-1);
    mu_past = mu_list(i-1);
    
    active_lambdas = cell(1, numel(params.streams));
    for j = 1:params.n_streams
        active_lambdas{j} = lambda_history{j}(:,i-1)';
    end
    
    dmu_sum = 0;
    dV_sum = 0;
    
    grad_surprisal_sum = 0;
    
    for j = 1:params.n_streams
        dmu_sum = dmu_sum + params.streams{j}.Lambda(mu_past, V_past, active_lambdas{j})...
            *(params.streams{j}.mu_hat(mu_past, V_past, active_lambdas{j})-mu_past);
    end
    
    dmu = dt*(1 - dmu_sum) + sqrt(dt)*eta_phi*randn();
    mu = mu_past+dmu;
    
    for j = 1:params.n_streams
        dV_sum = dV_sum + params.streams{j}.Lambda(mu_past, V_past, active_lambdas{j})*(params.streams{j}.V_hat(mu, mu_past, V_past, active_lambdas{j})-V_past);
    end
    
    dV = dt*(sigma_phi^2 - dV_sum);
    V = V_past+dV;
    
    for j = 1:params.n_streams
        if event_num(j) <= length(params.streams{j}.perceived_event_times) && (t>=params.streams{j}.perceived_event_times(event_num(j)) && t_past<=params.streams{j}.perceived_event_times(event_num(j)))
            mu_tmp = params.streams{j}.mu_hat(mu, V, active_lambdas{j});
            V = params.streams{j}.V_hat(mu_tmp, mu, V, active_lambdas{j});
            mu = mu_tmp;
            event_num(j) = event_num(j)+1;
            surprisal_prepost(i,j,1) = -log(params.streams{j}.Lambda(mu_past, V_past, active_lambdas{j})*dt);
            surprisal_prepost(i,j,2) = -log(params.streams{j}.Lambda(mu, V, active_lambdas{j})*dt);
            grad_surprisal_sum = grad_surprisal_sum ...
                +(-log(params.streams{j}.Lambda(mu_past+.01, V_past, active_lambdas{j})*dt) + log(params.streams{j}.Lambda(mu_past-.01, V_past, active_lambdas{j})*dt))/.02;
            
            if params.masking
                active_lambdas{j} = active_lambdas{j} .* (1 - (params.streams{j}.Lambda_i_list(mu_past, V_past, active_lambdas{j}) / params.streams{j}.Lambda(mu_past, V_past, active_lambdas{j})));
            end
        else
        
            surprisal_prepost(i,j,1) = -log(1-params.streams{j}.Lambda(mu_past, V_past, active_lambdas{j})*dt);
            surprisal_prepost(i,j,2) = -log(1-params.streams{j}.Lambda(mu, V, active_lambdas{j})*dt);
            grad_surprisal_sum = grad_surprisal_sum ...
                +(-log(1-params.streams{j}.Lambda(mu_past+.01, V_past, active_lambdas{j})*dt) + log(1-params.streams{j}.Lambda(mu_past-.01, V_past, active_lambdas{j})*dt))/.02;
        end
        lambda_history{j}(:,i) = active_lambdas{j}';
    end
    if params.tapping
%         if mu > tap_num * params.intertap_phase + tap_thresh
%             tap_time = t + params.intertap_phase - tap_thresh...
%                          + params.motor_eta*randn();
%             params.streams{params.tap_stream}.event_times(end+1) = tap_time;
%             params.streams{params.tap_stream}.perceived_event_times(end+1) = tap_time + params.eta_e*randn();
%             tap_num = tap_num+1;
%         end
    end

    mu_list(i) = mu;
    V_list(i) = V;
    grad_surprisal(i) = grad_surprisal_sum;
end



if params.display
    figure()
    tiledlayout(1,5);
    ax1 = nexttile;
    hold on
    for j = 1:params.n_streams
        plot(params.streams{j}.expect_func(t_list), t_list, params.stream_colors{j});
    end
    ylim([0, t_max])
    ylabel('Phase $\phi$','Interpreter','Latex')
    xlabel({'Expectation';'$\lambda(\phi)$'},'Interpreter','Latex');
    set(gca,'Yticklabel',[])
    sgtitle(params.title)
    
    ax2 = nexttile([1,4]);
    axis square
    
    shadedErrorBar(t_list, mu_list, 2*sqrt(V_list));%, 'lineProps',{'-','markerfacecolor',[0    0.4470    0.7410]} )
    ylim([0, t_max])
    xlim([0, t_max])
    axis square
    hold on
    for j = 1:params.n_streams
        for i=1:length(params.streams{j}.event_times)
            width = .5;
            linespec = params.stream_colors{j};
            if numel(params.streams{j}.highlight_event_indices)==length(params.streams{j}.event_times)
                
                if params.streams{j}.highlight_event_indices(i)==0
                    linespec = params.stream_colors{j}+"-.";
                elseif params.streams{j}.highlight_event_indices(i)==2
                    width = 1.5;
                end
            end
            plot([1,1]*params.streams{j}.perceived_event_times(i), [0,t_max], linespec, 'LineWidth', width);
        end
%         if params.tapping
%             for i=1:length(params.streams{params.tap_stream}.event_times)
%                 width = .5;
%                 linespec = 'k:';
% 
%                 plot([1,1]*params.streams{params.tap_stream}.event_times(i), [0,t_max], linespec, 'LineWidth', width);
%             end
%         end
        

        for i=1:length(params.streams{j}.e_means)
            width = .5;
            linespec = 'b';
            if params.streams{j}.highlight_expectations(i)==0
                linespec = 'b-.';
            elseif params.streams{j}.highlight_expectations(i)==2
                width = 1.5;
            end
            plot([0,t_max], [1,1]*params.streams{j}.e_means(i), linespec, 'LineWidth', width)
        end
    end
    xlabel('Time (sec)','Interpreter','Latex')
    
    
    linkaxes([ax1 ax2],'y')
    
end