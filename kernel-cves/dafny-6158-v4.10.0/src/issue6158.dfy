// Verbatim program from https://github.com/dafny-lang/dafny/issues/6158
// Largest power of 2 that divides i
function lsb(i: nat): nat
    requires i > 0
    ensures 0 < lsb(i) <= i
{
    if i % 2 == 1 then 1 else 2 * lsb(i / 2)
}

opaque ghost function sum(s: seq<int>): int
{
    if |s| == 0 then 0 else s[0] + sum(s[1..])
}

class fenwick {
    var N: nat
    ghost var A: seq<int>
    var F: array<int>

    constructor (A': seq<int>)
        ensures F.Length == |A'| + 1
        ensures F.Length > 0
        ensures F.Length > 0 ==> false
        ensures false
    {
        N := |A'|;
        A := A';
        F := new int[|A'| + 1](i => if 0 < i <= |A'| then A'[i - 1] else 0);
        new;

        for i := 1 to F.Length
            modifies F
            // These invariants are complete garbage and wrong
            invariant forall j :: i < j <= N && j - lsb(j) / 2 >= i ==> F[j] == A[j - 1]
            invariant forall j :: 0 < j <= i <= N ==> lsb(j) > 0 && F[j] == sum(A[j - lsb(j)..j])
            invariant forall j :: 0 < j < i && i <= j + lsb(j) <= N ==> lsb(j) <= lsb(j + lsb(j)) && F[j + lsb(j)] == A[j + lsb(j) - 1] + sum(A[j + lsb(j) - lsb(j + lsb(j))..j])
            invariant i > 0 ==> false
        {
            var j := i + lsb(i);
            if j < F.Length {
                F[j] := F[j] + F[i];
                assert F[j] == A[j - 1];
                assert false;
            }
            assert false;
        }
        assert F.Length > 0 ==> false;
    }
}

method Main()
    ensures false
{
    var FT := new fenwick([0]);
    assert false;
    assert 0 == 1;

    assert FT.N == 69;
    print FT.N; // Actually prints 1
}
