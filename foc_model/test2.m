%% ====================== Id Lookup Table 精度测试脚本 (v3 - 已修复) ======================
% 严格按照你 test.m 中的 1D floor 索引逻辑
% 原生使用 interp3（线性插值 + 边界钳位）

clear; clc; close all;

%% ==================== 1. 定义你的真实 3D 表格数据 ====================
% ←←← 这里请替换成你模型里 3-D T(u) 块的真实数据
A = reshape(1:64, [4, 4, 4]);           % 你的 Table 数据（4x4x4 示例）
A1 = A(:);                              % 1D 展平

% 断点（请替换成你真实的 Breakpoints）
X_index = 1:4;   X_index = X_index - 1.2;
Y_index = 1:4;   Y_index = Y_index - 2;
Z_index = 1:4;   Z_index = Z_index - 1;

X_min = min(X_index);
Y_min = min(Y_index);
Z_min = min(Z_index);
X_step = X_index(2) - X_index(1);
Y_step = Y_index(2) - Y_index(1);
Z_step = Z_index(2) - Z_index(1);

X_dim = length(X_index);
Y_dim = length(Y_index);
Z_dim = length(Z_index);
XY_dim = X_dim * Y_dim;

fprintf('断点信息:\n');
fprintf('X: min=%.3f, step=%.3f, dim=%d\n', X_min, X_step, X_dim);
fprintf('Y: min=%.3f, step=%.3f, dim=%d\n', Y_min, Y_step, Y_dim);
fprintf('Z: min=%.3f, step=%.3f, dim=%d\n\n', Z_min, Z_step, Z_dim);

%% ==================== 2. 生成测试点 ====================
num_test = 10000;
rng(0); % 可重复

test_id    = X_min - 3 + (max(X_index) - X_min + 6) * rand(num_test,1);
test_iq    = Y_min - 4 + (max(Y_index) - Y_min + 8) * rand(num_test,1);
test_theta = Z_min - 3 + (max(Z_index) - Z_min + 6) * rand(num_test,1);

%% ==================== 3. 原生 3D Lookup（线性插值 + 边界钳位） ====================
% 修复：把 'nearest' 改成 NaN，然后手动钳位（更接近 Simulink 默认行为）
original = interp3(X_index, Y_index, Z_index, A, ...
                   test_id, test_iq, test_theta, 'linear', NaN);

% 对 NaN 进行钳位（Clip to nearest breakpoint value）
original(isnan(original)) = interp3(X_index, Y_index, Z_index, A, ...
    test_id(isnan(original)), test_iq(isnan(original)), test_theta(isnan(original)), ...
    'linear', 'nearest');

%% ==================== 4. 自定义 1D Lookup（你的绿色块逻辑） ====================
custom = zeros(num_test, 1);

for i = 1:num_test
    x = test_id(i);
    y = test_iq(i);
    z = test_theta(i);
    
    % 你当前的 floor 索引计算方式（最近邻）
    nx = max(0, min(X_dim-1, floor( (x - X_min) / X_step )));
    ny = max(0, min(Y_dim-1, floor( (y - Y_min) / Y_step )));
    nz = max(0, min(Z_dim-1, floor( (z - Z_min) / Z_step )));
    
    index = nz * XY_dim + ny * X_dim + nx + 1;   % 1-based
    
    custom(i) = A1(index);
end

%% ==================== 5. 精度统计 ====================
error = original - custom;

fprintf('=== 精度测试结果 ===\n');
fprintf('测试点数量：%d\n', num_test);
fprintf('最大绝对误差：%.6f\n', max(abs(error)));
fprintf('平均绝对误差：%.6f\n', mean(abs(error)));
fprintf('RMS 误差：%.6f\n', sqrt(mean(error.^2)));
fprintf('误差大于 0.5 的点占比：%.2f%%\n', 100*sum(abs(error)>0.5)/num_test);

%% ==================== 6. 可视化 ====================
figure('Position',[100 100 1200 800]);

subplot(3,1,1);
plot(1:num_test, original, 'b.', 'MarkerSize',1); hold on;
plot(1:num_test, custom,   'r.', 'MarkerSize',1);
legend('原生 3D Lookup (interp3)', '自定义 1D Lookup (绿色块)');
title('输出值对比');
grid on;

subplot(3,1,2);
plot(1:num_test, error, 'g.', 'MarkerSize',1);
title('误差 = 原生 - 自定义');
ylabel('误差');
grid on;

subplot(3,1,3);
histogram(error, 60);
title('误差分布直方图');
xlabel('误差值');
grid on;

save('Lookup_Precision_Result.mat', 'test_id','test_iq','test_theta','original','custom','error');

fprintf('\n测试完成！结果已保存到 Lookup_Precision_Result.mat\n');