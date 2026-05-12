%% USD/CNY汇率GARCH分析 - 最终修复版
clear; clc; close all;

fprintf('=== USD/CNY汇率GARCH分析开始 ===\n\n');

data = readtable('data.xlsx'); 

%% 1. 检查数据
if ~exist('data', 'var')
    error('请先导入Excel数据到工作区。变量名应为"data"，包含"date"和"close"列。');
end

% 确保有正确的列
if ~ismember('date', data.Properties.VariableNames) || ~ismember('close', data.Properties.VariableNames)
    error('数据表需要包含"date"和"close"两列');
end

% 清理数据
data_clean = data;
data_clean(isnan(data_clean.close), :) = [];
data_clean = sortrows(data_clean, 'date');

% 转换为datetime
if ~isdatetime(data_clean.date)
    data_clean.date = datetime(data_clean.date, 'ConvertFrom', 'excel');
end

%% 2. 计算收益率
fprintf('数据期间: %s 到 %s\n', datestr(data_clean.date(1)), datestr(data_clean.date(end)));
fprintf('数据点数: %d\n', height(data_clean));

% 计算对数收益率
log_returns = diff(log(data_clean.close));
returns_dates = data_clean.date(2:end);

fprintf('平均日收益率: %.6f\n', mean(log_returns));
fprintf('收益率标准差: %.6f\n', std(log_returns));

%% 3. GARCH模型拟合
fprintf('\n=== GARCH模型拟合 ===\n');

try
    % 创建GARCH(1,1)模型
    mdl = garch(1, 1);
    est_mdl = estimate(mdl, log_returns, 'Display', 'off');
    fprintf('GARCH(1,1)模型创建成功！\n');
    
    % 显示模型参数
    fprintf('\n模型参数:\n');
    fprintf('常数项 (ω): %.6f\n', est_mdl.Constant);
    fprintf('ARCH系数 (α): %.6f\n', est_mdl.ARCH{1});
    fprintf('GARCH系数 (β): %.6f\n', est_mdl.GARCH{1});
    
    % 计算持久性
    persistence = est_mdl.ARCH{1} + est_mdl.GARCH{1};
    fprintf('持久性 (α+β): %.4f\n', persistence);
    if persistence >= 1
        fprintf('警告: 持久性>=1，模型可能不稳定\n');
    else
        fprintf('模型是稳定的\n');
    end
    
catch ME
    error('GARCH模型拟合失败: %s', ME.message);
end

%% 4. 计算条件方差和标准化残差
fprintf('\n=== 计算条件方差和残差 ===\n');
[cond_var, ~] = infer(est_mdl, log_returns);
std_residuals = log_returns ./ sqrt(cond_var);

fprintf('条件方差统计:\n');
fprintf('平均条件方差: %.6f\n', mean(cond_var));
fprintf('平均条件波动率: %.4f%%\n', mean(sqrt(cond_var))*100);
fprintf('今日条件波动率: %.4f%%\n', sqrt(cond_var(end))*100);

%% 5. 可视化 - 第一部分
figure('Position', [100, 100, 1200, 600], 'Name', 'USD/CNY GARCH分析 - 基础图表');

% 5.1 价格序列
subplot(2, 3, 1);
plot(data_clean.date, data_clean.close, 'b-', 'LineWidth', 1.5);
xlabel('日期'); ylabel('USD/CNY');
title('USD/CNY收盘价');
grid on;
datetick('x', 'yyyy-mm', 'keeplimits');

% 5.2 收益率序列
subplot(2, 3, 2);
plot(returns_dates, log_returns, 'b-', 'LineWidth', 0.8);
xlabel('日期'); ylabel('对数收益率');
title('日度对数收益率');
grid on;
datetick('x', 'yyyy-mm', 'keeplimits');

% 5.3 条件波动率
subplot(2, 3, 3);
plot(returns_dates, sqrt(cond_var)*100, 'r-', 'LineWidth', 1.5);
xlabel('日期'); ylabel('波动率 (%)');
title('GARCH条件波动率');
grid on;
datetick('x', 'yyyy-mm', 'keeplimits');

% 5.4 收益率与波动率带
subplot(2, 3, 4);
plot(returns_dates, log_returns, 'b-', 'LineWidth', 0.5);
hold on;
plot(returns_dates, sqrt(cond_var)*2, 'r-', 'LineWidth', 1);
plot(returns_dates, -sqrt(cond_var)*2, 'r-', 'LineWidth', 1);
xlabel('日期'); ylabel('收益率');
title('收益率与±2σ波动率带');
legend('收益率', '波动率带', 'Location', 'best');
grid on;
datetick('x', 'yyyy-mm', 'keeplimits');

% 5.5 标准化残差Q-Q图
subplot(2, 3, 5);
qqplot(std_residuals);
title('标准化残差Q-Q图');
grid on;

% 5.6 标准化残差分布
subplot(2, 3, 6);
histogram(std_residuals, 30, 'FaceColor', [0.2, 0.6, 0.4], 'EdgeColor', 'black');
hold on;
x = linspace(min(std_residuals), max(std_residuals), 100);
bin_width = (max(std_residuals) - min(std_residuals)) / 30;
y = normpdf(x, 0, 1) * length(std_residuals) * bin_width;
plot(x, y, 'r-', 'LineWidth', 2);
xlabel('标准化残差'); ylabel('频数');
title('标准化残差分布');
legend('标准化残差', '标准正态', 'Location', 'best');
grid on;

%% 6. 波动率预测
fprintf('\n=== 波动率预测 ===\n');
forecast_horizon = 30;

try
    % 方法1: 尝试单输出参数预测
    fprintf('尝试波动率预测...\n');
    v_forecast = forecast(est_mdl, forecast_horizon, 'Y0', log_returns);
    fprintf('预测成功！\n');
    
catch ME1
    fprintf('标准预测失败: %s\n', ME1.message);
    
    try
        % 方法2: 尝试不同的调用方式
        v_forecast = forecast(est_mdl, forecast_horizon, log_returns);
        fprintf('预测成功！\n');
        
    catch ME2
        fprintf('备选预测失败: %s\n', ME2.message);
        
        try
            % 方法3: 手动预测
            fprintf('使用手动方法预测...\n');
            
            % 提取模型参数
            omega = est_mdl.Constant;
            alpha = est_mdl.ARCH{1};
            beta = est_mdl.GARCH{1};
            
            % 获取最后一天的条件方差
            last_var = cond_var(end);
            
            % 手动计算预测
            v_forecast = zeros(forecast_horizon, 1);
            for i = 1:forecast_horizon
                if i == 1
                    v_forecast(i) = omega + alpha * (log_returns(end)^2) + beta * last_var;
                else
                    v_forecast(i) = omega + (alpha + beta) * v_forecast(i-1);
                end
            end
            
            fprintf('手动预测完成！\n');
            
        catch ME3
            fprintf('手动预测失败: %s\n', ME3.message);
            v_forecast = repmat(cond_var(end), forecast_horizon, 1);
            fprintf('使用最后一天的波动率作为预测\n');
        end
    end
end

% 绘制波动率预测
figure('Position', [100, 100, 800, 400], 'Name', '波动率预测');

% 选择最近100天的历史波动率
if length(cond_var) >= 100
    hist_dates = returns_dates(end-99:end);
    hist_vol = sqrt(cond_var(end-99:end))*100;
else
    hist_dates = returns_dates;
    hist_vol = sqrt(cond_var)*100;
end

% 创建预测日期
if isdatetime(hist_dates(end))
    forecast_dates = hist_dates(end) + (1:forecast_horizon)';
else
    forecast_dates = hist_dates(end) + (1:forecast_horizon)';
end

% 绘图
plot(hist_dates, hist_vol, 'b-', 'LineWidth', 1.5);
hold on;
plot(forecast_dates, sqrt(v_forecast)*100, 'r--', 'LineWidth', 2);
xlabel('日期'); ylabel('波动率 (%)');
title(sprintf('%d天波动率预测', forecast_horizon));
legend('历史波动率', '预测波动率', 'Location', 'best');
grid on;
datetick('x', 'mm-dd', 'keeplimits');

fprintf('\n波动率预测结果:\n');
fprintf('今日波动率: %.4f%%\n', sqrt(cond_var(end))*100);
fprintf('30天后预测波动率: %.4f%%\n', sqrt(v_forecast(end))*100);

%% 7. 模型诊断
fprintf('\n=== 模型诊断 ===\n');

% 7.1 标准化残差统计
fprintf('\n标准化残差统计:\n');
fprintf('均值: %.6f (期望: 0)\n', mean(std_residuals));
fprintf('标准差: %.6f (期望: 1)\n', std(std_residuals));
fprintf('偏度: %.4f (正态分布: 0)\n', skewness(std_residuals));
fprintf('峰度: %.4f (正态分布: 3)\n', kurtosis(std_residuals));

% 7.2 无条件波动率
try
    unconditional_var = est_mdl.Constant / (1 - est_mdl.ARCH{1} - est_mdl.GARCH{1});
    fprintf('\n无条件波动率:\n');
    fprintf('长期方差: %.6f\n', unconditional_var);
    fprintf('长期波动率: %.4f%%\n', sqrt(unconditional_var)*100);
catch
    fprintf('\n无条件波动率计算失败\n');
end

%% 8. VaR计算
fprintf('\n=== 风险价值(VaR)计算 ===\n');
current_price = data_clean.close(end);

% 计算不同置信水平的VaR
conf_levels = [0.95, 0.99];
for conf = conf_levels
    % 基于GARCH的VaR
    var_garch = -norminv(1-conf) * sqrt(cond_var(end));
    
    % 基于历史模拟的VaR
    sorted_resids = sort(std_residuals);
    idx = ceil((1-conf) * length(sorted_resids));
    if idx > 0 && idx <= length(sorted_resids)
        var_hist = -sorted_resids(idx) * sqrt(cond_var(end));
    else
        var_hist = NaN;
    end
    
    fprintf('\n置信度 %.1f%%:\n', conf*100);
    fprintf('  GARCH VaR: %.6f (%.4f%%)\n', var_garch, var_garch/current_price*100);
    if ~isnan(var_hist)
        fprintf('  历史VaR: %.6f (%.4f%%)\n', var_hist, var_hist/current_price*100);
    end
end

%% 9. 回测检验
fprintf('\n=== 回测检验 ===\n');

% 计算VaR违反次数
conf_level = 0.95;
var_level = -norminv(1-conf_level) * sqrt(cond_var);
violations = log_returns < -var_level;
violation_rate = sum(violations) / length(log_returns);

fprintf('95%% VaR回测结果:\n');
fprintf('  预期违反率: %.1f%%\n', (1-conf_level)*100);
fprintf('  实际违反率: %.2f%%\n', violation_rate*100);
fprintf('  违反次数: %d / %d\n', sum(violations), length(log_returns));

if abs(violation_rate - (1-conf_level)) < 0.01
    fprintf('  VaR模型表现良好\n');
else
    fprintf('  VaR模型可能需要调整\n');
end

%% 10. 保存结果
fprintf('\n=== 保存结果 ===\n');

% 创建结果结构
results = struct();
results.model = est_mdl;
results.log_returns = log_returns;
results.returns_dates = returns_dates;
results.cond_var = cond_var;
results.std_residuals = std_residuals;
results.v_forecast = v_forecast;
results.current_price = current_price;
results.violations = violations;
results.violation_rate = violation_rate;

% 保存到MAT文件
try
    save('garch_results_final.mat', 'results');
    fprintf('结果已保存到: garch_results_final.mat\n');
catch ME_save1
    fprintf('保存MAT文件失败: %s\n', ME_save1.message);
end

% 导出CSV
try
    result_table = table(returns_dates, log_returns, cond_var, std_residuals, ...
        'VariableNames', {'Date', 'LogReturn', 'ConditionalVariance', 'StandardizedResiduals'});
    writetable(result_table, 'garch_results_detailed.csv');
    fprintf('详细结果已导出到: garch_results_detailed.csv\n');
catch ME_save2
    fprintf('保存CSV文件失败: %s\n', ME_save2.message);
end

%% 11. 生成分析报告 - 修复字符串拼接问题
fprintf('\n');
fprintf('============================================================\n');
fprintf('USD/CNY汇率GARCH模型分析报告\n');
fprintf('============================================================\n\n');

fprintf('一、数据基本信息\n');
fprintf('  数据期间: %s 到 %s\n', datestr(data_clean.date(1)), datestr(data_clean.date(end)));
fprintf('  样本数量: %d 个交易日\n', length(log_returns));
fprintf('  当前汇率: %.4f\n\n', current_price);

fprintf('二、收益率统计\n');
fprintf('  平均收益率: %.6f\n', mean(log_returns));
fprintf('  收益率标准差: %.4f%%\n', std(log_returns)*100);
fprintf('  偏度: %.4f\n', skewness(log_returns));
fprintf('  峰度: %.4f\n\n', kurtosis(log_returns));

fprintf('三、GARCH(1,1)模型参数\n');
fprintf('  常数项 (ω): %.6f\n', est_mdl.Constant);
fprintf('  ARCH系数 (α): %.6f\n', est_mdl.ARCH{1});
fprintf('  GARCH系数 (β): %.6f\n', est_mdl.GARCH{1});
fprintf('  持久性 (α+β): %.4f\n', persistence);
try
    fprintf('  长期波动率: %.4f%%\n\n', sqrt(unconditional_var)*100);
catch
    fprintf('\n');
end

fprintf('四、风险度量\n');
fprintf('  当前条件波动率: %.4f%%\n', sqrt(cond_var(end))*100);
fprintf('  30天预测波动率: %.4f%%\n', sqrt(v_forecast(end))*100);

conf = 0.95;
var_garch = -norminv(1-conf) * sqrt(cond_var(end));
fprintf('  95%% VaR: %.6f (%.4f%%)\n\n', var_garch, var_garch/current_price*100);

fprintf('五、模型诊断\n');
fprintf('  标准化残差均值: %.4f\n', mean(std_residuals));
fprintf('  标准化残差标准差: %.4f\n', std(std_residuals));
fprintf('  VaR回测违反率: %.2f%%\n', violation_rate*100);

fprintf('============================================================\n');

%% 12. 额外分析：残差自相关检验
fprintf('\n=== 残差自相关检验 ===\n');

% 计算标准化残差的自相关
max_lag = 20;
if length(std_residuals) > max_lag
    acf_values = zeros(max_lag, 1);
    for lag = 1:max_lag
        if lag < length(std_residuals)
            acf = corrcoef(std_residuals(1:end-lag), std_residuals(lag+1:end));
            acf_values(lag) = acf(1,2);
        end
    end
    
    % 绘制自相关图
    figure('Position', [100, 100, 600, 400], 'Name', '标准化残差自相关');
    stem(1:max_lag, acf_values, 'b', 'filled', 'MarkerSize', 4);
    hold on;
    plot([1, max_lag], [0, 0], 'k-', 'LineWidth', 0.5);
    
    % 添加置信区间
    conf_bounds = 1.96/sqrt(length(std_residuals));
    plot([1, max_lag], [conf_bounds, conf_bounds], 'r--', 'LineWidth', 1);
    plot([1, max_lag], [-conf_bounds, -conf_bounds], 'r--', 'LineWidth', 1);
    
    xlabel('滞后阶数');
    ylabel('自相关系数');
    title('标准化残差自相关函数');
    xlim([0, max_lag+1]);
    grid on;
    hold off;
    
    % 检查是否存在显著的自相关
    significant_lags = find(abs(acf_values) > conf_bounds);
    if isempty(significant_lags)
        fprintf('标准化残差无显著自相关，模型设定合理\n');
    else
        fprintf('警告: 在滞后阶数 %s 处发现显著自相关\n', num2str(significant_lags'));
    end
end

%% 13. 创建汇总表格
fprintf('\n=== 关键指标汇总 ===\n');

% 创建汇总表格
summary_table = table();

% 使用英文变量名
summary_table.Metric = {
    '样本数量';
    '平均收益率';
    '收益率标准差_percent';
    '偏度';
    '峰度';
    'GARCH常数';
    'ARCH系数';
    'GARCH系数';
    '持久性';
    '当前波动率_percent';
    '预测波动率_percent';
    'VaR_95_percent';
    'VaR违反率_percent'
    };

summary_table.Value = [
    length(log_returns);
    mean(log_returns);
    std(log_returns)*100;
    skewness(log_returns);
    kurtosis(log_returns);
    est_mdl.Constant;
    est_mdl.ARCH{1};
    est_mdl.GARCH{1};
    persistence;
    sqrt(cond_var(end))*100;
    sqrt(v_forecast(end))*100;
    var_garch/current_price*100;
    violation_rate*100
    ];

% 显示表格
disp(summary_table);

% 添加解释说明
fprintf('\n注：单位说明\n');
fprintf('  *_percent 表示百分比单位\n');
fprintf('  VaR_95_percent: 95%%置信水平的风险价值\n');

% 保存表格
try
    writetable(summary_table, 'garch_summary_table.csv');
    fprintf('\n关键指标已保存到: garch_summary_table.csv\n');
catch ME
    fprintf('\n无法保存汇总表格: %s\n', ME.message);
end
%% 14. 生成最终报告文件
try
    fid = fopen('garch_analysis_report.txt', 'w');
    
    % 写入报告头部
    fprintf(fid, 'USD/CNY汇率GARCH模型分析报告\n');
    fprintf(fid, '生成时间: %s\n\n', datestr(now));
    
    % 写入数据信息
    fprintf(fid, '1. 数据信息\n');
    fprintf(fid, '   数据期间: %s 到 %s\n', datestr(data_clean.date(1)), datestr(data_clean.date(end)));
    fprintf(fid, '   样本数量: %d 个交易日\n', length(log_returns));
    fprintf(fid, '   当前汇率: %.4f\n\n', current_price);
    
    % 写入收益率统计
    fprintf(fid, '2. 收益率统计\n');
    fprintf(fid, '   平均收益率: %.6f\n', mean(log_returns));
    fprintf(fid, '   收益率标准差: %.4f%%\n', std(log_returns)*100);
    fprintf(fid, '   偏度: %.4f\n', skewness(log_returns));
    fprintf(fid, '   峰度: %.4f\n\n', kurtosis(log_returns));
    
    % 写入GARCH模型
    fprintf(fid, '3. GARCH(1,1)模型参数\n');
    fprintf(fid, '   常数项 (ω): %.6f\n', est_mdl.Constant);
    fprintf(fid, '   ARCH系数 (α): %.6f\n', est_mdl.ARCH{1});
    fprintf(fid, '   GARCH系数 (β): %.6f\n', est_mdl.GARCH{1});
    fprintf(fid, '   持久性 (α+β): %.4f\n', persistence);
    
    try
        fprintf(fid, '   长期波动率: %.4f%%\n\n', sqrt(unconditional_var)*100);
    catch
        fprintf(fid, '\n');
    end
    
    % 写入风险度量
    fprintf(fid, '4. 风险度量\n');
    fprintf(fid, '   当前条件波动率: %.4f%%\n', sqrt(cond_var(end))*100);
    fprintf(fid, '   30天预测波动率: %.4f%%\n', sqrt(v_forecast(end))*100);
    fprintf(fid, '   95%% VaR: %.4f%%\n\n', var_garch/current_price*100);
    
    % 写入模型诊断
    fprintf(fid, '5. 模型诊断\n');
    fprintf(fid, '   标准化残差均值: %.4f\n', mean(std_residuals));
    fprintf(fid, '   标准化残差标准差: %.4f\n', std(std_residuals));
    fprintf(fid, '   VaR回测违反率: %.2f%%\n', violation_rate*100);
    
    fclose(fid);
    fprintf('\n分析报告已保存到: garch_analysis_report.txt\n');
    
catch ME_report
    fprintf('生成报告文件失败: %s\n', ME_report.message);
end

fprintf('\n=== 分析完成 ===\n');
fprintf('所有结果已保存到当前工作目录\n');

%% EVT分析：阈值选取与GPD拟合
fprintf('\n=== EVT极值理论分析 ===\n');

% 1.1 提取标准化残差的负尾（损失端）
negative_residuals = -std_residuals;  % 转为正数表示损失
sorted_neg_res = sort(negative_residuals, 'descend');

% 1.2 阈值选择（示例：使用90%分位数）
threshold_quantile = 0.90;
threshold = quantile(sorted_neg_res, threshold_quantile);
fprintf('阈值选择: %.2f分位数\n', threshold_quantile);
fprintf('阈值: %.4f\n', threshold);

% 1.3 超出阈值的数据
exceedances = sorted_neg_res(sorted_neg_res > threshold) - threshold;
num_exceed = length(exceedances);
fprintf('超出阈值的样本数: %d (%.2f%%)\n', num_exceed, num_exceed/length(sorted_neg_res)*100);

% 1.4 GPD参数估计（矩估计法）
if num_exceed > 10
    mean_exceed = mean(exceedances);
    var_exceed = var(exceedances);
    
    % 形状参数ξ和尺度参数β
    xi = 0.5 * (mean_exceed^2 / var_exceed - 1);
    beta = 0.5 * mean_exceed * (mean_exceed^2 / var_exceed + 1);
    
    fprintf('\nGPD参数估计:\n');
    fprintf('  形状参数ξ: %.4f\n', xi);
    fprintf('  尺度参数β: %.4f\n', beta);
    
    if xi >= 0
        fprintf('  分布类型: 厚尾分布\n');
    else
        fprintf('  分布类型: 薄尾分布\n');
    end
end

%% 基于EVT的VaR和ES计算
fprintf('\n=== 基于EVT的风险度量 ===\n');

% 2.1 计算基于GPD的VaR
confidence_levels = [0.95, 0.99, 0.995];
current_vol = sqrt(cond_var(end));

for conf = confidence_levels
    % 传统正态VaR
    var_normal = -norminv(1-conf) * current_vol;
    
    % 基于GPD的VaR
    if num_exceed > 10
        % 超出概率
        p_exceed = (1-conf) * (length(sorted_neg_res)/num_exceed);
        
        % GPD VaR公式
        if xi ~= 0
            var_evt = threshold + (beta/xi) * ((p_exceed/num_exceed*length(sorted_neg_res))^(-xi) - 1);
        else
            var_evt = threshold - beta * log(p_exceed/num_exceed*length(sorted_neg_res));
        end
        var_evt = var_evt * current_vol;  % 转换为原始尺度
        
        fprintf('\n置信度 %.1f%%:\n', conf*100);
        fprintf('  正态VaR: %.6f (%.4f%%)\n', var_normal, var_normal/current_price*100);
        fprintf('  EVT-VaR: %.6f (%.4f%%)\n', var_evt, var_evt/current_price*100);
    end
end

% 2.2 计算ES（Expected Shortfall）
fprintf('\n=== 预期短缺(ES)计算 ===\n');
conf = 0.99;
if num_exceed > 10 && xi < 1
    % 传统正态ES
    es_normal = normpdf(norminv(conf)) / (1-conf) * current_vol;
    
    % 基于GPD的ES
    var_evt_val = var_evt;  % 使用上面计算的VaR
    es_evt = var_evt_val / (1-xi) + (beta - xi*threshold) / (1-xi);
    es_evt = es_evt * current_vol;
    
    fprintf('置信度 99%%:\n');
    fprintf('  正态ES: %.6f (%.4f%%)\n', es_normal, es_normal/current_price*100);
    fprintf('  EVT-ES: %.6f (%.4f%%)\n', es_evt, es_evt/current_price*100);
end

%% 完整的回测检验
fprintf('\n=== 完整的回测检验 ===\n');

% 3.1 Kupiec检验（无条件覆盖检验）
function [LR_uc, p_value_uc] = kupiec_test(violations, conf_level)
    n = length(violations);
    x = sum(violations);
    p_hat = x / n;
    p = 1 - conf_level;
    
    if p_hat == 0
        LR_uc = 0;
    else
        LR_uc = -2 * log(((1-p)^(n-x) * p^x) / ((1-p_hat)^(n-x) * p_hat^x));
    end
    p_value_uc = 1 - chi2cdf(LR_uc, 1);
end

% 3.2 Christoffersen检验（独立性与条件覆盖检验）
function [LR_ind, LR_cc, p_value_ind, p_value_cc] = christoffersen_test(violations, conf_level)
    n = length(violations);
    
    % 转移矩阵
    n00 = 0; n01 = 0; n10 = 0; n11 = 0;
    for i = 2:n
        if violations(i-1) == 0 && violations(i) == 0
            n00 = n00 + 1;
        elseif violations(i-1) == 0 && violations(i) == 1
            n01 = n01 + 1;
        elseif violations(i-1) == 1 && violations(i) == 0
            n10 = n10 + 1;
        else
            n11 = n11 + 1;
        end
    end
    
    % 独立性检验
    pi0 = n01 / (n00 + n01);
    pi1 = n11 / (n10 + n11);
    pi = (n01 + n11) / (n00 + n01 + n10 + n11);
    
    L0 = (1-pi)^(n00+n10) * pi^(n01+n11);
    L1 = (1-pi0)^n00 * pi0^n01 * (1-pi1)^n10 * pi1^n11;
    
    LR_ind = -2 * log(L0 / L1);
    p_value_ind = 1 - chi2cdf(LR_ind, 1);
    
    % 条件覆盖检验
    p = 1 - conf_level;
    L_cc = (1-p)^(n00+n10) * p^(n01+n11);
    LR_cc = -2 * log(L_cc / L1);
    p_value_cc = 1 - chi2cdf(LR_cc, 2);
end

% 执行回测检验
fprintf('回测检验结果:\n');
[LR_uc, p_uc] = kupiec_test(violations, 0.95);
fprintf('Kupiec检验（无条件覆盖）:\n');
fprintf('  LR统计量: %.4f, p值: %.4f\n', LR_uc, p_uc);
if p_uc > 0.05
    fprintf('  结论: 无法拒绝原假设，VaR模型有效\n');
else
    fprintf('  结论: 拒绝原假设，VaR模型无效\n');
end

[LR_ind, LR_cc, p_ind, p_cc] = christoffersen_test(violations, 0.95);
fprintf('\nChristoffersen检验:\n');
fprintf('  独立性检验: LR=%.4f, p=%.4f\n', LR_ind, p_ind);
fprintf('  条件覆盖检验: LR=%.4f, p=%.4f\n', LR_cc, p_cc);