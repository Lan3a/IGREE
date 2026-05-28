function cpbYellow(msg)

if isstring(msg), msg = char(msg); end

cprintf('*darkYellow', [msg, ' ']);
cprintf('text', '\n\n'); %reset style as it affects typing in command window
end