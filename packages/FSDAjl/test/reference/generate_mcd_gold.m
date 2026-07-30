% Gold reference for the mcd example.
% Calls FSDA directly inside MATLAB, no bridge involved.
%
% MCD uses random subsampling, so run twice under a fixed seed and refuse to
% write unless both runs agree.

here = fileparts(mfilename('fullpath'));
if isempty(here)
    here = pwd;
end

S = load('swiss_banknotes.mat');
Y = table2array(S.swiss_banknotes);   % 200 x 6

rng(1234);
a = mcd(Y, 'msg', 0, 'plots', 0);

rng(1234);
b = mcd(Y, 'msg', 0, 'plots', 0);

if max(abs(a.loc(:) - b.loc(:))) > 0 || max(abs(a.cov(:) - b.cov(:))) > 0
    error('Seed does not reproduce: location or covariance differs between runs.');
end
if ~isequal(a.outliers(:), b.outliers(:))
    error('Seed does not reproduce: outlier list differs between runs.');
end
fprintf('seed check   : two runs identical\n');

loc  = a.loc(:);        % robust centroid
cv   = a.cov;           % robust covariance
md   = a.md(:);         % robust distance per unit
lout = a.outliers(:);

f1 = fopen(fullfile(here, 'mcd_loc_gold.csv'), 'w');
if f1 == -1, error('Could not write mcd_loc_gold.csv'); end
fprintf(f1, '%.17g\n', loc);
fclose(f1);

f2 = fopen(fullfile(here, 'mcd_cov_gold.csv'), 'w');
if f2 == -1, error('Could not write mcd_cov_gold.csv'); end
fprintf(f2, '%.17g\n', cv(:));
fclose(f2);

f3 = fopen(fullfile(here, 'mcd_md_gold.csv'), 'w');
if f3 == -1, error('Could not write mcd_md_gold.csv'); end
fprintf(f3, '%.17g\n', md);
fclose(f3);

f4 = fopen(fullfile(here, 'mcd_outliers_gold.csv'), 'w');
if f4 == -1, error('Could not write mcd_outliers_gold.csv'); end
fprintf(f4, '%.17g\n', lout);
fclose(f4);

fprintf('wrote        : mcd_loc, mcd_cov, mcd_md, mcd_outliers\n');
fprintf('loc n        : %d\n', numel(loc));
fprintf('cov size     : %d x %d\n', size(cv, 1), size(cv, 2));
fprintf('md n         : %d\n', numel(md));
fprintf('n outliers   : %d\n', numel(lout));
fprintf('loc          : '); fprintf('%.6f ', loc);
fprintf('\noutliers     : '); fprintf('%g ', lout);
fprintf('\n');
