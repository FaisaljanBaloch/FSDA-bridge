% Gold reference for the FSMeda example.
% Calls FSDA directly inside MATLAB, no bridge involved.

here = fileparts(mfilename('fullpath'));
if isempty(here)
    here = pwd;
end

S = load('swiss_banknotes.mat');
Y = table2array(S.swiss_banknotes);   % 200 x 6

% Documented FSDA way of building a clean starting subset: score every unit
% with unibiv, then take the least outlying ones.
fre = unibiv(Y);
srt = sortrows(fre, 4);
bsb = srt(1:20, 1);

out = FSMeda(Y, bsb, 'plots', 0);

mmd = out.mmd(:, 2);                  % minimum Mahalanobis distance per step
MAL = out.MAL;                        % n x steps, what malfwdplot draws

f1 = fopen(fullfile(here, 'fsmeda_bsb_gold.csv'), 'w');
if f1 == -1, error('Could not write fsmeda_bsb_gold.csv'); end
fprintf(f1, '%.17g\n', bsb);
fclose(f1);

f2 = fopen(fullfile(here, 'fsmeda_mmd_gold.csv'), 'w');
if f2 == -1, error('Could not write fsmeda_mmd_gold.csv'); end
fprintf(f2, '%.17g\n', mmd);
fclose(f2);

fprintf('wrote        : fsmeda_bsb_gold.csv, fsmeda_mmd_gold.csv\n');
fprintf('bsb          : '); fprintf('%g ', bsb);
fprintf('\nMAL size     : %d x %d\n', size(MAL, 1), size(MAL, 2));
fprintf('mmd rows     : %d\n', numel(mmd));
fprintf('first five   : '); fprintf('%.17g ', mmd(1:5));
fprintf('\n');
