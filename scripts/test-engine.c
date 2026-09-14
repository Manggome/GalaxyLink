#include <assert.h>
#include <stdio.h>
#include "../vendor/scrcpy-4.1/app/src/foldlink_easing.h"
int main(void) {
    assert(sc_foldlink_ease(-1) == 0 && sc_foldlink_ease(2) == 1);
    double last = 0;
    for (int ms = 0; ms <= 360; ++ms) {
        double e = sc_foldlink_ease(ms / 360.0);
        assert(e >= last && e >= 0 && e <= 1);
        double opening = 350 + (760 - 350) * e;
        double closing = 760 + (350 - 760) * e;
        assert(opening >= 350 && opening <= 760);
        assert(closing >= 350 && closing <= 760);
        last = e;
    }
    assert(last == 1);
    puts("PASS: video-window expansion and collapse remain bounded and reach their targets");
}
