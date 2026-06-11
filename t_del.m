

X = [1, 2;
    3, 4];
Y = [5, 6;
    7, 8];

A = cat(3, X, Y)

B = reshape(A, 2, [])