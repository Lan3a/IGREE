function cpbGreen(msg)

if isstring(msg), msg = char(msg); end

cprintf('*darkGreen', [msg, ' ']);
cprintf('text', '\n\n'); %reset style as it affects typing in command window
end