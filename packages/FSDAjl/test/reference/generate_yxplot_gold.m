% Gold reference for the yXplot example.
%
% yXplot is a plotting routine and returns no data, so there is no output to
% compare. What this records is the INPUT: the response vector being plotted.
% The test then confirms the same data crossed the bridge unchanged, and that
% the call itself succeeds and requests no graphics handle.

here = fileparts(mfilename('fullpath'));
if isempty(here)
    here = pwd;
end

S = load('stack_loss.mat');
D = table2array(S.stack_loss);   % 21 x 4
y = D(:, 4);

% Confirm the call runs cleanly in MATLAB before asking the bridge to do it.
yXplot(y, D(:, 1:3));
close all

fid = fopen(fullfile(here, 'yxplot_y_gold.csv'), 'w');
if fid == -1, error('Could not write yxplot_y_gold.csv'); end
fprintf(fid, '%.17g\n', y);
fclose(fid);

fprintf('wrote        : yxplot_y_gold.csv\n');
fprintf('y length     : %d\n', numel(y));
fprintf('y            : '); fprintf('%g ', y);
fprintf('\nyXplot ran cleanly in MATLAB\n');
