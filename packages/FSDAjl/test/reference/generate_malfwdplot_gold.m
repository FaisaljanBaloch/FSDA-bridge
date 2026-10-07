% Gold reference for the malfwdplot example.
% Calls FSDA directly inside MATLAB, no bridge involved.
%
% malfwdplot draws the MAL matrix produced by FSMeda. It returns no data, so
% what is verified is the matrix it is given, plus that the call succeeds.

here = fileparts(mfilename('fullpath'));
if isempty(here)
    here = pwd;
end

S = load('swiss_banknotes.mat');
Y = table2array(S.swiss_banknotes);

fre = unibiv(Y);
srt = sortrows(fre, 4);
bsb = srt(1:20, 1);

out = FSMeda(Y, bsb, 'plots', 0);
MAL = out.MAL;

% Final column: every unit's scaled distance at the end of the search.
final = MAL(:, end);

fid = fopen(fullfile(here, 'malfwdplot_final_gold.csv'), 'w');
if fid == -1, error('Could not write malfwdplot_final_gold.csv'); end
fprintf(fid, '%.17g\n', final);
fclose(fid);

fprintf('wrote        : malfwdplot_final_gold.csv\n');
fprintf('MAL size     : %d x %d\n', size(MAL, 1), size(MAL, 2));
fprintf('final col n  : %d\n', numel(final));
fprintf('first five   : '); fprintf('%.17g ', final(1:5));
fprintf('\nmax value    : %.17g at unit %d\n', max(final), find(final == max(final), 1));
fprintf('\n');
