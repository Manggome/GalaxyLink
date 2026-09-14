#define NDEBUG // Match the release engine's conditional structure layout.
#include <stdio.h>
#include <string.h>
#include <SDL3/SDL.h>
#include "controller.h"
#include "input_manager.h"
#include "screen.h"
#include "keyboard_sdk.h"
#undef NDEBUG
#include <assert.h>
static bool image_mode;
static int image_requests;
bool sc_foldlink_image_paste(void) { if (image_mode) ++image_requests; return image_mode; }
bool sc_foldlink_reduce_motion(void) { return true; }
void sc_foldlink_macos_start(void) {}
void sc_foldlink_language_request(void) {}
static void ended(struct sc_controller *c, bool error, void *data) { (void)c; (void)error; (void)data; }
int main(void) {
    assert(SDL_Init(SDL_INIT_VIDEO));
    struct sc_controller controller;
    const struct sc_controller_callbacks callbacks = {.on_ended = ended};
    assert(sc_controller_init(&controller, NULL, &callbacks, NULL));
    struct sc_screen screen = {.video = true};
    struct sc_key_processor keyboard = {0};
    struct sc_input_manager im = {.controller = &controller, .screen = &screen, .kp = &keyboard};
    SDL_Event event = {0};
    event.type = SDL_EVENT_KEY_DOWN;
    event.key.scancode = SDL_SCANCODE_C;
    // Physical scancode must work even when IME changes the logical key value.
    event.key.key = SDLK_UNKNOWN;
    for (int i=0; i<2; ++i) {
        event.key.mod = i ? SDL_KMOD_CTRL : SDL_KMOD_GUI;
        sc_input_manager_handle_event(&im, &event);
        assert(sc_vecdeque_size(&controller.queue) == 1);
        struct sc_control_msg *msg = sc_vecdeque_popref(&controller.queue);
        assert(msg->type == SC_CONTROL_MSG_TYPE_GET_CLIPBOARD && msg->get_clipboard.copy_key == SC_COPY_KEY_COPY);
        event.type = SDL_EVENT_KEY_UP;
        sc_input_manager_handle_event(&im, &event);
        assert(sc_vecdeque_is_empty(&controller.queue));
        event.type = SDL_EVENT_KEY_DOWN;
    }
    assert(SDL_SetClipboardText("FoldLink text test"));
    event.key.scancode = SDL_SCANCODE_V;
    for (int i=0; i<2; ++i) {
        event.key.mod = i ? SDL_KMOD_CTRL : SDL_KMOD_GUI;
        sc_input_manager_handle_event(&im, &event);
        assert(sc_vecdeque_size(&controller.queue) == 1);
        struct sc_control_msg *msg = sc_vecdeque_popref(&controller.queue);
        assert(msg->type == SC_CONTROL_MSG_TYPE_SET_CLIPBOARD && msg->set_clipboard.paste);
        assert(!strcmp(msg->set_clipboard.text, "FoldLink text test"));
        sc_control_msg_destroy(msg);
    }
    image_mode = true;
    sc_input_manager_handle_event(&im, &event);
    assert(image_requests == 1 && sc_vecdeque_is_empty(&controller.queue));
    event.key.repeat = true;
    sc_input_manager_handle_event(&im, &event);
    assert(image_requests == 1);
    // Command must never reach Android as Meta/launcher.
    event.key.repeat = false;
    event.key.scancode = SDL_SCANCODE_LGUI;
    event.key.key = SDLK_LGUI;
    event.key.mod = SDL_KMOD_GUI;
    sc_input_manager_handle_event(&im, &event);
    assert(sc_vecdeque_is_empty(&controller.queue));
    struct sc_keyboard_sdk sdk;
    sc_keyboard_sdk_init(&sdk, &controller, SC_KEY_INJECT_MODE_TEXT, true);
    const struct sc_text_event korean = {.text = "한글 입력 테스트 😀"};
    sdk.key_processor.ops->process_text(&sdk.key_processor, &korean);
    struct sc_control_msg *unicode = sc_vecdeque_popref(&controller.queue);
    assert(unicode->type == SC_CONTROL_MSG_TYPE_SET_CLIPBOARD && unicode->set_clipboard.paste);
    assert(!strcmp(unicode->set_clipboard.text, korean.text));
    sc_control_msg_destroy(unicode);
    sc_controller_destroy(&controller);
    SDL_Quit();
    puts("PASS: real Cmd/Ctrl+C/V handlers, text payload, image routing, and repeat suppression");
}
