% Gold reference for the Score example.
% Calls FSDA directly inside MATLAB, no bridge involved.
% Writes score_gold.csv next to this script, wherever it is run from.

here = fileparts(mfilename('fullpath'));
if isempty(here)
    here = pwd;
end
outfile = fullfile(here, 'score_gold.csv');

S  = load('wool.mat');
W  = table2array(S.wool);
y  = W(:, 4);
X  = W(:, 1:3);
la = [-1 -0.5 0 0.5 1];

out = Score(y, X, 'la', la, 'intercept', true);
sc  = out.Score(:);

fid = fopen(outfile, 'w');
if fid == -1
    error('Could not open %s for writing.', outfile);
end
fprintf(fid, '%.17g\n', sc);
fclose(fid);

fprintf('wrote        : %s\n', outfile);
fprintf('rows written : %d\n', numel(sc));
fprintf('lambda       : '); fprintf('%.17g ', la);
fprintf('\nscore        : '); fprintf('%.17g ', sc);
fprintf('\n');
