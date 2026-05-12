%% 中国国债数据分析 - 完整流程
% 作者: 元宝
% 描述: 对中国国债日收盘价进行全面的金融时间序列分析

clear all; close all; clc;
warning('off', 'all');

%% 1. 数据导入与预处理
disp('========== 1. 数据导入与预处理 ==========');

% 读取Excel文件
filename = 'bond.xlsx';
try
    data = readtable(filename);
    fprintf('成功读取文件: %s\n', filename);
    fprintf('数据维度: %d 行 × %d 列\n', size(data));
    disp('列名:');
    disp(data.Properties.VariableNames);
catch
    error('无法读取文件，请检查文件路径和格式');
end

% 假设数据包含'date'和'close'列
if ~all(ismember({'date', 'close'}, data.Properties.VariableNames))
    error('数据必须包含date和close列');
end

% 数据排序和清理
data.date = datetime(data.date, 'InputFormat', 'yyyy-MM-dd');
data = sortrows(data, 'date');

% 计算日收益率
price = data.close;
returns = price2ret(price) * 100;  % 转换为百分比收益率
dates = data.date(2:end);

fprintf('收益率样本数: %d\n', length(returns));
fprintf('时间范围: %s 到 %s\n', datestr(dates(1)), datestr(dates(end)));

%% 2. 描述性统计分析
disp('========== 2. 描述性统计分析 ==========');

figure('Position', [100, 100, 1200, 800]);

% 子图1: 价格序列
subplot(3,3,1);
plot(dates, price(2:end), 'b-', 'LineWidth', 1.5);
title('中国国债价格序列');
xlabel('日期');
ylabel('价格');
grid on;
datetick('x', 'yyyy', 'keeplimits');

% 子图2: 收益率序列
subplot(3,3,2);
plot(dates, returns, 'b-', 'LineWidth', 0.5);
title('日收益率序列');
xlabel('日期');
ylabel('收益率(%)');
grid on;
datetick('x', 'yyyy', 'keeplimits');

% 子图3: 收益率分布直方图
subplot(3,3,3);
histfit(returns, 50);
title('收益率分布直方图');
xlabel('收益率(%)');
ylabel('频率');
grid on;

% Basic statistics
stats_table = table();
stats_table.Statistic = {'Mean'; 'StdDev'; 'Skewness'; 'Kurtosis'; 'Min'; 'Max'; 'JBStatistic'; 'JBpValue'};
stats_table.Value = zeros(8, 1);  % Pre-allocate with 8 rows

stats_table.Value(1) = mean(returns);
stats_table.Value(2) = std(returns);
stats_table.Value(3) = skewness(returns);
stats_table.Value(4) = kurtosis(returns);
stats_table.Value(5) = min(returns);
stats_table.Value(6) = max(returns);

% Jarque-Bera normality test
[~, pJB, jbStat] = jbtest(returns);
stats_table.Value(7) = jbStat;  % JB statistic
stats_table.Value(8) = pJB;     % JB p-value

disp('收益率基本统计量:');
disp(stats_table);

%% 3. 平稳性检验 (ADF检验)
disp('========== 3. 平稳性检验 ==========');

% 使用Econometrics Toolbox的ADF检验
if license('test', 'econometrics_toolbox')
    [h_price, pValue_price] = adftest(price, 'model', 'TS');
    [h_ret, pValue_ret] = adftest(returns, 'model', 'TS');
    
    fprintf('价格序列ADF检验:\n');
    fprintf('  H0: 序列有单位根\n');
    fprintf('  p值: %.4f\n', pValue_price);
    fprintf('  结论: %s\n', ...
        ternary(h_price==0, '不拒绝H0（非平稳）', '拒绝H0（平稳）'));
    
    fprintf('\n收益率序列ADF检验:\n');
    fprintf('  p值: %.4f\n', pValue_ret);
    fprintf('  结论: %s\n', ...
        ternary(h_ret==0, '不拒绝H0（非平稳）', '拒绝H0（平稳）'));
else
    disp('未检测到Econometrics Toolbox，跳过ADF检验');
end

%% 4. 自相关性分析
disp('========== 4. 自相关性分析 ==========');

% 自相关函数(ACF) - 手动计算
subplot(3,3,4);
maxlag = 20;
acf = xcorr(returns - mean(returns), maxlag, 'coeff');
acf = acf(maxlag+1:end);
lags = 0:maxlag;
stem(lags, acf, 'filled');
hold on;
% 置信区间（假设白噪声）
conf = 1.96/sqrt(length(returns));
plot([0 maxlag], [conf conf], 'r--');
plot([0 maxlag], [-conf -conf], 'r--');
plot([0 maxlag], [0 0], 'k-');
xlabel('滞后阶数');
ylabel('自相关系数');
title('收益率ACF');
grid on;
xlim([0 maxlag]);

% 偏自相关函数(PACF) - 手动计算
subplot(3,3,5);
maxlag = 20;
pacf = zeros(maxlag+1, 1);
pacf(1) = 1;
for k = 1:maxlag
    [r, ~] = aryule(returns, k);
    pacf(k+1) = -r(k+1);
end
lags = 0:maxlag;
stem(lags, pacf, 'filled');
hold on;
conf = 1.96/sqrt(length(returns));
plot([0 maxlag], [conf conf], 'r--');
plot([0 maxlag], [-conf -conf], 'r--');
plot([0 maxlag], [0 0], 'k-');
xlabel('滞后阶数');
ylabel('偏自相关系数');
title('收益率PACF');
grid on;
xlim([0 maxlag]);

% Ljung-Box Q检验
[h_lb, p_lb] = lbqtest(returns, 'lags', [5, 10, 20]);
fprintf('Ljung-Box Q检验:\n');
fprintf(' 滞后5阶: p值=%.4f, %s\n', p_lb(1), ...
    ternary(p_lb(1)<0.05, '拒绝独立假设', '不拒绝独立假设'));
fprintf(' 滞后10阶: p值=%.4f, %s\n', p_lb(2), ...
    ternary(p_lb(2)<0.05, '拒绝独立假设', '不拒绝独立假设'));
fprintf(' 滞后20阶: p值=%.4f, %s\n', p_lb(3), ...
    ternary(p_lb(3)<0.05, '拒绝独立假设', '不拒绝独立假设'));

%% 5. 厚尾性检验
disp('========== 5. 厚尾性检验 ==========');

% 子图6: QQ图
subplot(3,3,6);
qqplot(returns);
title('收益率QQ图');
grid on;

% 与正态分布比较
x = linspace(min(returns), max(returns), 1000);
norm_pdf = normpdf(x, mean(returns), std(returns));

subplot(3,3,7);
histogram(returns, 50, 'Normalization', 'pdf', 'FaceAlpha', 0.6);
hold on;
plot(x, norm_pdf, 'r-', 'LineWidth', 2);
title('收益率分布 vs 正态分布');
xlabel('收益率(%)');
ylabel('概率密度');
legend('收益率分布', '正态分布', 'Location', 'best');
grid on;

% 计算超额峰度
excess_kurtosis = kurtosis(returns) - 3;
fprintf('超额峰度: %.4f\n', excess_kurtosis);
fprintf('结论: %s\n', ...
    ternary(excess_kurtosis > 0, '存在厚尾特征', '无明显厚尾特征'));

%% 6. GARCH模型估计
disp('========== 6. GARCH模型估计 ==========');

% 使用GARCH(1,1)模型
if license('test', 'econometrics_toolbox')
    try
        % 估计GARCH(1,1)模型
        Mdl = garch('GARCHLags', 1, 'ARCHLags', 1);
        EstMdl = estimate(Mdl, returns, 'Display', 'off');
        
        % 提取参数
        fprintf('GARCH(1,1)模型参数:\n');
        fprintf('  常数项(Omega): %.6f\n', EstMdl.Constant);
        fprintf('  GARCH项(Beta): %.6f\n', EstMdl.GARCH{1});
        fprintf('  ARCH项(Alpha): %.6f\n', EstMdl.ARCH{1});
        fprintf('  持久性(Alpha+Beta): %.6f\n', ...
            EstMdl.ARCH{1} + EstMdl.GARCH{1});
        
        % 提取标准化残差
        [residuals, condVar] = infer(EstMdl, returns);
        stdResiduals = returns ./ sqrt(condVar);
        
        % 子图8: 条件波动率
        subplot(3,3,8);
        plot(dates, sqrt(condVar), 'r-', 'LineWidth', 1.5);
        title('条件波动率(GARCH)');
        xlabel('日期');
        ylabel('波动率(%)');
        grid on;
        datetick('x', 'yyyy', 'keeplimits');
        
        % 子图9: 标准化残差
        subplot(3,3,9);
        plot(dates, stdResiduals, 'b-', 'LineWidth', 0.5);
        title('标准化残差');
        xlabel('日期');
        ylabel('标准化残差');
        grid on;
        datetick('x', 'yyyy', 'keeplimits');
        
    catch ME
        disp('GARCH模型估计失败:');
        disp(ME.message);
        stdResiduals = returns / std(returns);  % 使用简单标准化作为后备
    end
else
    disp('未检测到Econometrics Toolbox，使用简单标准化');
    stdResiduals = returns / std(returns);
end

%% 7. 阈值选取与GPD拟合
disp('========== 7. 阈值选取与GPD拟合 ==========');

% 使用极端值（负收益）进行尾部分析
neg_returns = -returns;  % 转换为损失序列
sorted_losses = sort(neg_returns, 'descend');

% 经验超出均值函数（MEF）法选择阈值
n = length(sorted_losses);
u_candidates = sorted_losses(1:floor(0.2*n));  % 考虑前20%的最大损失
nu = zeros(size(u_candidates));
mean_excess = zeros(size(u_candidates));

for i = 1:length(u_candidates)
    exceedances = sorted_losses(sorted_losses > u_candidates(i)) - u_candidates(i);
    nu(i) = length(exceedances);
    mean_excess(i) = mean(exceedances);
end

% 选择阈值（通常选择MEF大致线性区域的起点）
threshold_idx = find(mean_excess > 0, 1, 'last');
u = u_candidates(threshold_idx);
exceedances = sorted_losses(sorted_losses > u) - u;

fprintf('\n阈值选取结果:\n');
fprintf('  选择阈值u: %.4f%%\n', u);
fprintf('  超出数量: %d\n', length(exceedances));
fprintf('  超出比例: %.2f%%\n', length(exceedances)/n*100);

%% 8. GPD参数估计（极大似然估计）
disp('========== 8. GPD参数估计 ==========');

% 初始参数
xi0 = 0.1;  % 形状参数初值
beta0 = std(exceedances);  % 尺度参数初值
params0 = [xi0, beta0];

% 负对数似然函数
negloglik = @(params) -gpd_loglik(exceedances, params(1), params(2));

% 参数约束
lb = [-0.5, 1e-6];
ub = [0.5, 100];

% 优化
options = optimset('Display', 'off', 'MaxIter', 1000, 'MaxFunEvals', 3000);
[params_est, nll, ~] = fmincon(negloglik, params0, [], [], [], [], lb, ub, [], options);

xi_est = params_est(1);
beta_est = params_est(2);

fprintf('\nGPD参数估计结果:\n');
fprintf('  形状参数(xi): %.4f\n', xi_est);
fprintf('  尺度参数(beta): %.4f\n', beta_est);
fprintf('  负对数似然值: %.4f\n', nll);

%% 9. VaR和ES计算
disp('========== 9. VaR和ES计算 ==========');

% 置信水平
alpha = 0.95;  % 95%置信水平
p = 1 - alpha;  % 概率水平

% 分位数计算
VaR_empirical = quantile(returns, p);  % 经验VaR
VaR_normal = norminv(p, mean(returns), std(returns));  % 正态分布VaR

% GPD VaR
n_exceed = length(exceedances);
F_u = 1 - n_exceed / n;
VaR_gpd = u + (beta_est/xi_est) * (((n/n_exceed) * p)^(-xi_est) - 1);

% ES计算
ES_empirical = mean(returns(returns <= VaR_empirical));  % 经验ES
ES_normal = -mean(returns) + std(returns) * normpdf(norminv(p)) / p;  % 正态分布ES

% GPD ES
ES_gpd = (VaR_gpd + beta_est - xi_est * u) / (1 - xi_est);

fprintf('\n风险度量计算结果(%.0f%%置信水平):\n', alpha*100);
fprintf('  经验VaR: %.4f%%\n', VaR_empirical);
fprintf('  正态分布VaR: %.4f%%\n', VaR_normal);
fprintf('  GPD-VaR: %.4f%%\n', VaR_gpd);
fprintf('\n  经验ES: %.4f%%\n', ES_empirical);
fprintf('  正态分布ES: %.4f%%\n', ES_normal);
fprintf('  GPD-ES: %.4f%%\n', ES_gpd);

%% 10. 回测检验
disp('========== 10. 回测检验 ==========');

% 将数据分为训练集和测试集
train_ratio = 0.7;
n_train = floor(length(returns) * train_ratio);
train_returns = returns(1:n_train);
test_returns = returns(n_train+1:end);

% 训练集上计算VaR
train_VaR_empirical = quantile(train_returns, p);
train_VaR_normal = norminv(p, mean(train_returns), std(train_returns));

% 测试集上的例外数
exceptions_empirical = sum(test_returns < train_VaR_empirical);
exceptions_normal = sum(test_returns < train_VaR_normal);

% 计算失败率
n_test = length(test_returns);
failure_rate_empirical = exceptions_empirical / n_test;
failure_rate_normal = exceptions_normal / n_test;

% Kupiec回测
LR_empirical = 2*log(((1-p)^(n_test-exceptions_empirical) * p^exceptions_empirical) / ...
    ((1-failure_rate_empirical)^(n_test-exceptions_empirical) * failure_rate_empirical^exceptions_empirical));

LR_normal = 2*log(((1-p)^(n_test-exceptions_normal) * p^exceptions_normal) / ...
    ((1-failure_rate_normal)^(n_test-exceptions_normal) * failure_rate_normal^exceptions_normal));

fprintf('\n回测检验结果(测试集大小: %d):\n', n_test);
fprintf('  经验VaR回测:\n');
fprintf('    例外数: %d/%d\n', exceptions_empirical, n_test);
fprintf('    失败率: %.4f (理论: %.3f)\n', failure_rate_empirical, p);
fprintf('    Kupiec统计量: %.4f\n', LR_empirical);
fprintf('    结论: %s\n', ...
    ternary(abs(LR_empirical) < 3.841, '通过(5%显著性)', '未通过(5%显著性)'));

fprintf('\n  正态分布VaR回测:\n');
fprintf('    例外数: %d/%d\n', exceptions_normal, n_test);
fprintf('    失败率: %.4f (理论: %.3f)\n', failure_rate_normal, p);
fprintf('    Kupiec统计量: %.4f\n', LR_normal);
fprintf('    结论: %s\n', ...
    ternary(abs(LR_normal) < 3.841, '通过(5%显著性)', '未通过(5%显著性)'));

%% 11. 可视化结果汇总
figure('Position', [100, 100, 1400, 600]);

% 左图: 收益率与VaR
subplot(1,2,1);
plot(dates, returns, 'b-', 'LineWidth', 0.5);
hold on;
plot(dates, ones(size(dates)) * VaR_empirical, 'r--', 'LineWidth', 2);
plot(dates, ones(size(dates)) * VaR_normal, 'g--', 'LineWidth', 2);
plot(dates, ones(size(dates)) * VaR_gpd, 'm--', 'LineWidth', 2);
title('收益率序列与VaR比较');
xlabel('日期');
ylabel('收益率(%)');
legend('收益率', '经验VaR', '正态VaR', 'GPD-VaR', 'Location', 'best');
grid on;
datetick('x', 'yyyy', 'keeplimits');

% 右图: 风险度量比较
subplot(1,2,2);
risk_measures = [VaR_empirical, VaR_normal, ES_empirical; ...
                 VaR_gpd, ES_normal, ES_gpd];
bar(risk_measures);
set(gca, 'XTickLabel', {'VaR', 'ES'});
ylabel('风险值(%)');
title('不同方法风险度量比较');
legend('经验法', '正态分布', 'GPD', 'Location', 'best');
grid on;

%% 保存结果
results = struct();
results.returns = returns;
results.dates = dates;
results.basic_stats = stats_table;
results.VaR_results = table({'Empirical'; 'Normal'; 'GPD'}, ...
    [VaR_empirical; VaR_normal; VaR_gpd], ...
    [ES_empirical; ES_normal; ES_gpd], ...
    'VariableNames', {'Method', 'VaR', 'ES'});
results.GPD_params = struct('xi', xi_est, 'beta', beta_est, 'threshold', u);
results.backtest = struct('empirical', LR_empirical, 'normal', LR_normal);

save('bond_analysis_results.mat', 'results');
fprintf('\n分析完成！结果已保存到 bond_analysis_results.mat\n');

%% 辅助函数
function L = gpd_loglik(exceedances, xi, beta)
    % GPD对数似然函数
    n = length(exceedances);
    if xi == 0
        L = -n*log(beta) - sum(exceedances)/beta;
    else
        L = -n*log(beta) - (1/xi + 1)*sum(log(1 + xi*exceedances/beta));
    end
end

function result = ternary(condition, true_str, false_str)
    % 三元操作符模拟
    if condition
        result = true_str;
    else
        result = false_str;
    end
end