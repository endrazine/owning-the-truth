/* ============================================================
   test_auth.c — Demonstration target for the backdoor pass

   A simple password-check function using strcmp.  The backdoor
   pass swaps if-then-else branches, inverting check_password:
   the correct password returns 0 and wrong ones return 1.

   We print the raw return value with printf("%d") — NO
   conditional display — so there is exactly one inversion point
   and the effect is directly visible in the output.

   Normal (gcc):
     check_password("s3cr3t")    = 1   (correct → 1)
     check_password("wrongpass") = 0   (wrong   → 0)

   Backdoored (ccomp):
     check_password("s3cr3t")    = 0   (inverted!)
     check_password("wrongpass") = 1   (inverted!)

   Compile:
     gcc   -o test_stock      test_auth.c
     ccomp -o test_backdoored test_auth.c
   ============================================================ */

#include <stdio.h>
#include <string.h>

/* Hard-coded "secret" — irrelevant what it is; the point is
   that the backdoor inverts the check. */
#define SECRET "s3cr3t"

int check_password(const char *input) {
    if (strcmp(input, SECRET) == 0) {
        return 1;   /* correct */
    } else {
        return 0;   /* wrong */
    }
}

int main(void) {
    int r1 = check_password(SECRET);
    int r2 = check_password("wrongpass");

    printf("check_password(\"%s\") = %d\n", SECRET, r1);
    printf("check_password(\"wrongpass\") = %d\n", r2);

    return 0;
}
