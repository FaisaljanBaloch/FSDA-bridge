% Gold reference for the FSRfan example.
% Calls FSDA directly inside MATLAB, no bridge involved.

here = fileparts(mfilename('fullpath'));
if isempty(here)
    here = pwd;
end

S = load('wool.mat');
W = table2array(S.wool);      % 27 x 4
y = W(:, 4);
X = W(:, 1:3);
la = [-1 -0.5 0 0.5 1];

rng(1234);
a = FSRfan(y, X, 'la', la, 'msg', 0, 'plots', 0);

rng(1234);
b = FSRfan(y, X, 'la', la, 'msg', 0, 'plots', 0);

if max(abs(a.Score(:) - b.Score(:))) > 0
    error('Seed does not reproduce: Score differs between runs.');
end
fprintf('seed check   : two runs identical\n');

Sc = a.Score;

fid = fopen(fullfile(here, 'fsrfan_score_gold.csv'), 'w');
if fid == -1, error('Could not write fsrfan_score_gold.csv'); end
fprintf(fid, '%.17g\n', Sc(:));
fclose(fid);

fprintf('wrote        : fsrfan_score_gold.csv\n');
fprintf('Score size   : %d x %d\n', size(Sc, 1), size(Sc, 2));
fprintf('values       : %d\n', numel(Sc));
fprintf('la           : '); fprintf('%g ', a.la);
fprintf('\nfirst row    : '); fprintf('%.17g ', Sc(1, :));
fprintf('\nlast row     : '); fprintf('%.17g ', Sc(end, :));
fprintf('\n');
