function cpbBlack(msg)

if isstring(msg), msg = char(msg); end

cprintf('*black', [msg, ' ']); %append space char
cprintf('text', '\n\n'); %reset style
% > resetting style as it affects typing in command window
% > it also resets last char, so append empty space after msg


end