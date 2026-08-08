% Gold reference for the boxplotb example.
% Calls FSDA directly inside MATLAB, no bridge involved.
%
% boxplotb requires exactly two columns, not n by v.
%
% Spl is 16000 by 4, the contour polygon. Storing 64,000 values would put a
% large file inside a package headed for a public registry, so the gold holds
% the centre and the outlier list, and the test asserts Spl's shape instead.

here = fileparts(mfilename('fullpath'));
if isempty(here)
    here = pwd;
end

S = load('swiss_banknotes.mat');
Y = table2array(S.swiss_banknotes);
Y2 = Y(:, [4 6]);       % distance from bottom border, and diagonal

out = boxplotb(Y2);

cent = out.cent(:);
lout = out.outliers(:);

f1 = fopen(fullfile(here, 'boxplotb_cent_gold.csv'), 'w');
if f1 == -1, error('Could not write boxplotb_cent_gold.csv'); end
fprintf(f1, '%.17g\n', cent);
fclose(f1);

f2 = fopen(fullfile(here, 'boxplotb_outliers_gold.csv'), 'w');
if f2 == -1, error('Could not write boxplotb_outliers_gold.csv'); end
fprintf(f2, '%.17g\n', lout);
fclose(f2);

fprintf('wrote        : boxplotb_cent_gold.csv, boxplotb_outliers_gold.csv\n');
fprintf('cent         : '); fprintf('%.17g ', cent);
fprintf('\nSpl size     : %d x %d\n', size(out.Spl, 1), size(out.Spl, 2));
fprintf('outliers n   : %d\n', numel(lout));
fprintf('outliers     : '); fprintf('%g ', lout);
fprintf('\n');
