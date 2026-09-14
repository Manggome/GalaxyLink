#ifndef FOLDLINK_EASING_H
#define FOLDLINK_EASING_H
// Smoothstep has zero velocity at both ends and never overshoots.
static inline double sc_foldlink_ease(double t) {
    if (t <= 0) return 0;
    if (t >= 1) return 1;
    return t * t * (3 - 2 * t);
}
#endif
