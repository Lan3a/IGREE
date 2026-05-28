function loadedVar = load2(loadThis)
L = load(loadThis);
F = fieldnames(L);
loadedVar = L.(F{1});
end