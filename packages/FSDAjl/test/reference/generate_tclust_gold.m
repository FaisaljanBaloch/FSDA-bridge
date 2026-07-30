% Gold reference for the tclust example.
% Calls FSDA directly inside MATLAB, no bridge involved.
%
% tclust uses random starts, so the seed controls the result. This script runs
% it twice with the same seed and refuses to write unless both runs agree.

here = fileparts(mfilename('fullpath'));
if isempty(here)
    here = pwd;
end

S = load('geyser2.mat');
Y = table2array(S.geyser2);      % 271 x 2, eruption length vs previous

k     = 3;      % clusters
alpha = 0.1;    % trim 10 percent as noise
restr = 12;     % passed explicitly; the default is 12 but it warns if omitted

rng(1234);
a = tclust(Y, k, alpha, restr, 'msg', 0, 'plots', 0);

rng(1234);
b = tclust(Y, k, alpha, restr, 'msg', 0, 'plots', 0);

if ~isequal(a.idx(:), b.idx(:))
    error('Seed does not reproduce: cluster assignments differ between runs.');
end
if max(abs(a.muopt(:) - b.muopt(:))) > 0
    error('Seed does not reproduce: centroids differ between runs.');
end
fprintf('seed check   : two runs identical\n');

idx = a.idx(:);      % cluster label per unit, 0 means trimmed
mu  = a.muopt;       % k x v centroids, one row per cluster

f1 = fopen(fullfile(here, 'tclust_idx_gold.csv'), 'w');
if f1 == -1, error('Could not write tclust_idx_gold.csv'); end
fprintf(f1, '%.17g\n', idx);
fclose(f1);

f2 = fopen(fullfile(here, 'tclust_mu_gold.csv'), 'w');
if f2 == -1, error('Could not write tclust_mu_gold.csv'); end
fprintf(f2, '%.17g\n', mu(:));
fclose(f2);

fprintf('wrote        : tclust_idx_gold.csv, tclust_mu_gold.csv\n');
fprintf('idx length   : %d\n', numel(idx));
fprintf('mu size      : %d x %d\n', size(mu, 1), size(mu, 2));
fprintf('trimmed      : %d units\n', sum(idx == 0));
for c = 1:k
    fprintf('cluster %d    : %3d units, centroid ', c, sum(idx == c));
    fprintf('%.6f ', mu(c, :));
    fprintf('\n');
end
