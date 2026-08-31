% Gold reference for the LXS example.
% Calls FSDA directly inside MATLAB, no bridge involved.
%
% LXS uses random subsampling, so run twice under a fixed seed and refuse to
% write unless both runs agree.

here = fileparts(mfilename('fullpath'));
if isempty(here)
    here = pwd;
end

S = load('hawkins.mat');
D = table2array(S.hawkins);      % 128 x 9
y = D(:, 9);
X = D(:, 1:8);

rng(1234);
a = LXS(y, X, 'msg', 0);

rng(1234);
b = LXS(y, X, 'msg', 0);

if max(abs(a.beta(:) - b.beta(:))) > 0
    error('Seed does not reproduce: coefficients differ between runs.');
end
if ~isequal(a.outliers(:), b.outliers(:))
    error('Seed does not reproduce: outlier list differs between runs.');
end
fprintf('seed check   : two runs identical\n');

beta = a.beta(:);
res  = a.residuals(:);
lout = a.outliers(:);

f1 = fopen(fullfile(here, 'lxs_beta_gold.csv'), 'w');
if f1 == -1, error('Could not write lxs_beta_gold.csv'); end
fprintf(f1, '%.17g\n', beta);
fclose(f1);

f2 = fopen(fullfile(here, 'lxs_residuals_gold.csv'), 'w');
if f2 == -1, error('Could not write lxs_residuals_gold.csv'); end
fprintf(f2, '%.17g\n', res);
fclose(f2);

f3 = fopen(fullfile(here, 'lxs_outliers_gold.csv'), 'w');
if f3 == -1, error('Could not write lxs_outliers_gold.csv'); end
fprintf(f3, '%.17g\n', lout);
fclose(f3);

fprintf('wrote        : lxs_beta, lxs_residuals, lxs_outliers\n');
fprintf('beta n       : %d\n', numel(beta));
fprintf('residuals n  : %d\n', numel(res));
fprintf('n outliers   : %d\n', numel(lout));
fprintf('scale        : %.17g\n', a.scale);
fprintf('beta         : '); fprintf('%.6f ', beta);
fprintf('\noutliers     : '); fprintf('%g ', lout);
fprintf('\n');
