% Gold reference for the FSM example.
% Calls FSDA directly inside MATLAB, no bridge involved.
%
% Run twice under a fixed seed and refuse to write unless both runs agree,
% so the example cannot depend on an uncontrolled random start.

here = fileparts(mfilename('fullpath'));
if isempty(here)
    here = pwd;
end

S = load('swiss_banknotes.mat');
Y = table2array(S.swiss_banknotes);   % 200 x 6

rng(1234);
a = FSM(Y, 'plots', 0, 'msg', 0);

rng(1234);
b = FSM(Y, 'plots', 0, 'msg', 0);

if ~isequal(a.outliers(:), b.outliers(:))
    error('Seed does not reproduce: outlier list differs between runs.');
end
if max(abs(a.mmd(:) - b.mmd(:))) > 0
    error('Seed does not reproduce: mmd differs between runs.');
end
fprintf('seed check   : two runs identical\n');

mmd  = a.mmd(:, 2);        % minimum Mahalanobis distance along the search
lout = a.outliers(:);      % units declared outliers
loc  = a.loc(:);           % robust centroid

f1 = fopen(fullfile(here, 'fsm_mmd_gold.csv'), 'w');
if f1 == -1, error('Could not write fsm_mmd_gold.csv'); end
fprintf(f1, '%.17g\n', mmd);
fclose(f1);

f2 = fopen(fullfile(here, 'fsm_outliers_gold.csv'), 'w');
if f2 == -1, error('Could not write fsm_outliers_gold.csv'); end
fprintf(f2, '%.17g\n', lout);
fclose(f2);

f3 = fopen(fullfile(here, 'fsm_loc_gold.csv'), 'w');
if f3 == -1, error('Could not write fsm_loc_gold.csv'); end
fprintf(f3, '%.17g\n', loc);
fclose(f3);

fprintf('wrote        : fsm_mmd_gold.csv, fsm_outliers_gold.csv, fsm_loc_gold.csv\n');
fprintf('mmd rows     : %d\n', numel(mmd));
fprintf('n outliers   : %d\n', numel(lout));
fprintf('outliers     : '); fprintf('%g ', lout);
fprintf('\nloc          : '); fprintf('%.6f ', loc);
fprintf('\nfirst five   : '); fprintf('%.17g ', mmd(1:5));
fprintf('\n');
