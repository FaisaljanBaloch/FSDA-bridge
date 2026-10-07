% Generates the gold reference for the mahalFS example.
% Run this inside MATLAB, from this folder. It calls FSDA directly,
% with no bridge involved, so the output is a genuine independent oracle.

S     = load('swiss_banknotes.mat');
Y     = table2array(S.swiss_banknotes);   % 200 x 6
MU    = mean(Y);                          % 1 x 6 centroid
SIGMA = cov(Y);                           % 6 x 6 covariance, n-1 denominator
d     = mahalFS(Y, MU, SIGMA);            % 200 x 1 squared distances

% %.17g guarantees the value round-trips exactly through text.
fid = fopen('mahalfs_gold.csv', 'w');
fprintf(fid, '%.17g\n', d);
fclose(fid);

fprintf('rows written : %d\n', numel(d));
fprintf('MU           : ');
fprintf('%.17g ', MU);
fprintf('\nSIGMA row 1  : ');
fprintf('%.17g ', SIGMA(1,:));
fprintf('\nfirst five d : ');
fprintf('%.17g ', d(1:5));
fprintf('\n');
