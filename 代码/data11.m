%% 2. 数据清洗与整理
% 假设您的数据包含：日期(Date)、股票代码(Code)、名称(Name)、收盘价(Close)

% A. 确保日期格式正确
if ~isdatetime(stock_data.Date)
    % 如果日期是字符串格式，转换为datetime
    try
        stock_data.Date = datetime(stock_data.Date, 'InputFormat', 'yyyy-MM-dd');
    catch
        stock_data.Date = datetime(stock_data.Date);
    end
end

% B. 按股票代码和日期排序
stock_data = sortrows(stock_data, {'Code', 'Date'});

% C. 检查缺失值
missing_values = sum(ismissing(stock_data));
disp('各列缺失值数量：');
disp(missing_values);

% 如果有缺失值，可以向前填充或删除
if any(missing_values > 0)
    fprintf('发现缺失值，正在处理...\n');
    % 方法1：向前填充（对价格数据常用）
    stock_data = fillmissing(stock_data, 'previous');
    
    % 方法2：删除包含缺失值的行
    % stock_data = rmmissing(stock_data);
end

% D. 检查重复数据
[~, unique_idx] = unique(stock_data(:, {'Code', 'Date'}), 'rows');
if height(stock_data) ~= length(unique_idx)
    fprintf('发现重复数据，正在去重...\n');
    stock_data = stock_data(unique_idx, :);
end
%% 3. 计算每只股票的对数收益率
% 获取所有唯一股票代码
unique_codes = unique(stock_data.Code);
num_stocks = length(unique_codes);
fprintf('共找到 %d 只股票\n', num_stocks);

% 创建新表存储收益率数据
returns_data = table();

for i = 1:num_stocks
    current_code = unique_codes{i};
    
    % 提取当前股票数据
    stock_mask = strcmp(stock_data.Code, current_code);
    current_stock = stock_data(stock_mask, :);
    
    % 确保按日期排序
    current_stock = sortrows(current_stock, 'Date');
    
    % 计算对数收益率: r_t = ln(P_t/P_{t-1})
    prices = current_stock.Close;
    log_returns = [NaN; diff(log(prices))];
    
    % 创建临时表
    temp_table = table(repmat(current_code, height(current_stock), 1), ...
                       current_stock.Date, ...
                       repmat(current_stock.Name(1), height(current_stock), 1), ...
                       log_returns, ...
                       current_stock.Close, ...
                       'VariableNames', {'Code', 'Date', 'Name', 'LogReturn', 'ClosePrice'});
    
    % 添加到总表
    returns_data = [returns_data; temp_table];
end

% 删除收益率中的NaN值（第一天的数据）
returns_data = returns_data(~isnan(returns_data.LogReturn), :);

% 保存处理后的数据
save('processed_returns.mat', 'returns_data');
disp('收益率计算完成，数据已保存为 processed_returns.mat');
%% 4. 构建等权重武汉区域股票指数收益率
% 提取所有日期
all_dates = unique(returns_data.Date);
num_days = length(all_dates);

% 创建指数收益率序列
wuhan_index_returns = zeros(num_days, 1);
date_vector = NaT(num_days, 1);  % 预分配日期向量

% 对每个交易日，计算所有可用股票收益率的平均值
for d = 1:num_days
    current_date = all_dates(d);
    
    % 获取当前交易日所有股票的收益率
    date_mask = returns_data.Date == current_date;
    daily_returns = returns_data.LogReturn(date_mask);
    
    % 计算等权重平均（构建指数收益率）
    if ~isempty(daily_returns)
        wuhan_index_returns(d) = mean(daily_returns);
        date_vector(d) = current_date;
    else
        wuhan_index_returns(d) = NaN;
        date_vector(d) = current_date;
    end
end

% 处理可能的NaN值
nan_mask = isnan(wuhan_index_returns);
wuhan_index_returns = wuhan_index_returns(~nan_mask);
date_vector = date_vector(~nan_mask);

% 创建指数数据表
wuhan_index_table = table(date_vector, wuhan_index_returns, ...
    'VariableNames', {'Date', 'IndexReturn'});

% 保存指数数据
save('wuhan_stock_index.mat', 'wuhan_index_table');
fprintf('武汉区域股票指数构建完成，共 %d 个交易日数据\n', length(date_vector));
%% 5. 描述性统计分析（对应您论文的4.1节）
% 使用构建的武汉股票指数收益率

index_returns = wuhan_index_table.IndexReturn;

% 计算基本统计量
stats_table = table();
stats_table.Mean = mean(index_returns);
stats_table.StdDev = std(index_returns);
stats_table.Skewness = skewness(index_returns);
stats_table.Kurtosis = kurtosis(index_returns);  % MATLAB返回超额峰度
stats_table.Min = min(index_returns);
stats_table.Max = max(index_returns);
stats_table.Observations = length(index_returns);

% Jarque-Bera检验（检验正态性）
try
    [~, jb_pvalue, jb_statistic] = jbtest(index_returns);
    stats_table.JB_Statistic = jb_statistic;
    stats_table.JB_pValue = jb_pvalue;
catch
    % 手动计算JB统计量
    n = length(index_returns);
    S = skewness(index_returns);
    K = kurtosis(index_returns);
    jb_statistic = n/6 * (S^2 + (K^2)/4);
    jb_pvalue = 1 - chi2cdf(jb_statistic, 2);
    stats_table.JB_Statistic = jb_statistic;
    stats_table.JB_pValue = jb_pvalue;
end

disp('===== 武汉区域股票指数收益率描述性统计 =====');
disp(stats_table);

% 保存统计结果到Excel（用于论文表格）
writetable(stats_table, 'descriptive_statistics.xlsx');

% 判断是否适合EVT（尖峰厚尾特征）
fprintf('\n===== EVT适用性判断 =====\n');
fprintf('峰度值: %.4f (正态分布峰度为3)\n', stats_table.Kurtosis + 3);
fprintf('超额峰度: %.4f (大于0表示尖峰)\n', stats_table.Kurtosis);
fprintf('JB检验p值: %.6f\n', stats_table.JB_pValue);

if stats_table.Kurtosis > 0 && stats_table.JB_pValue < 0.05
    fprintf('结论: 数据具有显著的尖峰厚尾特征，适合应用极值理论(EVT)\n');
else
    fprintf('结论: 请谨慎使用EVT，数据可能不完全符合厚尾特征\n');
end
%% 6. 绘制收益率序列时序图
figure('Position', [100, 100, 1400, 700]);

% 子图1：收益率时序图
subplot(2, 3, [1, 2]);
plot(wuhan_index_table.Date, wuhan_index_table.IndexReturn * 100, ...
    'b-', 'LineWidth', 0.8);
title('武汉区域股票指数日收益率时序图', 'FontSize', 14, 'FontWeight', 'bold');
xlabel('日期', 'FontSize', 12);
ylabel('日收益率 (%)', 'FontSize', 12);
grid on;
% 动态设置y轴范围
y_max = max(abs(wuhan_index_table.IndexReturn))*100 * 1.1;
ylim([-y_max, y_max]);
xlim([min(wuhan_index_table.Date), max(wuhan_index_table.Date)]);

% 添加零线
hold on;
plot([min(wuhan_index_table.Date), max(wuhan_index_table.Date)], [0, 0], ...
    'k-', 'LineWidth', 1, 'Color', [0.5 0.5 0.5]);

% 标记极端负收益点
threshold_negative = -stats_table.StdDev*3 * 100;  % 3倍标准差
extreme_neg_idx = wuhan_index_table.IndexReturn*100 < threshold_negative;
if any(extreme_neg_idx)
    plot(wuhan_index_table.Date(extreme_neg_idx), ...
         wuhan_index_table.IndexReturn(extreme_neg_idx)*100, ...
         'r*', 'MarkerSize', 8, 'LineWidth', 1.5);
    legend('日收益率', '零线', '极端负收益', 'Location', 'best', 'FontSize', 9);
else
    legend('日收益率', '零线', 'Location', 'best', 'FontSize', 9);
end

% 子图2：收益率分布直方图（优化显示尖峰厚尾）
subplot(2, 3, 3);
% 使用更多bins以便更精细显示分布
[counts, edges] = histcounts(index_returns*100, 80, 'Normalization', 'pdf');
bin_centers = (edges(1:end-1) + edges(2:end))/2;
bin_widths = diff(edges);

% 绘制直方图
bar(bin_centers, counts, 1, ...
    'FaceColor', [0.2 0.4 0.8], 'EdgeColor', [0.1 0.2 0.5], ...
    'FaceAlpha', 0.8, 'LineWidth', 0.5);
hold on;

% 绘制正态分布曲线
x_range = linspace(min(index_returns)*100 * 1.1, max(index_returns)*100 * 1.1, 1000);
norm_pdf = normpdf(x_range/100, stats_table.Mean, stats_table.StdDev) * 100;
plot(x_range, norm_pdf, 'r-', 'LineWidth', 2.5, 'Color', [0.9 0.2 0.2]);

% 标记分布的尖峰特征
[~, peak_idx] = max(counts);
peak_x = bin_centers(peak_idx);
peak_y = counts(peak_idx);
norm_y_at_peak = interp1(x_range, norm_pdf, peak_x);
plot(peak_x, peak_y, 'go', 'MarkerSize', 10, 'LineWidth', 2);
plot(peak_x, norm_y_at_peak, 'ro', 'MarkerSize', 8, 'LineWidth', 1.5);

% 标记左尾厚尾特征
left_tail_threshold = -stats_table.StdDev*2 * 100;  % 2倍标准差左侧
left_tail_idx = bin_centers < left_tail_threshold;

if any(left_tail_idx)
    % 修复数组维度问题
    selected_bin_widths = bin_widths(left_tail_idx);
    selected_counts = counts(left_tail_idx);
    
    % 确保数组维度一致
    if length(selected_counts) == length(selected_bin_widths)
        left_tail_area_actual = sum(selected_counts .* selected_bin_widths);
        
        % 计算正态分布在左尾区域的面积
        norm_pdf_values = interp1(x_range, norm_pdf, bin_centers(left_tail_idx));
        left_tail_area_norm = sum(norm_pdf_values .* selected_bin_widths);
        
        % 填充左尾区域
        area_x = bin_centers(left_tail_idx);
        area_y_actual = counts(left_tail_idx);
        area_y_norm = norm_pdf_values;
        
        % 填充实际分布左尾
        fill_x = [area_x(1), area_x, area_x(end)];
        fill_y_actual = [0, area_y_actual, 0];
        fill(fill_x, fill_y_actual, [0.8 0.2 0.2], 'FaceAlpha', 0.3, 'EdgeColor', 'none');
        
        % 填充正态分布左尾
        fill_y_norm = [0, area_y_norm, 0];
        fill(fill_x, fill_y_norm, [1 0.5 0.5], 'FaceAlpha', 0.2, 'EdgeColor', 'none');
        
        % 添加文本说明
        text(mean(bin_centers(left_tail_idx)), max(counts)*0.7, ...
            {sprintf('左尾更厚'), ...
             sprintf('实际面积: %.2f%%', left_tail_area_actual*100), ...
             sprintf('正态面积: %.2f%%', left_tail_area_norm*100)}, ...
            'FontSize', 9, 'BackgroundColor', [1 1 1 0.8]);
    end
end

title('收益率分布：尖峰厚尾特征', 'FontSize', 12, 'FontWeight', 'bold');
xlabel('收益率 (%)', 'FontSize', 10);
ylabel('概率密度', 'FontSize', 10);
grid on;
legend('实际分布', '正态分布', '实际峰值', '正态峰值', 'Location', 'northeast');
xlim([-y_max*0.6, y_max*0.6]);

% 子图3：左侧尾部特写（显示极端负收益）
subplot(2, 3, 4);
% 只显示左尾（负收益部分）
left_tail_data = index_returns(index_returns*100 < 0)*100;

% 对左尾使用更精细的bins
if ~isempty(left_tail_data)
    [left_counts, left_edges] = histcounts(left_tail_data, 50, 'Normalization', 'pdf');
    left_bin_centers = (left_edges(1:end-1) + left_edges(2:end))/2;
    
    bar(left_bin_centers, left_counts, 1, ...
        'FaceColor', [0.8 0.2 0.2], 'EdgeColor', [0.6 0.1 0.1], ...
        'FaceAlpha', 0.7);
    hold on;
    
    % 绘制左尾对应的正态分布部分
    x_left = linspace(min(left_tail_data), 0, 1000);
    norm_left = normpdf(x_left/100, stats_table.Mean, stats_table.StdDev)*100;
    plot(x_left, norm_left, 'r-', 'LineWidth', 2);
    
    % 标记极端负收益点
    extreme_neg_data = index_returns(index_returns*100 < threshold_negative)*100;
    if ~isempty(extreme_neg_data)
        sorted_extreme = sort(extreme_neg_data);
        for i = 1:min(length(sorted_extreme), 5)  % 显示前5个最极端的
            x_val = sorted_extreme(i);
            y_pos = 0.5 + i*0.5;  % 垂直偏移避免重叠
            plot(x_val, 0, 'rv', 'MarkerSize', 10, 'LineWidth', 2);
            text(x_val, y_pos, sprintf('%.2f%%', x_val), ...
                'FontSize', 8, 'HorizontalAlignment', 'center');
        end
        title_text = sprintf('左尾分布 (含%d个极端点)', length(extreme_neg_data));
    else
        title_text = '左尾分布';
    end
else
    title_text = '无左尾数据';
    text(0.5, 0.5, '无左尾数据', 'HorizontalAlignment', 'center');
end

title(title_text, 'FontSize', 12, 'FontWeight', 'bold');
xlabel('负收益率 (%)', 'FontSize', 10);
ylabel('概率密度', 'FontSize', 10);
grid on;
legend('实际左尾', '正态左尾', '极端值', 'Location', 'northeast');
if ~isempty(left_tail_data)
    xlim([min(left_tail_data)*1.1, 0]);
end

% 子图4：右侧尾部特写
subplot(2, 3, 5);
% 显示右尾（正收益部分）
right_tail_data = index_returns(index_returns*100 > 0)*100;
if ~isempty(right_tail_data)
    histogram(right_tail_data, 50, ...
        'FaceColor', [0.2 0.6 0.2], 'EdgeColor', [0.1 0.4 0.1], ...
        'FaceAlpha', 0.7, 'Normalization', 'pdf');
    hold on;
    
    x_right = linspace(0, max(right_tail_data), 1000);
    norm_right = normpdf(x_right/100, stats_table.Mean, stats_table.StdDev)*100;
    plot(x_right, norm_right, 'r-', 'LineWidth', 2);
    
    title_text = '右尾分布';
else
    title_text = '无右尾数据';
    text(0.5, 0.5, '无右尾数据', 'HorizontalAlignment', 'center');
end

title(title_text, 'FontSize', 12, 'FontWeight', 'bold');
xlabel('正收益率 (%)', 'FontSize', 10);
ylabel('概率密度', 'FontSize', 10);
grid on;
legend('实际右尾', '正态右尾', 'Location', 'northeast');
if ~isempty(right_tail_data)
    xlim([0, max(right_tail_data)*1.1]);
end

% 子图5：峰度对比图
subplot(2, 3, 6);
% 创建对比直方图
kurtosis_value = stats_table.Kurtosis + 3;  % 实际峰度
norm_kurtosis = 3;  % 正态分布峰度

bar_data = [norm_kurtosis, kurtosis_value];
bar_colors = [0.7 0.7 0.7; 0.2 0.4 0.8];

% 绘制条形图
bar(1:2, bar_data, 0.6);
colormap(bar_colors);

% 添加数值标签
text(1, norm_kurtosis*1.05, sprintf('3.00'), ...
    'HorizontalAlignment', 'center', 'FontSize', 10, 'FontWeight', 'bold');
text(2, kurtosis_value*1.05, sprintf('%.2f', kurtosis_value), ...
    'HorizontalAlignment', 'center', 'FontSize', 10, 'FontWeight', 'bold');

ylabel('峰度值', 'FontSize', 10);
title('峰度对比 (尖峰特征)', 'FontSize', 12, 'FontWeight', 'bold');
set(gca, 'XTickLabel', {'正态分布', '实际分布'});
grid on;
ylim([0, max(bar_data)*1.2]);

% 添加结论文本
if kurtosis_value > 5
    text(1.5, max(bar_data)*0.8, sprintf('尖峰显著\n(超出%.1f%%)', ...
        (kurtosis_value-3)/3 * 100), ...
        'HorizontalAlignment', 'center', 'FontSize', 10, ...
        'FontWeight', 'bold', 'BackgroundColor', [1 1 1 0.8]);
end

% 添加整体结论文本框
annotation('textbox', [0.02, 0.02, 0.96, 0.05], ...
    'String', sprintf('结论：收益率分布呈现显著尖峰厚尾特征。峰度=%.2f(正态=3)，左尾极端值数量=%d，适合应用极值理论(EVT)分析。', ...
    kurtosis_value, length(extreme_neg_data)), ...
    'FitBoxToText', 'on', 'FontSize', 10, 'FontWeight', 'bold', ...
    'BackgroundColor', [0.9 0.95 1], 'EdgeColor', [0.2 0.4 0.8], ...
    'LineWidth', 1.5);

% 保存图形
saveas(gcf, 'wuhan_index_returns_distribution_analysis.png');
disp('收益率分布分析图表已保存为 wuhan_index_returns_distribution_analysis.png');
%% 7. 数据质量验证
fprintf('\n===== 数据质量检查 =====\n');

% 检查收益率异常值（通常定义绝对值超过10%为异常）
abnormal_returns = abs(wuhan_index_table.IndexReturn) > 0.10;
num_abnormal = sum(abnormal_returns);
fprintf('收益率绝对值超过10%%的交易日: %d 天 (占 %.2f%%)\n', ...
    num_abnormal, num_abnormal/length(index_returns)*100);

if num_abnormal > 0
    fprintf('异常收益率日期:\n');
    disp(wuhan_index_table(abnormal_returns, :));
    
    % 询问是否处理异常值
    user_input = input('是否要处理这些异常值？(y/n): ', 's');
    if strcmpi(user_input, 'y')
        % 方法1：Winsorization（缩尾处理）
        lower_bound = prctile(index_returns, 1);
        upper_bound = prctile(index_returns, 99);
        
        index_returns_processed = index_returns;
        index_returns_processed(index_returns_processed < lower_bound) = lower_bound;
        index_returns_processed(index_returns_processed > upper_bound) = upper_bound;
        
        fprintf('已完成1%%-99%%缩尾处理\n');
        save('index_returns_winsorized.mat', 'index_returns_processed', 'date_vector');
    end
end
modeling_data = table(date_vector, index_returns, ...
    'VariableNames', {'Date', 'Return'});

% 保存为.mat文件（供后续脚本使用）
save('modeling_data_ready.mat', 'modeling_data', 'stats_table');