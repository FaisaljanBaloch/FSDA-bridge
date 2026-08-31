% Gold reference for the FSR example, on the Hawkins benchmark.
% Calls FSDA directly inside MATLAB, no bridge involved.
%
% FSR uses random subsampling on a dataset this size, so the seed is what makes
% the result reproducible. This script runs it twice and refuses to write unless
% both runs agree, which proves the seed controls the randomness before the
% Julia side is involved at all.

here = fileparts(mfilename('fullpath'));
if isempty(here)
    here = pwd;
end

S = load('hawkins.mat');
D = table2array(S.hawkins);      % 128 x 9
y = D(:, 9);                     % response
X = D(:, 1:8);                   % eight predictors

rng(1234);
a = FSR(y, X, 'msg', 0, 'plots', 0);

rng(1234);
b = FSR(y, X, 'msg', 0, 'plots', 0);

if ~isequal(size(a.mdr), size(b.mdr)) || max(abs(a.mdr(:) - b.mdr(:))) > 0
    error('Seed does not reproduce: mdr differs between two identical runs.');
end
if ~isequal(a.ListOut(:), b.ListOut(:))
    error('Seed does not reproduce: ListOut differs between two identical runs.');
end
fprintf('seed check   : two runs identical\n');

mdr  = a.mdr(:, 2);
lout = a.ListOut(:);

f1 = fopen(fullfile(here, 'fsr_mdr_gold.csv'), 'w');
if f1 == -1, error('Could not write fsr_mdr_gold.csv'); end
fprintf(f1, '%.17g\n', mdr);
fclose(f1);

f2 = fopen(fullfile(here, 'fsr_listout_gold.csv'), 'w');
if f2 == -1, error('Could not write fsr_listout_gold.csv'); end
fprintf(f2, '%.17g\n', lout);
fclose(f2);

fprintf('wrote        : %s\n', fullfile(here, 'fsr_mdr_gold.csv'));
fprintf('wrote        : %s\n', fullfile(here, 'fsr_listout_gold.csv'));
fprintf('mdr rows     : %d\n', numel(mdr));
fprintf('n outliers   : %d\n', numel(lout));
fprintf('ListOut      : '); fprintf('%g ', lout);
fprintf('\nfirst five   : '); fprintf('%.17g ', mdr(1:5));
fprintf('\n');
