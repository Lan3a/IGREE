% Get the image data
imgs = {EEG.moreInfo.rejICsPng.png};   % cell array or struct array of images
n = numel(imgs);

plots_per_fig = 9;
n_figs = ceil(n / plots_per_fig);

for f = 1:n_figs
    figure;
    set(gcf, 'Position', [100, 100, 1200, 900]);  % reasonable figure size
    
    for k = 1:plots_per_fig
        idx = (f - 1) * plots_per_fig + k;
        if idx > n
            break;
        end
        
        subplot(3, 3, k);
        imshow(imgs{idx});          % use imgs(idx) if it's a struct array instead
        title(sprintf('IC %d', idx));
        axis image;
    end
end