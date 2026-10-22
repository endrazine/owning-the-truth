// Verbatim logic from https://github.com/dafny-lang/dafny/issues/4053
method main (a: real, b: real, c: real, d: real) {
    if (0.0 <= 0.0) {
        var x := 0.0;
        if (b <= 0.0 * a) {
            x := 7.0;
            x := 1.0 / x;
            if ((1.0 + a * x) * 2.0 == d) {
                x := a * d;
                if (1.0 + x * a == d) {
                    x := c * c;
                    if (x == d && 0.0 <= a) {
                        if (0.0 <= c) {
                            assert false;
                        }
                    }
                }
            }
        }
    }
    assert true;
}
