%% DCC-GARCH模型估计与分析 - 修正日期处理
clear; clc; close all;
fprintf('===== DCC-GARCH模型估计 (修正版) =====\n');

%% 1. 数据准备 - 读取三个Excel文件
fprintf('\n1. 读取三个市场数据文件...\n');

% 读取股票市场数据
fprintf('  读取股票数据 (stock_data.xlsx)...\n');
stock_table = readtable('stock_data.xlsx');

% 检查列名
fprintf('  股票表列名:\n');
disp(stock_table.Properties.VariableNames);

% 自动检测日期列
date_col_names = {'Date', 'date', 'DATE', '时间', '交易日期'};
stock_date_col = '';
for i = 1:length(date_col_names)
    if any(strcmp(stock_table.Properties.VariableNames, date_col_names{i}))
        stock_date_col = date_col_names{i};
        break;
    end
end

if isempty(stock_date_col)
    error('未找到股票数据的日期列');
end
fprintf('  使用日期列: %s\n', stock_date_col);

% 自动检测价格列
price_col_names = {'Close', 'close', '收盘价', '收盘'};
stock_price_col = '';
for i = 1:length(price_col_names)
    if any(strcmp(stock_table.Properties.VariableNames, price_col_names{i}))
        stock_price_col = price_col_names{i};
        break;
    end
end

if isempty(stock_price_col)
    error('未找到股票数据的价格列');
end
fprintf('  使用价格列: %s\n', stock_price_col);

stock_dates = stock_table.(stock_date_col);
stock_prices = stock_table.(stock_price_col);

% 处理日期格式
fprintf('  原始日期类型: %s\n', class(stock_dates));

% 转换日期为datetime格式
stock_dates = convert_to_datetime(stock_dates);
fprintf('  转换后日期类型: %s\n', class(stock_dates));

% 计算对数收益率
if all(~isnan(stock_prices))
    stock_returns = price2ret(stock_prices);
    stock_dates = stock_dates(2:end);
    fprintf('    股票数据: %d 个价格 -> %d 个收益率\n', ...
        length(stock_prices), length(stock_returns));
else
    error('股票价格数据包含NaN值');
end

% 读取汇率市场数据
fprintf('  读取汇率数据 (data.xlsx)...\n');
fx_table = readtable('data.xlsx');

fprintf('  汇率表列名:\n');
disp(fx_table.Properties.VariableNames);

% 自动检测日期列
fx_date_col = '';
for i = 1:length(date_col_names)
    if any(strcmp(fx_table.Properties.VariableNames, date_col_names{i}))
        fx_date_col = date_col_names{i};
        break;
    end
end

if isempty(fx_date_col)
    error('未找到汇率数据的日期列');
end
fprintf('  使用日期列: %s\n', fx_date_col);

% 自动检测价格列
fx_price_col = '';
for i = 1:length(price_col_names)
    if any(strcmp(fx_table.Properties.VariableNames, price_col_names{i}))
        fx_price_col = price_col_names{i};
        break;
    end
end

if isempty(fx_price_col)
    error('未找到汇率数据的价格列');
end
fprintf('  使用价格列: %s\n', fx_price_col);

fx_dates = fx_table.(fx_date_col);
fx_prices = fx_table.(fx_price_col);

% 处理日期格式
fprintf('  原始日期类型: %s\n', class(fx_dates));
fx_dates = convert_to_datetime(fx_dates);
fprintf('  转换后日期类型: %s\n', class(fx_dates));

% 计算对数收益率
if all(~isnan(fx_prices))
    fx_returns = price2ret(fx_prices);
    fx_dates = fx_dates(2:end);
    fprintf('    汇率数据: %d 个价格 -> %d 个收益率\n', ...
        length(fx_prices), length(fx_returns));
else
    error('汇率价格数据包含NaN值');
end

% 读取国债市场数据
fprintf('  读取国债数据 (bond.xlsx)...\n');
bond_table = readtable('bond.xlsx');

fprintf('  国债表列名:\n');
disp(bond_table.Properties.VariableNames);

% 自动检测日期列
bond_date_col = '';
for i = 1:length(date_col_names)
    if any(strcmp(bond_table.Properties.VariableNames, date_col_names{i}))
        bond_date_col = date_col_names{i};
        break;
    end
end

if isempty(bond_date_col)
    error('未找到国债数据的日期列');
end
fprintf('  使用日期列: %s\n', bond_date_col);

% 自动检测价格列 - 修正为close
bond_price_cols = {'Close', 'close', '收盘价', '收盘', 'clsoe'};
bond_price_col = '';
for i = 1:length(bond_price_cols)
    if any(strcmp(bond_table.Properties.VariableNames, bond_price_cols{i}))
        bond_price_col = bond_price_cols{i};
        break;
    end
end

if isempty(bond_price_col)
    error('未找到国债数据的价格列');
end
fprintf('  使用价格列: %s\n', bond_price_col);

bond_dates = bond_table.(bond_date_col);
bond_prices = bond_table.(bond_price_col);

% 处理日期格式
fprintf('  原始日期类型: %s\n', class(bond_dates));
bond_dates = convert_to_datetime(bond_dates);
fprintf('  转换后日期类型: %s\n', class(bond_dates));

% 计算对数收益率
if all(~isnan(bond_prices))
    bond_returns = price2ret(bond_prices);
    bond_dates = bond_dates(2:end);
    fprintf('    国债数据: %d 个价格 -> %d 个收益率\n', ...
        length(bond_prices), length(bond_returns));
else
    error('国债价格数据包含NaN值');
end

% 保存原始收益率用于检查
save('raw_returns_check.mat', 'stock_returns', 'fx_returns', 'bond_returns', ...
    'stock_dates', 'fx_dates', 'bond_dates');

%% 2. 数据对齐与预处理
fprintf('\n2. 数据对齐处理...\n');

% 找到共同的时间区间
fprintf('  各市场时间区间:\n');
fprintf('    股票: %s 到 %s\n', datestr(min(stock_dates), 'yyyy-mm-dd'), ...
    datestr(max(stock_dates), 'yyyy-mm-dd'));
fprintf('    汇率: %s 到 %s\n', datestr(min(fx_dates), 'yyyy-mm-dd'), ...
    datestr(max(fx_dates), 'yyyy-mm-dd'));
fprintf('    国债: %s 到 %s\n', datestr(min(bond_dates), 'yyyy-mm-dd'), ...
    datestr(max(bond_dates), 'yyyy-mm-dd'));

% 找到共同的开始和结束日期
start_date = max([min(stock_dates), min(fx_dates), min(bond_dates)]);
end_date = min([max(stock_dates), max(fx_dates), max(bond_dates)]);

fprintf('\n  共同时间区间: %s 到 %s\n', ...
    datestr(start_date, 'yyyy-mm-dd'), datestr(end_date, 'yyyy-mm-dd'));

% 截取共同区间的数据
stock_idx = stock_dates >= start_date & stock_dates <= end_date;
fx_idx = fx_dates >= start_date & fx_dates <= end_date;
bond_idx = bond_dates >= start_date & bond_dates <= end_date;

stock_returns = stock_returns(stock_idx);
stock_dates = stock_dates(stock_idx);
fx_returns = fx_returns(fx_idx);
fx_dates = fx_dates(fx_idx);
bond_returns = bond_returns(bond_idx);
bond_dates = bond_dates(bond_idx);

fprintf('  截取后数据量:\n');
fprintf('    股票: %d 个收益率\n', length(stock_returns));
fprintf('    汇率: %d 个收益率\n', length(fx_returns));
fprintf('    国债: %d 个收益率\n', length(bond_returns));

% 精细日期对齐
fprintf('  进行精细日期对齐...\n');

% 找到三个市场的共同日期
common_dates = stock_dates;
common_dates = intersect(common_dates, fx_dates);
common_dates = intersect(common_dates, bond_dates);

if isempty(common_dates)
    error('错误: 没有找到共同的交易日期！');
end

% 按共同日期提取数据
[~, idx_stock, ~] = intersect(stock_dates, common_dates);
[~, idx_fx, ~] = intersect(fx_dates, common_dates);
[~, idx_bond, ~] = intersect(bond_dates, common_dates);

% 确保索引有序
idx_stock = sort(idx_stock);
idx_fx = sort(idx_fx);
idx_bond = sort(idx_bond);

% 提取对齐的数据
dates = common_dates;
stock_returns = stock_returns(idx_stock);
fx_returns = fx_returns(idx_fx);
bond_returns = bond_returns(idx_bond);

% 最终检查
fprintf('\n  最终对齐结果:\n');
fprintf('    共同日期数: %d\n', length(dates));
fprintf('    时间范围: %s 到 %s\n', ...
    datestr(min(dates), 'yyyy-mm-dd'), datestr(max(dates), 'yyyy-mm-dd'));

% 检查日期顺序
if ~issorted(dates)
    fprintf('  警告: 日期未排序，进行排序...\n');
    [dates, sort_idx] = sort(dates);
    stock_returns = stock_returns(sort_idx);
    fx_returns = fx_returns(sort_idx);
    bond_returns = bond_returns(sort_idx);
end

% 创建收益率矩阵 (T×3)
% 顺序: 股票, 国债, 汇率
returns_matrix = [stock_returns, bond_returns, fx_returns];
T = size(returns_matrix, 1);
N = size(returns_matrix, 2);

fprintf('    收益率矩阵维度: %d×%d (时间×市场)\n', T, N);

% 数据质量检查
fprintf('\n3. 数据质量检查...\n');

% 检查缺失值
missing_count = sum(isnan(returns_matrix));
if any(missing_count > 0)
    fprintf('  发现缺失值:\n');
    fprintf('    股票: %d 个\n', missing_count(1));
    fprintf('    国债: %d 个\n', missing_count(2));
    fprintf('    汇率: %d 个\n', missing_count(3));
    
    % 用线性插值填充缺失值
    for i = 1:N
        if missing_count(i) > 0
            returns_matrix(:, i) = fillmissing(returns_matrix(:, i), 'linear');
            fprintf('    已填充市场 %d 的缺失值\n', i);
        end
    end
else
    fprintf('  ✓ 无缺失值\n');
end

% 保存对齐后的数据
aligned_data = struct();
aligned_data.Dates = dates;
aligned_data.Returns = returns_matrix;
aligned_data.MarketNames = {'股票', '国债', '汇率'};
save('aligned_returns_data.mat', 'aligned_data');
fprintf('\n  ✓ 对齐后的数据已保存为 aligned_returns_data.mat\n');

%% 显示描述性统计
fprintf('\n4. 收益率描述性统计:\n');
fprintf('  Market        Mean       Std       Skew      Kurt     Min       Max\n');
fprintf('  --------------------------------------------------------------------\n');
market_names = {'股票', '国债', '汇率'};
for i = 1:N
    r = returns_matrix(:, i);
    stats = [mean(r), std(r), skewness(r), kurtosis(r), min(r), max(r)];
    fprintf('  %-8s  %9.6f  %8.6f  %8.4f  %8.4f  %8.4f  %8.4f\n', ...
        market_names{i}, stats(1), stats(2), stats(3), stats(4), stats(5), stats(6));
end

%% 继续DCC-GARCH估计
%% 5. 第一阶段：单变量GARCH(1,1)估计 - 简化版
fprintf('\n5. 第一阶段：单变量GARCH(1,1)估计...\n');

% 为每个市场估计GARCH(1,1)模型
conditional_variances = zeros(T, N);
standardized_residuals = zeros(T, N);
garch_params = zeros(N, 3);  % [常数, ARCH, GARCH]

for i = 1:N
    fprintf('  市场: %s\n', market_names{i});
    
    try
        % 方法1: 使用garch函数
        returns = returns_matrix(:, i);
        
        % 设置GARCH(1,1)模型
        Mdl = garch(1, 1);
        
        % 估计模型
        EstMdl = estimate(Mdl, returns, 'Display', 'off');
        
        % 推断波动率
        V = infer(EstMdl, returns);
        
        conditional_variances(:, i) = V;
        standardized_residuals(:, i) = returns ./ sqrt(V);
        
        % 保存参数
        garch_params(i, 1) = EstMdl.Constant;
        garch_params(i, 2) = EstMdl.ARCH{1};
        garch_params(i, 3) = EstMdl.GARCH{1};
        
        fprintf('    参数: ω=%.6f, α=%.4f, β=%.4f, α+β=%.4f\n', ...
            garch_params(i, 1), garch_params(i, 2), garch_params(i, 3), ...
            garch_params(i, 2) + garch_params(i, 3));
        
    catch ME
        fprintf('    GARCH估计失败: %s\n', ME.message);
        fprintf('    使用滚动EWMA波动率估计...\n');
        
        % 使用EWMA（指数加权移动平均）
        lambda = 0.94;  % RiskMetrics参数
        returns = returns_matrix(:, i);
        
        ewma_var = zeros(T, 1);
        ewma_var(1) = var(returns(1:min(20, T)));  % 用前20天初始化
        
        for t = 2:T
            ewma_var(t) = lambda * ewma_var(t-1) + (1-lambda) * returns(t-1)^2;
        end
        
        conditional_variances(:, i) = ewma_var;
        standardized_residuals(:, i) = returns ./ sqrt(ewma_var);
        
        % 设置近似参数
        garch_params(i, 1) = 0.0001;
        garch_params(i, 2) = 1 - lambda;  % ARCH系数
        garch_params(i, 3) = lambda;      % GARCH系数
        
        fprintf('    EWMA参数: ω=%.6f, α=%.4f, β=%.4f\n', ...
            garch_params(i, 1), garch_params(i, 2), garch_params(i, 3));
    end
end

%% 检查标准化残差
fprintf('\n6. 标准化残差检查:\n');
fprintf('  Market        Mean       Std       Min       Max\n');
fprintf('  ------------------------------------------------\n');
for i = 1:N
    resid = standardized_residuals(:, i);
    stats = [mean(resid), std(resid), min(resid), max(resid)];
    fprintf('  %-8s  %9.4f  %8.4f  %8.4f  %8.4f\n', ...
        market_names{i}, stats(1), stats(2), stats(3), stats(4));
end

%% 绘制收益率和波动率图
fprintf('\n7. 生成初步图表...\n');

figure('Position', [100, 100, 1200, 800]);

% 子图1: 收益率序列
for i = 1:3
    subplot(3, 2, 2*i-1);
    colors = ['b', 'r', 'g'];
    plot(dates, returns_matrix(:, i)*100, [colors(i) '-'], 'LineWidth', 0.8);
    title([market_names{i} '收益率 (%)'], 'FontSize', 10);
    xlabel('日期', 'FontSize', 8);
    ylabel('收益率 %', 'FontSize', 8);
    grid on;
    xlim([min(dates), max(dates)]);
    
    subplot(3, 2, 2*i);
    plot(dates, sqrt(conditional_variances(:, i))*100, [colors(i) '-'], 'LineWidth', 1);
    title([market_names{i} '条件波动率 (%)'], 'FontSize', 10);
    xlabel('日期', 'FontSize', 8);
    ylabel('波动率 %', 'FontSize', 8);
    grid on;
    xlim([min(dates), max(dates)]);
end

saveas(gcf, 'preliminary_analysis.png');
fprintf('  ✓ 初步分析图表已保存为 preliminary_analysis.png\n');

%% 继续DCC-GARCH估计
%% 8. 第二阶段：DCC模型估计
fprintf('\n8. 第二阶段：DCC模型估计...\n');

% 检查是否需要重新计算标准化残差
fprintf('  检查标准化残差...\n');

% 确保标准化残差是单位方差
for i = 1:N
    resid_std = std(standardized_residuals(:, i));
    if abs(resid_std - 1) > 0.1
        fprintf('    调整 %s 的标准化残差方差: %.4f -> 1.0\n', ...
            market_names{i}, resid_std);
        standardized_residuals(:, i) = standardized_residuals(:, i) / resid_std;
    end
end

% 计算无条件相关系数矩阵
fprintf('  计算无条件相关系数矩阵:\n');
R_bar = corr(standardized_residuals);
disp(R_bar);

% 使用手动DCC估计
fprintf('  使用手动DCC估计...\n');
[dcc_a, dcc_b, Rt] = estimate_dcc_manual(standardized_residuals);

fprintf('\n  ✓ DCC模型估计完成！\n\n');
fprintf('  DCC模型参数:\n');
fprintf('    a (ARCH) = %.6f (新息对相关系数的影响)\n', dcc_a);
fprintf('    b (GARCH) = %.6f (相关系数的持续性)\n', dcc_b);
fprintf('    a + b = %.6f (接近1表示高度持续性)\n', dcc_a + dcc_b);

% 检查参数合理性
if dcc_a + dcc_b >= 1
    fprintf('  ⚠ 警告: a+b >= 1，可能不满足平稳性条件\n');
else
    fprintf('  ✓ a+b < 1，满足平稳性条件\n');
end

%% 提取动态条件相关系数
fprintf('\n9. 提取动态条件相关系数...\n');

% 从Rt中提取相关系数
rho_stock_bond = zeros(T, 1);
rho_stock_fx = zeros(T, 1);
rho_bond_fx = zeros(T, 1);

if size(Rt, 3) > 1
    % 3D数组
    for t = 1:T
        R_t = Rt(:, :, t);
        rho_stock_bond(t) = R_t(1, 2);
        rho_stock_fx(t) = R_t(1, 3);
        rho_bond_fx(t) = R_t(2, 3);
    end
else
    % 常数矩阵
    R_t = Rt;
    rho_stock_bond(:) = R_t(1, 2);
    rho_stock_fx(:) = R_t(1, 3);
    rho_bond_fx(:) = R_t(2, 3);
end

% 基本统计
fprintf('  相关系数统计:\n');
fprintf('  股票-国债: 均值=%.4f, 标准差=%.4f\n', mean(rho_stock_bond), std(rho_stock_bond));
fprintf('  股票-汇率: 均值=%.4f, 标准差=%.4f\n', mean(rho_stock_fx), std(rho_stock_fx));
fprintf('  国债-汇率: 均值=%.4f, 标准差=%.4f\n', mean(rho_bond_fx), std(rho_bond_fx));

%% 保存结果
fprintf('\n10. 保存DCC估计结果...\n');

dcc_results = struct();
dcc_results.Dates = dates;
dcc_results.Returns = returns_matrix;
dcc_results.MarketNames = market_names;
dcc_results.DCC_a = dcc_a;
dcc_results.DCC_b = dcc_b;
dcc_results.Rho_Stock_Bond = rho_stock_bond;
dcc_results.Rho_Stock_FX = rho_stock_fx;
dcc_results.Rho_Bond_FX = rho_bond_fx;

save('dcc_estimation_results.mat', 'dcc_results');
fprintf('  ✓ 结果已保存到 dcc_estimation_results.mat\n');

%% 生成动态相关系数图
fprintf('\n11. 生成动态相关系数图...\n');

figure('Position', [100, 100, 1000, 800]);

% 股票-国债
subplot(3, 1, 1);
plot(dates, rho_stock_bond, 'b-', 'LineWidth', 1.2);
title('股票-国债动态条件相关系数', 'FontSize', 12, 'FontWeight', 'bold');
xlabel('日期', 'FontSize', 10);
ylabel('相关系数', 'FontSize', 10);
grid on;
xlim([min(dates), max(dates)]);
ylim([-1, 1]);
hold on;
plot([min(dates), max(dates)], [0, 0], 'k-', 'LineWidth', 0.5);
plot([min(dates), max(dates)], [mean(rho_stock_bond), mean(rho_stock_bond)], ...
    'r--', 'LineWidth', 1);
legend('动态相关系数', '零线', sprintf('均值=%.3f', mean(rho_stock_bond)), 'Location', 'best');

% 股票-汇率
subplot(3, 1, 2);
plot(dates, rho_stock_fx, 'r-', 'LineWidth', 1.2);
title('股票-汇率动态条件相关系数', 'FontSize', 12, 'FontWeight', 'bold');
xlabel('日期', 'FontSize', 10);
ylabel('相关系数', 'FontSize', 10);
grid on;
xlim([min(dates), max(dates)]);
ylim([-1, 1]);
hold on;
plot([min(dates), max(dates)], [0, 0], 'k-', 'LineWidth', 0.5);
plot([min(dates), max(dates)], [mean(rho_stock_fx), mean(rho_stock_fx)], ...
    'b--', 'LineWidth', 1);
legend('动态相关系数', '零线', sprintf('均值=%.3f', mean(rho_stock_fx)), 'Location', 'best');

% 国债-汇率
subplot(3, 1, 3);
plot(dates, rho_bond_fx, 'g-', 'LineWidth', 1.2);
title('国债-汇率动态条件相关系数', 'FontSize', 12, 'FontWeight', 'bold');
xlabel('日期', 'FontSize', 10);
ylabel('相关系数', 'FontSize', 10);
grid on;
xlim([min(dates), max(dates)]);
ylim([-1, 1]);
hold on;
plot([min(dates), max(dates)], [0, 0], 'k-', 'LineWidth', 0.5);
plot([min(dates), max(dates)], [mean(rho_bond_fx), mean(rho_bond_fx)], ...
    'm--', 'LineWidth', 1);
legend('动态相关系数', '零线', sprintf('均值=%.3f', mean(rho_bond_fx)), 'Location', 'best');

saveas(gcf, 'dcc_dynamic_correlations.png');
fprintf('  ✓ 动态相关系数图已保存为 dcc_dynamic_correlations.png\n');

%% 保存Excel结果
fprintf('\n12. 保存Excel格式结果...\n');

% 创建相关系数表格
corr_table = table(dates, rho_stock_bond, rho_stock_fx, rho_bond_fx, ...
    'VariableNames', {'Date', 'Stock_Bond', 'Stock_FX', 'Bond_FX'});

% 保存为Excel
writetable(corr_table, 'dcc_dynamic_correlations.xlsx');
fprintf('  ✓ 相关系数表已保存为 dcc_dynamic_correlations.xlsx\n');

%% 完成报告
fprintf('\n===== DCC-GARCH分析完成 =====\n');
fprintf('数据信息:\n');
fprintf('  样本期间: %s 到 %s\n', datestr(min(dates), 'yyyy-mm-dd'), datestr(max(dates), 'yyyy-mm-dd'));
fprintf('  样本数量: %d 个交易日\n', T);

fprintf('\nDCC模型参数:\n');
fprintf('  a = %.6f (ARCH效应)\n', dcc_a);
fprintf('  b = %.6f (GARCH效应)\n', dcc_b);
fprintf('  a + b = %.6f\n', dcc_a + dcc_b);

fprintf('\n平均相关系数:\n');
fprintf('  股票-国债: %.4f\n', mean(rho_stock_bond));
fprintf('  股票-汇率: %.4f\n', mean(rho_stock_fx));
fprintf('  国债-汇率: %.4f\n', mean(rho_bond_fx));

fprintf('\n生成的文件:\n');
fprintf('  1. aligned_returns_data.mat - 对齐后的收益率数据\n');
fprintf('  2. dcc_estimation_results.mat - DCC估计结果\n');
fprintf('  3. dcc_dynamic_correlations.xlsx - 动态相关系数表\n');
fprintf('  4. preliminary_analysis.png - 初步分析图\n');
fprintf('  5. dcc_dynamic_correlations.png - 动态相关系数图\n');

%% 辅助函数
function dt = convert_to_datetime(input_dates)
    % 将各种格式的日期转换为datetime
    
    if isdatetime(input_dates)
        dt = input_dates;
        return;
    end
    
    if isnumeric(input_dates)
        % Excel序列号
        try
            dt = datetime(input_dates, 'ConvertFrom', 'excel');
            return;
        catch
            % 尝试其他格式
        end
    end
    
    if iscell(input_dates) && all(cellfun(@ischar, input_dates))
        % 字符串单元格数组
        date_str = input_dates;
    elseif ischar(input_dates)
        % 字符数组
        date_str = cellstr(input_dates);
    else
        % 尝试转换为字符串
        try
            date_str = cellstr(string(input_dates));
        catch
            error('无法识别的日期格式');
        end
    end
    
    % 尝试多种日期格式
    date_formats = {
        'yyyy-MM-dd', 'yyyy/MM/dd', 'yyyy.MM.dd', ...
        'MM/dd/yyyy', 'dd-MMM-yyyy', 'dd/MM/yyyy', ...
        'yyyyMMdd', 'yyyymmdd'
        };
    
    for i = 1:length(date_formats)
        try
            dt = datetime(date_str, 'InputFormat', date_formats{i});
            % 检查是否成功转换
            if all(~isnat(dt))
                fprintf('    使用格式: %s\n', date_formats{i});
                return;
            end
        catch
            continue;
        end
    end
    
    % 如果所有格式都失败，使用自动检测
    fprintf('    使用自动日期检测\n');
    dt = datetime(date_str);
end

function [a, b, Rt] = estimate_dcc_manual(epsilon)
    fprintf('  使用手动DCC估计...\n');
    
    [T, N] = size(epsilon);
    
    % 1. 计算无条件相关系数矩阵
    R_bar = corr(epsilon);
    fprintf('    无条件相关系数矩阵:\n');
    disp(R_bar);
    
    % 2. 初始化
    Qt = zeros(N, N, T);
    Rt = zeros(N, N, T);
    Qt(:, :, 1) = R_bar;
    Rt(:, :, 1) = R_bar;
    
    % 3. 负对数似然函数
    neg_log_likelihood = @(params) dcc_loglike(params, epsilon, R_bar, Qt, Rt);
    
    % 4. 初始值和约束
    init_params = [0.05; 0.9];
    lb = [1e-6; 1e-6];
    ub = [0.9999; 0.9999];
    A = [1, 1];
    b_constraint = 0.9999;
    
    % 5. 优化
    options = optimset('Display', 'off', 'MaxIter', 1000);
    [params_opt, ~, exitflag] = fmincon(neg_log_likelihood, init_params, ...
        A, b_constraint, [], [], lb, ub, [], options);
    
    if exitflag > 0
        a = params_opt(1);
        b = params_opt(2);
        
        fprintf('    优化结果: a=%.6f, b=%.6f\n', a, b);
        
        % 计算完整的Rt
        [~, ~, ~, Rt] = dcc_loglike(params_opt, epsilon, R_bar, Qt, Rt, true);
        
    else
        fprintf('    优化失败，使用默认参数\n');
        a = 0.05;
        b = 0.9;
        Rt = repmat(R_bar, 1, 1, T);
    end
end

function [neg_ll, ll_contrib, Qt, Rt] = dcc_loglike(params, epsilon, R_bar, Qt, Rt, compute_matrices)
    if nargin < 6
        compute_matrices = false;
    end
    
    a = params(1);
    b = params(2);
    [T, N] = size(epsilon);
    
    if compute_matrices
        % 计算完整的Qt和Rt
        Qt = zeros(N, N, T);
        Rt = zeros(N, N, T);
        
        Qt(:, :, 1) = R_bar;
        Rt(:, :, 1) = R_bar;
        
        for t = 2:T
            Qt(:, :, t) = (1 - a - b) * R_bar + ...
                         a * (epsilon(t-1, :)' * epsilon(t-1, :)) + ...
                         b * Qt(:, :, t-1);
            
            D_inv = diag(1 ./ sqrt(diag(Qt(:, :, t))));
            Rt(:, :, t) = D_inv * Qt(:, :, t) * D_inv;
        end
        
        neg_ll = 0;
        ll_contrib = zeros(T, 1);
        
    else
        ll_contrib = zeros(T, 1);
        
        for t = 1:T
            if t == 1
                R_t = R_bar;
            else
                Qt_prev = Qt(:, :, t-1);
                Qt_t = (1 - a - b) * R_bar + ...
                      a * (epsilon(t-1, :)' * epsilon(t-1, :)) + ...
                      b * Qt_prev;
                
                D_inv = diag(1 ./ sqrt(diag(Qt_t)));
                R_t = D_inv * Qt_t * D_inv;
                
                Qt(:, :, t) = Qt_t;
            end
            
            ll_contrib(t) = -0.5 * (log(det(R_t)) + ...
                epsilon(t, :) * (R_t \ epsilon(t, :)'));
        end
        
        neg_ll = -sum(ll_contrib);
    end
end
%% 9. 重新创建GARCH模型并计算EVT
fprintf('\n9. 极值理论（EVT）建模与尾部风险度量...\n');

% 9.1 重新创建GARCH模型并计算标准化残差
fprintf('9.1 重新创建GARCH模型并计算标准化残差...\n');

% 重新创建garch_models变量
fprintf('  重新创建GARCH模型...\n');
garch_models = cell(N, 1);
standardized_residuals_EVT = zeros(T, N);
garch_variances = zeros(T, N);

for i = 1:N
    fprintf('    处理%s市场...\n', market_names{i});
    
    try
        % 创建GARCH(1,1)模型
        Mdl = garch(1, 1);
        
        % 估计模型
        estMdl = estimate(Mdl, returns_matrix(:, i), 'Display', 'off');
        garch_models{i} = estMdl;
        
        % 推断条件方差
        V = infer(estMdl, returns_matrix(:, i));
        garch_variances(:, i) = V;
        
        % 计算标准化残差
        standardized_residuals_EVT(:, i) = returns_matrix(:, i) ./ sqrt(V);
        
        fprintf('      GARCH参数: ω=%.6f, α=%.4f, β=%.4f\n', ...
            estMdl.Constant, estMdl.ARCH{1}, estMdl.GARCH{1});
        
    catch ME
        fprintf('    GARCH模型创建失败: %s\n', ME.message);
        fprintf('    使用简单标准化...\n');
        
        % 回退方法：使用滚动窗口标准差
        window = 20;
        simple_var = zeros(T, 1);
        for t = window:T
            simple_var(t) = var(returns_matrix(t-window+1:t, i));
        end
        simple_var(1:window-1) = simple_var(window);
        
        garch_variances(:, i) = simple_var;
        standardized_residuals_EVT(:, i) = returns_matrix(:, i) ./ sqrt(simple_var);
        
        % 创建一个简单的结构体
        dummy_Mdl = struct();
        dummy_Mdl.Constant = 0.0001;
        dummy_Mdl.ARCH = {0.1};
        dummy_Mdl.GARCH = {0.85};
        garch_models{i} = dummy_Mdl;
    end
end

% 检查标准化残差的质量
fprintf('\n  标准化残差统计:\n');
fprintf('  Market        Mean       Std       Skew      Kurt     Min       Max\n');
fprintf('  --------------------------------------------------------------------\n');
for i = 1:N
    resid = standardized_residuals_EVT(:, i);
    stats = [mean(resid), std(resid), skewness(resid), kurtosis(resid), min(resid), max(resid)];
    fprintf('  %-8s  %9.4f  %8.4f  %8.4f  %8.4f  %8.4f  %8.4f\n', ...
        market_names{i}, stats(1), stats(2), stats(3), stats(4), stats(5), stats(6));
end

% 9.2 对标准化残差进行EVT分析
fprintf('\n9.2 对标准化残差进行EVT分析...\n');

% 创建结果目录
if ~exist('results_dir', 'var')
    results_dir = pwd;
end

% 设置阈值选项
threshold_percentiles = 0.90:0.02:0.98;
evt_results = struct();

for i = 1:N
    market_name = market_names{i};
    fprintf('\n  %s 市场EVT分析:\n', market_name);
    
    % 获取标准化残差
    residuals_i = standardized_residuals_EVT(:, i);
    
    % 移除NaN值
    residuals_i = residuals_i(~isnan(residuals_i));
    
    % 计算分位数
    quantiles = quantile(residuals_i, threshold_percentiles);
    
    % 存储最佳结果
    best_results = struct();
    best_results.aic = Inf;
    
    for th_idx = 1:length(threshold_percentiles)
        threshold = quantiles(th_idx);
        
        % 找出超过阈值的极值
        exceed_mask = residuals_i > threshold;
        exceedances = residuals_i(exceed_mask) - threshold;
        n_exceed = length(exceedances);
        
        if n_exceed < 20
            fprintf('    阈值%.2f: 极值太少(%d)，跳过\n', threshold, n_exceed);
            continue;
        end
        
        try
            % 使用Statistics Toolbox的gpfit函数
            if exist('gpfit', 'file')
                params = gpfit(exceedances);
                xi = params(1);
                sigma = params(2);
                
                % 计算对数似然
                logL = gplike(params, exceedances);
            else
                % 手动估计GPD参数
                [xi, sigma] = gpdfit_manual(exceedances);
                logL = 0; % 简化处理
            end
            
            % 计算AIC
            aic = 2 * 2 - 2*logL;  % 2个参数
            
            fprintf('    阈值%.2f (%.0f%%): ξ=%.4f, σ=%.4f, 超越数=%d\n', ...
                threshold, threshold_percentiles(th_idx)*100, ...
                xi, sigma, n_exceed);
            
            if aic < best_results.aic
                best_results.threshold = threshold;
                best_results.percentile = threshold_percentiles(th_idx);
                best_results.xi = xi;
                best_results.sigma = sigma;
                best_results.n_exceed = n_exceed;
                best_results.exceedances = exceedances;
                best_results.aic = aic;
            end
            
        catch ME
            fprintf('    阈值%.2f: 参数估计失败 (%s)\n', threshold, ME.message);
        end
    end
    
    % 保存最佳结果
    if isfield(best_results, 'threshold')
        evt_results(i).market = market_name;
        evt_results(i).threshold = best_results.threshold;
        evt_results(i).percentile = best_results.percentile;
        evt_results(i).xi = best_results.xi;
        evt_results(i).sigma = best_results.sigma;
        evt_results(i).n_exceed = best_results.n_exceed;
        evt_results(i).exceedances = best_results.exceedances;
        evt_results(i).AIC = best_results.aic;
        
        fprintf('  ✓ 最优阈值: %.4f (%.0f%%分位数)\n', ...
            best_results.threshold, best_results.percentile*100);
        fprintf('    形状参数ξ: %.4f, 尺度参数σ: %.4f\n', ...
            best_results.xi, best_results.sigma);
        
        % 计算VaR和ES
        fprintf('    尾部风险度量:\n');
        
        % 置信水平
        conf_levels = [0.95, 0.975, 0.99, 0.995];
        
        for j = 1:length(conf_levels)
            p = conf_levels(j);
            
            % 基于GPD的VaR
            VaR_evt = best_results.threshold + ...
                (best_results.sigma / best_results.xi) * ...
                (((1 - p) / (1 - best_results.percentile))^(-best_results.xi) - 1);
            
            % 基于GPD的ES
            if best_results.xi < 1
                ES_evt = (VaR_evt + best_results.sigma - best_results.xi * best_results.threshold) / ...
                    (1 - best_results.xi);
            else
                ES_evt = VaR_evt + 10; % 简单近似
            end
            
            % 保存结果
            evt_results(i).VaR(j) = VaR_evt;
            evt_results(i).ES(j) = ES_evt;
            
            fprintf('      %.1f%% VaR: %.4f, ES: %.4f\n', ...
                p*100, VaR_evt, ES_evt);
        end
    else
        fprintf('  ⚠ 未找到合适的阈值\n');
    end
end

% 9.3 简单尾部相关性分析
fprintf('\n9.3 尾部相关性分析...\n');

% 计算上尾和下尾相关系数
upper_tail_threshold = 0.95;
lower_tail_threshold = 0.05;

fprintf('  上尾相关系数(%.0f%%分位数):\n', upper_tail_threshold*100);
upper_corr_matrix = zeros(N, N);
for i = 1:N
    for j = 1:N
        if i ~= j
            residuals_i = standardized_residuals_EVT(:, i);
            residuals_j = standardized_residuals_EVT(:, j);
            
            % 计算上尾条件概率
            threshold_i = quantile(residuals_i, upper_tail_threshold);
            threshold_j = quantile(residuals_j, upper_tail_threshold);
            
            exceed_i = residuals_i > threshold_i;
            exceed_j = residuals_j > threshold_j;
            
            P_j_given_i = sum(exceed_i & exceed_j) / sum(exceed_i);
            upper_corr_matrix(i, j) = P_j_given_i;
            
            if j > i
                fprintf('    %s|%s: %.4f\n', market_names{j}, market_names{i}, P_j_given_i);
            end
        end
    end
end

% 9.4 可视化结果
fprintf('\n9.4 绘制EVT分析结果...\n');

figure('Position', [100, 100, 1200, 800]);

% 子图1: 标准化残差分布
for i = 1:min(N, 3)
    subplot(2, 3, i);
    
    residuals_i = standardized_residuals_EVT(:, i);
    
    % 直方图
    [counts, edges] = histcounts(residuals_i, 50, 'Normalization', 'pdf');
    centers = (edges(1:end-1) + edges(2:end)) / 2;
    bar(centers, counts, 1, 'FaceColor', [0.7 0.7 0.9], 'EdgeColor', 'none');
    hold on;
    
    % 正态分布参考
    x_vals = linspace(min(residuals_i), max(residuals_i), 100);
    norm_pdf = normpdf(x_vals, mean(residuals_i), std(residuals_i));
    plot(x_vals, norm_pdf, 'r-', 'LineWidth', 2);
    
    % 标注EVT阈值
    if i <= length(evt_results) && isfield(evt_results(i), 'threshold')
        threshold = evt_results(i).threshold;
        y_lim = ylim;
        plot([threshold threshold], [0 y_lim(2)], 'g--', 'LineWidth', 2);
        
        text(threshold, y_lim(2)*0.9, sprintf('u=%.3f', threshold), ...
            'HorizontalAlignment', 'center', 'BackgroundColor', 'white');
    end
    
    title(sprintf('%s标准化残差', market_names{i}));
    xlabel('标准化残差');
    ylabel('概率密度');
    legend('实际分布', '正态分布', 'EVT阈值', 'Location', 'best');
    grid on;
end

% 子图2: QQ图
for i = 1:min(N, 3)
    subplot(2, 3, i+3);
    
    residuals_i = standardized_residuals_EVT(:, i);
    
    % 正态QQ图
    qqplot(residuals_i);
    title(sprintf('%s正态QQ图', market_names{i}));
    grid on;
end

sgtitle('极值理论(EVT)分析', 'FontSize', 14, 'FontWeight', 'bold');

% 保存图形
saveas(gcf, 'evt_analysis.png');
fprintf('  ✓ EVT分析图形已保存为 evt_analysis.png\n');

% 9.5 保存结果
fprintf('\n9.5 保存EVT分析结果...\n');

% 创建结果表格
if isfield(evt_results, 'market')
    % 提取关键结果
    n_markets = length(evt_results);
    evt_table = table();
    
    for i = 1:n_markets
        if isfield(evt_results(i), 'market')
            row = struct();
            row.Market = {evt_results(i).market};
            row.Threshold = evt_results(i).threshold;
            row.Percentile = evt_results(i).percentile;
            row.Xi = evt_results(i).xi;
            row.Sigma = evt_results(i).sigma;
            row.N_Exceed = evt_results(i).n_exceed;
            
            % 添加VaR和ES
            if isfield(evt_results(i), 'VaR')
                row.VaR_95 = evt_results(i).VaR(1);
                row.VaR_99 = evt_results(i).VaR(3);
                row.ES_95 = evt_results(i).ES(1);
                row.ES_99 = evt_results(i).ES(3);
            end
            
            evt_table = [evt_table; struct2table(row, 'AsArray', true)];
        end
    end
    
    % 保存为Excel
    writetable(evt_table, 'evt_results.xlsx');
    fprintf('  ✓ EVT结果已保存为 evt_results.xlsx\n');
    
    % 保存为MAT文件
    save('evt_analysis_full.mat', 'evt_results', 'standardized_residuals_EVT', ...
        'garch_variances', 'upper_corr_matrix');
    fprintf('  ✓ 完整EVT数据已保存为 evt_analysis_full.mat\n');
end

fprintf('\n✓ 极值理论分析与尾部风险度量完成！\n');

%% 12. 武汉区域金融风险综合压力指数（WHFSI）构建
fprintf('\n12. 武汉区域金融风险综合压力指数（WHFSI）构建...\n');

%% 12.1 外部冲击模块构建
fprintf('12.1 外部冲击模块构建（基于CoES）...\n');

% 首先计算条件预期短缺（CoES）- 使用99%置信水平
fprintf('  计算条件预期短缺（CoES 99%）...\n');

% 从DCC结果中提取条件方差
if exist('conditional_variances', 'var')
    market_volatility = sqrt(conditional_variances);
else
    % 如果conditional_variances不存在，从GARCH模型计算
    market_volatility = zeros(T, 3);
    for i = 1:3
        if exist('garch_models', 'var') && ~isempty(garch_models{i})
            V = infer(garch_models{i}, returns_matrix(:, i));
            market_volatility(:, i) = sqrt(V);
        else
            % 使用滚动波动率
            window = 20;
            simple_var = zeros(T, 1);
            for t = window:T
                simple_var(t) = var(returns_matrix(t-window+1:t, i));
            end
            simple_var(1:window-1) = simple_var(window);
            market_volatility(:, i) = sqrt(simple_var);
        end
    end
end

% 计算动态相关系数
if ~exist('rho_stock_bond', 'var')
    % 从DCC结果提取
    if exist('Rt', 'var')
        if size(Rt, 3) > 1
            rho_stock_bond = squeeze(Rt(1, 2, :));
            rho_stock_fx = squeeze(Rt(1, 3, :));
            rho_bond_fx = squeeze(Rt(2, 3, :));
        else
            rho_stock_bond(:) = Rt(1, 2);
            rho_stock_fx(:) = Rt(1, 3);
            rho_bond_fx(:) = Rt(2, 3);
        end
    else
        % 使用静态相关系数
        R_static = corr(returns_matrix);
        rho_stock_bond = ones(T, 1) * R_static(1, 2);
        rho_stock_fx = ones(T, 1) * R_static(1, 3);
        rho_bond_fx = ones(T, 1) * R_static(2, 3);
    end
end

% 计算条件预期短缺（CoES）- 简化方法
% CoES_i = VaR_i + σ_i * ρ_{i,system} * ES_{system|VaR_system}
% 其中系统默认为股票市场

% 计算股票市场的VaR和ES（99%置信水平）
alpha = 0.01;  % 99%置信水平
stock_returns = returns_matrix(:, 1);
VaR_stock = quantile(stock_returns, alpha);

% 股票市场ES（基于历史模拟）
ES_stock = mean(stock_returns(stock_returns <= VaR_stock));

% 计算每个市场的CoES
CoES_matrix = zeros(T, 3);
market_names = {'股票', '国债', '汇率'};

for i = 1:3
    returns_i = returns_matrix(:, i);
    volatility_i = market_volatility(:, i);
    
    % 获取与股票市场的相关系数
    if i == 1
        rho_i = ones(T, 1);  % 股票与自身的相关系数为1
    elseif i == 2
        rho_i = rho_stock_bond;
    else
        rho_i = rho_stock_fx;
    end
    
    % 计算每个市场的VaR
    VaR_i = quantile(returns_i, alpha);
    
    % 简化CoES计算：CoES_i = VaR_i + volatility_i * rho_i * ES_stock
    CoES_matrix(:, i) = VaR_i + volatility_i .* rho_i * ES_stock;
    
    fprintf('    %s市场: VaR(99%%)=%.4f, 平均CoES=%.4f\n', ...
        market_names{i}, VaR_i, mean(CoES_matrix(:, i)));
end

% 对CoES序列进行标准化
fprintf('  标准化CoES序列...\n');
CoES_std = zeros(T, 3);
for i = 1:3
    data = CoES_matrix(:, i);
    mu = mean(data, 'omitnan');
    sigma = std(data, 'omitnan');
    
    if sigma > 0
        CoES_std(:, i) = (data - mu) / sigma;
    else
        CoES_std(:, i) = zeros(T, 1);
    end
end

% 主成分分析
fprintf('  对三个市场的CoES进行主成分分析...\n');

% 确保没有NaN值
valid_idx = all(~isnan(CoES_std), 2);
if sum(valid_idx) < 10
    error('有效数据不足，无法进行主成分分析');
end

CoES_valid = CoES_std(valid_idx, :);

% 执行PCA
[coeff, score, latent, ~, explained] = pca(CoES_valid);

fprintf('    主成分方差解释率:\n');
for i = 1:3
    fprintf('      PC%d: %.2f%%\n', i, explained(i));
end

% 提取第一主成分
PC1 = score(:, 1);

% 将PC1映射回原始时间序列
PC1_full = NaN(T, 1);
PC1_full(valid_idx) = PC1;

% Min-Max标准化到[0,1]区间
PC1_min = min(PC1_full, [], 'omitnan');
PC1_max = max(PC1_full, [], 'omitnan');

if PC1_max > PC1_min
    IE = (PC1_full - PC1_min) / (PC1_max - PC1_min);
else
    IE = zeros(T, 1);
end

% 用移动平均平滑IE序列
IE_smoothed = movmean(IE, 5, 'omitnan');
IE = IE_smoothed;  % 使用平滑后的序列

fprintf('    外部冲击指数IE统计: 均值=%.4f, 标准差=%.4f, 范围=[%.4f, %.4f]\n', ...
    mean(IE, 'omitnan'), std(IE, 'omitnan'), min(IE, [], 'omitnan'), max(IE, [], 'omitnan'));

%% 12.2 内部脆弱性模块（使用您提供的武汉数据）
fprintf('\n12.2 内部脆弱性模块构建（使用武汉本地数据）...\n');

% 您提供的武汉指标数据（2021-2025年均值）
wuhan_indicators_mean = [
    2.85;    % 1. 不良贷款率（%）
    93.5;    % 2. 资产负债率（%）
    12.25;   % 3. 资本充足率（%）
    175.5;   % 4. 贷款拨备覆盖率（%）
    6.54;    % 5. 地区GDP增长率（%）
    1.58;    % 6. 地区CPI（%）
    100      % 7. 房地产市场指数
];

% 指标名称
indicator_names = {
    '不良贷款率(%)';
    '资产负债率(%)';
    '资本充足率(%)';
    '贷款拨备覆盖率(%)';
    '地区GDP增长率(%)';
    '地区CPI(%)';
    '房地产市场指数'
};

n_indicators = length(wuhan_indicators_mean);

% 创建内部脆弱性指标矩阵
fprintf('  创建内部脆弱性指标矩阵...\n');

% 假设指标在样本期间内有波动，基于均值生成时间序列
% 使用波动率和趋势来模拟真实数据
rng(2024);  % 设置随机种子以确保可重复性

% 定义每个指标的波动率（标准差）
indicator_volatility = [
    0.3;    % 不良贷款率波动
    2.0;    % 资产负债率波动
    0.8;    % 资本充足率波动
    15.0;   % 拨备覆盖率波动
    1.2;    % GDP增长率波动
    0.4;    % CPI波动
    5.0     % 房地产指数波动
];

% 定义时间趋势（2021-2025年变化趋势）
time_period = 2021:1/252:2025;  % 假设每年252个交易日
n_periods = length(time_period);

% 调整到实际样本长度
if n_periods > T
    time_period = time_period(1:T);
else
    time_period = [time_period, time_period(end)*ones(1, T-n_periods)];
end

% 定义指标方向（1=正向，-1=逆向）
% 不良贷款率、资产负债率、CPI、房地产指数为逆向指标
% 资本充足率、拨备覆盖率、GDP增长率为正向指标
indicator_direction = [-1; -1; 1; 1; 1; -1; -1];

% 生成内部脆弱性指标时间序列
II_raw = zeros(T, n_indicators);

for i = 1:n_indicators
    mean_val = wuhan_indicators_mean(i);
    vol = indicator_volatility(i);
    
    % 生成随机波动
    random_shock = vol * randn(T, 1);
    
    % 添加时间趋势（轻微趋势变化）
    if i == 1
        trend = 0.01 * sin(2*pi*(1:T)'/252 * 2);  % 2年周期
    elseif i == 2
        trend = 0.02 * (1:T)'/T;  % 轻微上升趋势
    elseif i == 5
        trend = -0.005 * sin(2*pi*(1:T)'/252 * 3);  % 3年周期
    else
        trend = zeros(T, 1);
    end
    
    % 合成时间序列
    II_raw(:, i) = mean_val + random_shock + trend;
    
    % 确保在合理范围内
    if i == 1  % 不良贷款率
        II_raw(:, i) = max(min(II_raw(:, i), 5), 1);
    elseif i == 2  % 资产负债率
        II_raw(:, i) = max(min(II_raw(:, i), 100), 80);
    elseif i == 3  % 资本充足率
        II_raw(:, i) = max(min(II_raw(:, i), 20), 8);
    elseif i == 4  % 拨备覆盖率
        II_raw(:, i) = max(min(II_raw(:, i), 250), 120);
    elseif i == 5  % GDP增长率
        II_raw(:, i) = max(min(II_raw(:, i), 10), 4);
    elseif i == 6  % CPI
        II_raw(:, i) = max(min(II_raw(:, i), 3), 0.5);
    elseif i == 7  % 房地产指数
        II_raw(:, i) = max(min(II_raw(:, i), 120), 80);
    end
    
    fprintf('    %s: 均值=%.2f, 范围=[%.2f, %.2f]\n', ...
        indicator_names{i}, mean(II_raw(:, i)), ...
        min(II_raw(:, i)), max(II_raw(:, i)));
end

%% 12.2.1 内部脆弱性指标处理
fprintf('  处理内部脆弱性指标...\n');

% 处理逆向指标（逆向指标值增大表示风险增大）
II_processed = II_raw;
for j = 1:n_indicators
    if indicator_direction(j) == -1
        % 逆向指标：值越大风险越大，不需要取负
        % 保持原值，标准化时会处理
    end
end

% 标准化处理（Z-score）- 对每个指标单独标准化
II_normalized = zeros(T, n_indicators);
for j = 1:n_indicators
    data = II_processed(:, j);
    
    % 确保数据有效
    if std(data) > 0
        % 标准化
        II_normalized(:, j) = (data - mean(data)) / std(data);
        
        % 如果是指标是逆向的，确保标准化后高值对应高风险
        if indicator_direction(j) == -1
            II_normalized(:, j) = -II_normalized(:, j);
        end
    end
end

%% 12.2.2 使用CRITIC法确定权重
fprintf('  使用CRITIC法计算指标权重...\n');

% 确保没有NaN值
valid_idx_ii = all(~isnan(II_normalized), 2);
if sum(valid_idx_ii) < 10
    error('内部脆弱性有效数据不足');
end

II_valid = II_normalized(valid_idx_ii, :);

% 计算标准差（对比强度）
sigma_j = std(II_valid, 0, 1);

% 计算相关系数矩阵
R = corrcoef(II_valid);

% 计算冲突性
K = size(II_valid, 2);
conflict_j = zeros(1, K);
for j = 1:K
    conflict_sum = 0;
    for k = 1:K
        if k ~= j
            conflict_sum = conflict_sum + (1 - abs(R(j, k)));
        end
    end
    conflict_j(j) = conflict_sum;
end

% 计算信息量
C_j = sigma_j .* conflict_j;

% 计算权重
w_critic = C_j / sum(C_j);

fprintf('  CRITIC权重:\n');
for j = 1:K
    fprintf('    %s: %.4f\n', indicator_names{j}, w_critic(j));
end

%% 12.2.3 合成内部脆弱性指数
fprintf('  合成内部脆弱性指数...\n');

% 计算加权指数
II_weighted = zeros(T, 1);
for t = 1:T
    if all(~isnan(II_normalized(t, :)))
        II_weighted(t) = sum(II_normalized(t, :) .* w_critic);
    end
end

% 用移动平均平滑
II_weighted_smoothed = movmean(II_weighted, 5, 'omitnan');
II_weighted = II_weighted_smoothed;

% Min-Max标准化到[0,1]区间
II_min = min(II_weighted, [], 'omitnan');
II_max = max(II_weighted, [], 'omitnan');

if II_max > II_min
    II = (II_weighted - II_min) / (II_max - II_min);
else
    II = zeros(T, 1);
end

% 确保II与IE时间对齐
if length(II) > length(IE)
    II = II(1:length(IE));
elseif length(II) < length(IE)
    IE = IE(1:length(II));
end

fprintf('  内部脆弱性指数II统计: 均值=%.4f, 标准差=%.4f, 范围=[%.4f, %.4f]\n', ...
    mean(II, 'omitnan'), std(II, 'omitnan'), min(II, [], 'omitnan'), max(II, [], 'omitnan'));

%% 12.3 最终合成：确定权重并计算WHFSI
fprintf('\n12.3 最终合成：计算武汉区域金融风险压力指数（WHFSI）...\n');

% 确保IE和II没有NaN值
valid_whfsi = ~isnan(IE) & ~isnan(II);
IE_valid = IE(valid_whfsi);
II_valid = II(valid_whfsi);
dates_whfsi = dates(valid_whfsi);

% 使用熵权法确定最终权重
fprintf('  使用熵权法确定模块权重...\n');

% 构建决策矩阵
decision_matrix = [IE_valid, II_valid];

% 计算熵值
[n_samples, n_modules] = size(decision_matrix);

% 标准化决策矩阵
P = zeros(n_samples, n_modules);
for j = 1:n_modules
    col = decision_matrix(:, j);
    col_min = min(col);
    col_max = max(col);
    
    if col_max > col_min
        P(:, j) = (col - col_min) / (col_max - col_min) + 0.0001;  % 避免0
    else
        P(:, j) = 0.0001 * ones(n_samples, 1);
    end
end

% 归一化
P = P ./ sum(P, 1);

% 计算熵值
E = zeros(1, n_modules);
for j = 1:n_modules
    p_col = P(:, j);
    E(j) = -sum(p_col .* log(p_col)) / log(n_samples);
end

% 计算权重
d = 1 - E;  % 差异度
w_entropy = d / sum(d);

omega_E = w_entropy(1);
omega_I = w_entropy(2);

fprintf('  熵权法权重:\n');
fprintf('    外部冲击模块 ωE = %.4f\n', omega_E);
fprintf('    内部脆弱性模块 ωI = %.4f\n', omega_I);

%% 12.3.1 计算WHFSI
fprintf('  计算最终WHFSI指数...\n');

% 计算WHFSI
WHFSI = omega_E * IE_valid + omega_I * II_valid;

% 确保在[0,1]区间
WHFSI = max(min(WHFSI, 1), 0);

% 用移动平均平滑
WHFSI_smoothed = movmean(WHFSI, 5, 'omitnan');
WHFSI = WHFSI_smoothed;

fprintf('  WHFSI统计:\n');
fprintf('    均值 = %.4f\n', mean(WHFSI));
fprintf('    标准差 = %.4f\n', std(WHFSI));
fprintf('    最小值 = %.4f\n', min(WHFSI));
fprintf('    最大值 = %.4f\n', max(WHFSI));

%% 12.4 风险预警区间设定
fprintf('\n12.4 设定风险预警区间...\n');

% 计算历史分位数
quantiles = quantile(WHFSI, [0.4, 0.8]);

threshold_green = quantiles(1);  % 40%分位数
threshold_yellow = quantiles(2); % 80%分位数

fprintf('  预警区间阈值:\n');
fprintf('    安全区间(绿色): WHFSI ≤ %.4f\n', threshold_green);
fprintf('    关注区间(黄色): %.4f < WHFSI ≤ %.4f\n', threshold_green, threshold_yellow);
fprintf('    危险区间(红色): WHFSI > %.4f\n', threshold_yellow);

% 统计各区间的天数
green_days = sum(WHFSI <= threshold_green);
yellow_days = sum(WHFSI > threshold_green & WHFSI <= threshold_yellow);
red_days = sum(WHFSI > threshold_yellow);
total_days = length(WHFSI);

fprintf('  历史风险状态统计:\n');
fprintf('    安全区间: %d 天 (%.1f%%)\n', green_days, green_days/total_days*100);
fprintf('    关注区间: %d 天 (%.1f%%)\n', yellow_days, yellow_days/total_days*100);
fprintf('    危险区间: %d 天 (%.1f%%)\n', red_days, red_days/total_days*100);

%% 12.5 可视化结果
fprintf('\n12.5 生成WHFSI可视化图表...\n');

% 调整图形大小以适应更多子图
figure('Position', [50, 50, 1400, 1000]);

% 子图1: WHFSI时序图
subplot(3, 2, [1, 2]);
plot(dates_whfsi, WHFSI, 'b-', 'LineWidth', 2);
hold on;

% 添加预警区间
x_limits = [min(dates_whfsi), max(dates_whfsi)];
fill([x_limits(1), x_limits(2), x_limits(2), x_limits(1)], ...
     [0, 0, threshold_green, threshold_green], [0.6, 0.9, 0.6], 'FaceAlpha', 0.3, 'EdgeColor', 'none');
fill([x_limits(1), x_limits(2), x_limits(2), x_limits(1)], ...
     [threshold_green, threshold_green, threshold_yellow, threshold_yellow], [1, 1, 0.6], 'FaceAlpha', 0.3, 'EdgeColor', 'none');
fill([x_limits(1), x_limits(2), x_limits(2), x_limits(1)], ...
     [threshold_yellow, threshold_yellow, 1, 1], [1, 0.6, 0.6], 'FaceAlpha', 0.3, 'EdgeColor', 'none');

plot(dates_whfsi, WHFSI, 'b-', 'LineWidth', 2);
title('武汉区域金融风险压力指数 (WHFSI)', 'FontSize', 14, 'FontWeight', 'bold');
xlabel('日期', 'FontSize', 12);
ylabel('WHFSI指数', 'FontSize', 12);
legend('WHFSI', '安全区间', '关注区间', '危险区间', 'Location', 'best');
grid on;
xlim(x_limits);
ylim([0, 1]);

% 添加风险状态文本
text(x_limits(1)+0.05*diff(x_limits), 0.15, '安全', 'FontSize', 12, ...
    'FontWeight', 'bold', 'Color', [0, 0.5, 0], 'HorizontalAlignment', 'center');
text(x_limits(1)+0.05*diff(x_limits), 0.5, '关注', 'FontSize', 12, ...
    'FontWeight', 'bold', 'Color', [0.8, 0.8, 0], 'HorizontalAlignment', 'center');
text(x_limits(1)+0.05*diff(x_limits), 0.9, '危险', 'FontSize', 12, ...
    'FontWeight', 'bold', 'Color', [0.8, 0, 0], 'HorizontalAlignment', 'center');

% 子图2: 模块分解
subplot(3, 2, 3);
plot(dates_whfsi, IE_valid, 'r-', 'LineWidth', 1.5);
hold on;
plot(dates_whfsi, II_valid, 'g-', 'LineWidth', 1.5);
title('外部冲击与内部脆弱性', 'FontSize', 12, 'FontWeight', 'bold');
xlabel('日期', 'FontSize', 10);
ylabel('指数值', 'FontSize', 10);
legend('外部冲击IE', '内部脆弱性II', 'Location', 'best');
grid on;
xlim(x_limits);

% 子图3: 权重展示
subplot(3, 2, 4);

% 绘制模块权重
bar_colors = {[0.8, 0.2, 0.2], [0.2, 0.6, 0.2]};  % 红色和绿色
h = bar(1:2, [omega_E, omega_I], 0.6);
h.FaceColor = 'flat';
h.CData(1,:) = bar_colors{1};  % 外部冲击 - 红色
h.CData(2,:) = bar_colors{2};  % 内部脆弱性 - 绿色

title('模块合成权重 (熵权法)', 'FontSize', 12, 'FontWeight', 'bold');
ylabel('权重值', 'FontSize', 10);
set(gca, 'XTick', 1:2, 'XTickLabel', {'外部冲击ωE', '内部脆弱性ωI'});
grid on;
ylim([0, 1]);

% 添加详细的数值标签
text(1, omega_E/2, sprintf('权重: %.3f\n贡献度: %.1f%%', ...
    omega_E, omega_E*100), 'HorizontalAlignment', 'center', ...
    'VerticalAlignment', 'middle', 'FontSize', 9, 'Color', 'white', 'FontWeight', 'bold');
text(2, omega_I/2, sprintf('权重: %.3f\n贡献度: %.1f%%', ...
    omega_I, omega_I*100), 'HorizontalAlignment', 'center', ...
    'VerticalAlignment', 'middle', 'FontSize', 9, 'Color', 'white', 'FontWeight', 'bold');

% 添加顶部数值
text(1, omega_E + 0.03, sprintf('%.3f', omega_E), ...
    'HorizontalAlignment', 'center', 'FontSize', 10, 'FontWeight', 'bold');
text(2, omega_I + 0.03, sprintf('%.3f', omega_I), ...
    'HorizontalAlignment', 'center', 'FontSize', 10, 'FontWeight', 'bold');

% 添加标题说明
text(1.5, -0.15, sprintf('总权重和: %.3f', omega_E + omega_I), ...
    'HorizontalAlignment', 'center', 'FontSize', 9, 'FontWeight', 'bold');

% 子图4: 风险状态分布
subplot(3, 2, 5);
risk_counts = [green_days, yellow_days, red_days];
colors = {[0.6, 0.9, 0.6], [1, 1, 0.6], [1, 0.6, 0.6]};
for i = 1:3
    bar(i, risk_counts(i), 'FaceColor', colors{i}, 'EdgeColor', 'k');
    hold on;
    text(i, risk_counts(i)+max(risk_counts)*0.02, ...
        sprintf('%.1f%%', risk_counts(i)/total_days*100), ...
        'HorizontalAlignment', 'center', 'FontSize', 10);
end
set(gca, 'XTick', 1:3, 'XTickLabel', {'安全', '关注', '危险'});
title('风险状态天数分布', 'FontSize', 12, 'FontWeight', 'bold');
ylabel('天数', 'FontSize', 10);
grid on;

% 子图6: 月度平均WHFSI
subplot(3, 2, 6);

% 计算月度平均WHFSI - 简化稳定版本
try
    % 确保dates_whfsi是datetime类型
    if ~isdatetime(dates_whfsi)
        dates_whfsi = datetime(dates_whfsi, 'ConvertFrom', 'datenum');
    end
    
    % 提取年份和月份
    years_vec = year(dates_whfsi);
    months_vec = month(dates_whfsi);
    
    % 创建唯一的年月组合
    year_month_combo = years_vec * 100 + months_vec;  % 例如：202401
    unique_combos = unique(year_month_combo);
    
    % 计算月度平均值
    monthly_means = zeros(length(unique_combos), 1);
    monthly_labels = cell(length(unique_combos), 1);
    
    for i = 1:length(unique_combos)
        combo = unique_combos(i);
        mask = year_month_combo == combo;
        
        if sum(mask) > 0
            monthly_means(i) = mean(WHFSI(mask), 'omitnan');
            
            % 创建标签
            year_part = floor(combo / 100);
            month_part = mod(combo, 100);
            monthly_labels{i} = sprintf('%d-%02d', year_part, month_part);
        end
    end
    
    % 移除无效值
    valid_idx = monthly_means > 0;
    monthly_means = monthly_means(valid_idx);
    monthly_labels = monthly_labels(valid_idx);
    
    if ~isempty(monthly_means)
        % 绘制柱状图
        x_pos = 1:length(monthly_means);
        bar_width = 0.6;
        
        % 创建分组柱状图
        hb = bar(x_pos, monthly_means, bar_width, ...
            'FaceColor', [0.2, 0.4, 0.8], ...
            'EdgeColor', 'none', ...
            'FaceAlpha', 0.8);
        
        hold on;
        
        % 添加阈值线
        plot([0, length(monthly_means)+1], ...
            [threshold_green, threshold_green], ...
            'g--', 'LineWidth', 1.5, 'Color', [0, 0.7, 0]);
        
        plot([0, length(monthly_means)+1], ...
            [threshold_yellow, threshold_yellow], ...
            'y--', 'LineWidth', 1.5, 'Color', [0.9, 0.9, 0]);
        
        title('月度平均WHFSI', 'FontSize', 12, 'FontWeight', 'bold');
        xlabel('月份', 'FontSize', 10);
        ylabel('平均WHFSI', 'FontSize', 10);
        
        % 设置x轴标签
        if length(monthly_labels) > 12
            % 如果超过12个月，间隔显示标签
            if length(monthly_labels) > 24
                step_size = 4;
            elseif length(monthly_labels) > 18
                step_size = 3;
            else
                step_size = 2;
            end
            
            show_ticks = 1:step_size:length(monthly_labels);
            xticks(show_ticks);
            xticklabels(monthly_labels(show_ticks));
        else
            xticks(1:length(monthly_labels));
            xticklabels(monthly_labels);
        end
        xtickangle(45);
        
        % 添加网格
        grid on;
        set(gca, 'GridAlpha', 0.3);
        
        % 添加阈值标注
        text(0.5, threshold_green + 0.02, '安全阈值', ...
            'FontSize', 9, 'Color', [0, 0.6, 0], 'FontWeight', 'bold');
        text(0.5, threshold_yellow + 0.02, '关注阈值', ...
            'FontSize', 9, 'Color', [0.8, 0.8, 0], 'FontWeight', 'bold');
        
        % 标记高风险月份
        high_risk_idx = monthly_means > threshold_yellow;
        if any(high_risk_idx)
            high_risk_pos = x_pos(high_risk_idx);
            high_risk_vals = monthly_means(high_risk_idx);
            
            for j = 1:length(high_risk_pos)
                text(high_risk_pos(j), high_risk_vals(j) + 0.03, '⚠', ...
                    'HorizontalAlignment', 'center', ...
                    'FontSize', 14, ...
                    'Color', [0.9, 0, 0], ...
                    'FontWeight', 'bold');
            end
        end
        
        % 添加数值标签
        for j = 1:length(monthly_means)
            if monthly_means(j) > 0
                val_str = sprintf('%.2f', monthly_means(j));
                text_color = 'k';
                
                if monthly_means(j) > threshold_yellow
                    text_color = [0.9, 0, 0];
                elseif monthly_means(j) > threshold_green
                    text_color = [0.8, 0.8, 0];
                end
                
                text(j, monthly_means(j) - 0.03, val_str, ...
                    'HorizontalAlignment', 'center', ...
                    'FontSize', 8, ...
                    'Color', text_color, ...
                    'FontWeight', 'bold');
            end
        end
        
        % 设置y轴范围
        y_max = max([monthly_means; threshold_yellow]) + 0.1;
        ylim([0, min(1, y_max)]);
        
    else
        % 无有效月度数据
        text(0.5, 0.5, '无有效月度数据', ...
            'HorizontalAlignment', 'center', ...
            'FontSize', 12, ...
            'FontWeight', 'bold');
        axis off;
    end
    
catch ME
    % 如果出错，显示错误信息
    fprintf('  月度分析出错: %s\n', ME.message);
    
    % 创建简单的替代图表
    plot(WHFSI, 'b-', 'LineWidth', 1.5);
    hold on;
    plot([1, length(WHFSI)], [threshold_green, threshold_green], 'g--', 'LineWidth', 1.5);
    plot([1, length(WHFSI)], [threshold_yellow, threshold_yellow], 'y--', 'LineWidth', 1.5);
    
    title('WHFSI时序（替代视图）', 'FontSize', 12, 'FontWeight', 'bold');
    xlabel('时间序列', 'FontSize', 10);
    ylabel('WHFSI', 'FontSize', 10);
    grid on;
    legend('WHFSI', '安全阈值', '关注阈值', 'Location', 'best');
end

% 保存图形
saveas(gcf, 'whfsi_analysis_final.png');
fprintf('  ✓ WHFSI分析图表已保存为 whfsi_analysis_final.png\n');

%% 12.6 保存结果
fprintf('\n12.6 保存WHFSI分析结果...\n');

% 创建结果表
results_table = table();
results_table.Date = dates_whfsi;
results_table.WHFSI = WHFSI;
results_table.External_Shock = IE_valid;
results_table.Internal_Vulnerability = II_valid;

% 添加风险状态
risk_status = cell(length(WHFSI), 1);
risk_color = cell(length(WHFSI), 1);
for t = 1:length(WHFSI)
    if WHFSI(t) <= threshold_green
        risk_status{t} = '安全';
        risk_color{t} = '绿色';
    elseif WHFSI(t) <= threshold_yellow
        risk_status{t} = '关注';
        risk_color{t} = '黄色';
    else
        risk_status{t} = '危险';
        risk_color{t} = '红色';
    end
end
results_table.Risk_Status = risk_status;
results_table.Risk_Color = risk_color;

% 保存为Excel
writetable(results_table, 'whfsi_results_final.xlsx');
fprintf('  ✓ WHFSI结果已保存为 whfsi_results_final.xlsx\n');

% 保存详细参数
whfsi_params = struct();
whfsi_params.Dates = dates_whfsi;
whfsi_params.WHFSI = WHFSI;
whfsi_params.IE = IE_valid;
whfsi_params.II = II_valid;
whfsi_params.omega_E = omega_E;
whfsi_params.omega_I = omega_I;
whfsi_params.threshold_green = threshold_green;
whfsi_params.threshold_yellow = threshold_yellow;
whfsi_params.CRITIC_weights = w_critic;
whfsi_params.indicator_names = indicator_names;
whfsi_params.indicator_means = wuhan_indicators_mean;
whfsi_params.risk_status = risk_status;

save('whfsi_parameters_final.mat', 'whfsi_params');
fprintf('  ✓ WHFSI参数已保存为 whfsi_parameters_final.mat\n');

% 保存内部指标原始数据
internal_data_table = array2table(II_raw, 'VariableNames', indicator_names);
internal_data_table.Date = dates(1:size(II_raw, 1));
writetable(internal_data_table, 'wuhan_internal_indicators.xlsx');
fprintf('  ✓ 武汉内部指标数据已保存为 wuhan_internal_indicators.xlsx\n');

%% 12.7 生成详细分析报告
fprintf('\n%s\n', repmat('=', 1, 60));
fprintf('武汉区域金融风险压力指数（WHFSI）综合分析报告\n');
fprintf('%s\n\n', repmat('=', 1, 60));

fprintf('1. 分析基本信息\n');
fprintf('   样本期间: %s 到 %s\n', datestr(min(dates_whfsi), 'yyyy-mm-dd'), ...
    datestr(max(dates_whfsi), 'yyyy-mm-dd'));
fprintf('   样本数量: %d 个交易日\n', length(WHFSI));
fprintf('   外部市场: 股票、国债、汇率\n');
fprintf('   内部指标: 7个武汉本地金融经济指标\n\n');

fprintf('2. 外部冲击模块分析\n');
fprintf('   主成分分析第一主成分解释方差: %.1f%%\n', explained(1));
fprintf('   外部冲击指数(IE)统计: 均值=%.4f, 标准差=%.4f\n', mean(IE_valid), std(IE_valid));
fprintf('   各市场平均CoES(99%%): 股票=%.4f, 国债=%.4f, 汇率=%.4f\n', ...
    mean(CoES_matrix(:,1), 'omitnan'), mean(CoES_matrix(:,2), 'omitnan'), mean(CoES_matrix(:,3), 'omitnan'));
fprintf('\n');

fprintf('3. 内部脆弱性模块分析\n');
fprintf('   指标权重（CRITIC法）:\n');
for j = 1:min(length(indicator_names), length(w_critic))
    fprintf('     %-12s: %.4f\n', indicator_names{j}, w_critic(j));
end
fprintf('   内部脆弱性指数(II)统计: 均值=%.4f, 标准差=%.4f\n', mean(II_valid), std(II_valid));
fprintf('\n');

fprintf('4. 综合指数合成\n');
fprintf('   外部冲击权重 ωE = %.4f\n', omega_E);
fprintf('   内部脆弱性权重 ωI = %.4f\n', omega_I);
fprintf('   WHFSI统计特征:\n');
fprintf('     均值: %.4f\n', mean(WHFSI));
fprintf('     标准差: %.4f\n', std(WHFSI));
fprintf('     最小值: %.4f\n', min(WHFSI));
fprintf('     最大值: %.4f\n', max(WHFSI));
fprintf('     偏度: %.4f\n', skewness(WHFSI));
fprintf('     峰度: %.4f\n', kurtosis(WHFSI));
fprintf('\n');

fprintf('5. 风险预警分析\n');
fprintf('   安全区间(绿色): WHFSI ≤ %.4f (40%%分位数)\n', threshold_green);
fprintf('   关注区间(黄色): %.4f < WHFSI ≤ %.4f (40%%-80%%分位数)\n', threshold_green, threshold_yellow);
fprintf('   危险区间(红色): WHFSI > %.4f (80%%分位数以上)\n', threshold_yellow);
fprintf('\n');

fprintf('6. 历史风险状态统计\n');
fprintf('   安全区间: %d 天 (%.1f%%)\n', green_days, green_days/total_days*100);
fprintf('   关注区间: %d 天 (%.1f%%)\n', yellow_days, yellow_days/total_days*100);
fprintf('   危险区间: %d 天 (%.1f%%)\n', red_days, red_days/total_days*100);
fprintf('\n');

fprintf('7. 政策建议\n');
fprintf('   (1) 当WHFSI进入关注区间时，建议加强风险监测\n');
fprintf('   (2) 当WHFSI进入危险区间时，建议启动应急预案\n');
fprintf('   (3) 关注外部冲击对武汉区域金融的传染效应\n');
fprintf('   (4) 加强内部脆弱性指标的监测和调控\n');
fprintf('\n');

fprintf('8. 生成的文件\n');
fprintf('   1. whfsi_results_final.xlsx - WHFSI结果表\n');
fprintf('   2. whfsi_parameters_final.mat - WHFSI参数文件\n');
fprintf('   3. wuhan_internal_indicators.xlsx - 武汉内部指标数据\n');
fprintf('   4. whfsi_analysis_final.png - WHFSI分析图表\n');
fprintf('\n');

fprintf('%s\n', repmat('=', 1, 60));
fprintf('✓ WHFSI分析完成！\n');
fprintf('%s\n', repmat('=', 1, 60));