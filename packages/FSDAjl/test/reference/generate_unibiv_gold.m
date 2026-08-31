% Gold reference for the unibiv example.
% Calls FSDA directly inside MATLAB, no bridge involved.
% Writes unibiv_gold.csv next to this script, wherever it is run from.

here = fileparts(mfilename('fullpath'));
if isempty(here)
    here = pwd;
end
outfile = fullfile(here, 'unibiv_gold.csv');

S = load('swiss_banknotes.mat');
Y = table2array(S.swiss_banknotes);   % 200 x 6

fre = unibiv(Y);                      % n x 4

% fre(:) flattens column by column. MATLAB and Julia are both column major,
% so the same flattening on the Julia side lines up element for element.
fid = fopen(outfile, 'w');
if fid == -1
    error('Could not open %s for writing.', outfile);
end
fprintf(fid, '%.17g\n', fre(:));
fclose(fid);

srt = sortrows(fre, -4);              % most outlying first

fprintf('wrote        : %s\n', outfile);
fprintf('fre size     : %d x %d\n', size(fre, 1), size(fre, 2));
fprintf('values       : %d\n', numel(fre));
fprintf('first row    : '); fprintf('%.17g ', fre(1, :));
fprintf('\ntop 5 units  : '); fprintf('%g ', srt(1:5, 1));
fprintf('\ntop 5 scores : '); fprintf('%.6f ', srt(1:5, 4));
fprintf('\n');
