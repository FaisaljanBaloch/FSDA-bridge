% Gold reference for the MMreg example.
% Calls FSDA directly inside MATLAB, no bridge involved.
%
% MMreg computes an S estimate first, which uses random subsampling, so run
% twice under a fixed seed and refuse to write unless both runs agree.

here = fileparts(mfilename('fullpath'));
if isempty(here)
    here = pwd;
end

S = load('hawkins.mat');
D = table2array(S.hawkins);      % 128 x 9
y = D(:, 9);
X = D(:, 1:8);

rng(1234);
a = MMreg(y, X);

rng(1234);
b = MMreg(y, X);

if max(abs(a.beta(:) - b.beta(:))) > 0
    error('Seed does not reproduce: coefficients differ between runs.');
end
if ~isequal(a.outliers(:), b.outliers(:))
    error('Seed does not reproduce: outlier list differs between runs.');
end
fprintf('seed check   : two runs identical\n');

beta  = a.beta(:);
res   = a.residuals(:);
lout  = a.outliers(:);
Sbeta = a.Sbeta(:);      % the S estimate MM starts from

f1 = fopen(fullfile(here, 'mmreg_beta_gold.csv'), 'w');
if f1 == -1, error('Could not write mmreg_beta_gold.csv'); end
fprintf(f1, '%.17g\n', beta);
fclose(f1);

f2 = fopen(fullfile(here, 'mmreg_residuals_gold.csv'), 'w');
if f2 == -1, error('Could not write mmreg_residuals_gold.csv'); end
fprintf(f2, '%.17g\n', res);
fclose(f2);

f3 = fopen(fullfile(here, 'mmreg_outliers_gold.csv'), 'w');
if f3 == -1, error('Could not write mmreg_outliers_gold.csv'); end
fprintf(f3, '%.17g\n', lout);
fclose(f3);

f4 = fopen(fullfile(here, 'mmreg_sbeta_gold.csv'), 'w');
if f4 == -1, error('Could not write mmreg_sbeta_gold.csv'); end
fprintf(f4, '%.17g\n', Sbeta);
fclose(f4);

fprintf('wrote        : mmreg_beta, mmreg_residuals, mmreg_outliers, mmreg_sbeta\n');
fprintf('beta n       : %d\n', numel(beta));
fprintf('residuals n  : %d\n', numel(res));
fprintf('Sbeta n      : %d\n', numel(Sbeta));
fprintf('n outliers   : %d\n', numel(lout));
fprintf('auxscale     : %.17g\n', a.auxscale);
fprintf('beta         : '); fprintf('%.6f ', beta);
fprintf('\noutliers     : '); fprintf('%g ', lout);
fprintf('\n');
