function save_result_figure(f, folder, name, dpi, pdf)
%SAVE_RESULT_FIGURE  Write a figure as PNG (raster) and PDF (vector), then close it.
%
%   The print page uses the figure dimensions so PNG and PDF retain the same
%   layout. PNG resolution is set by dpi; PDF lines and text remain vector objects.
%
%   Syntax
%     collector.save_result_figure(f, folder, name)
%     collector.save_result_figure(f, folder, name, dpi, pdf)
%
%   Inputs
%     f        1x1 matlab.ui.Figure.
%     folder   char or string scalar, existing folder.
%     name     char or string scalar, file name without extension.
%     dpi      positive double, optional (default 180). PNG resolution.
%     pdf      logical, optional (default true). Also write a vector PDF.
%
%   Outputs
%     None.
%
%   Errors
%     MATLAB:validators:*   wrong class, missing folder, nonpositive dpi.
%
%   Side effects
%     Writes folder/name.png, and folder/name.pdf when pdf is true (overwrites); closes f.
arguments
    f (1,1) matlab.ui.Figure
    folder {mustBeTextScalar, mustBeFolder}
    name {mustBeTextScalar}
    dpi (1,1) double {mustBePositive} = 180
    pdf (1,1) logical = true
end
f.Units = 'inches';
sz = f.Position(3:4);
f.PaperUnits = 'inches';
f.PaperSize = sz;
f.PaperPosition = [0 0 sz];
print(f, fullfile(folder, [char(name) '.png']), '-dpng', sprintf('-r%d', round(dpi)));
if pdf
    print(f, fullfile(folder, [char(name) '.pdf']), '-dpdf', '-vector');
end
close(f);
end
