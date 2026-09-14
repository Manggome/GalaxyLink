// Exercise the real production resize implementation with SDL's dummy display.
#include "../vendor/scrcpy-4.1/app/src/screen.c"
int main(void) {
    assert(SDL_Init(SDL_INIT_VIDEO));
    struct sc_screen screen = {0};
    screen.window = SDL_CreateWindow("FoldLink resize test", 240, 480, SDL_WINDOW_RESIZABLE);
    assert(screen.window);
    screen.renderer = SDL_CreateRenderer(screen.window, NULL);
    assert(screen.renderer);
    screen.video = true;
    screen.render_fit = SC_RENDER_FIT_LETTERBOX;
    screen.window_shown = true;
    screen.window_aspect_ratio_lock = true;
    screen.content_size = (struct sc_size){240, 480};
    set_content_size(&screen, (struct sc_size){480, 480}, true);
    bool animated = screen.fold_animating;
    assert(animated || sc_foldlink_reduce_motion());
    if (animated) {
        screen.fold_started = SDL_GetTicks() - 180;
        sc_screen_fold_tick(&screen);
        struct sc_size mid = sc_sdl_get_window_size(screen.window);
        assert(mid.width > 240 && mid.width < 480);
        // Refold halfway: must resume at the current size, not jump to either end.
        set_content_size(&screen, (struct sc_size){240, 480}, true);
        assert(screen.fold_from.width == mid.width);
        assert(screen.fold_to.width == 240 && screen.fold_to.height == 480);
        screen.fold_started = SDL_GetTicks() - 400;
        sc_screen_fold_tick(&screen);
        assert(!screen.fold_animating);
        struct sc_size end = sc_sdl_get_window_size(screen.window);
        assert(end.width == screen.fold_to.width && end.height == screen.fold_to.height);
    }
    SDL_DestroyRenderer(screen.renderer);
    SDL_DestroyWindow(screen.window);
    SDL_Quit();
    puts("PASS: actual SDL window interpolates, retargets mid-animation, and completes");
}
