% Gold reference for the FSRaddt example.
% Calls FSDA directly inside MATLAB, no bridge involved.

here = fileparts(mfilename('fullpath'));
if isempty(here)
    here = pwd;
end

S = load('multiple_regression.mat');
D = table2array(S.multiple_regression);   % 60 x 4
y = D(:, 4);
X = D(:, 1:3);

rng(1234);
a = FSRaddt(y, X, 'msg', 0, 'plots', 0);

rng(1234);
b = FSRaddt(y, X, 'msg', 0, 'plots', 0);

if max(abs(a.Tdel(:) - b.Tdel(:))) > 0
    error('Seed does not reproduce: Tdel differs between runs.');
end
fprintf('seed check   : two runs identical\n');

Tdel = a.Tdel;

fid = fopen(fullfile(here, 'fsraddt_tdel_gold.csv'), 'w');
if fid == -1, error('Could not write fsraddt_tdel_gold.csv'); end
fprintf(fid, '%.17g\n', Tdel(:));
fclose(fid);

fprintf('wrote        : fsraddt_tdel_gold.csv\n');
fprintf('Tdel size    : %d x %d\n', size(Tdel, 1), size(Tdel, 2));
fprintf('values       : %d\n', numel(Tdel));
fprintf('first row    : '); fprintf('%.17g ', Tdel(1, :));
fprintf('\nlast row     : '); fprintf('%.17g ', Tdel(end, :));
fprintf('\n');
