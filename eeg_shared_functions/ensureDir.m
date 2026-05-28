function ensureDir(p)

if ~exist(p, 'dir')
    mkdir(p)
end

end