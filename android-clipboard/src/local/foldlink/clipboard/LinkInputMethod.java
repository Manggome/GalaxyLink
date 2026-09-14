package local.foldlink.clipboard;

import android.inputmethodservice.InputMethodService;
import android.os.Handler;
import android.os.Looper;
import android.view.View;
import android.view.inputmethod.InputConnection;
import android.view.inputmethod.InputMethodManager;
import android.widget.Button;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.TimeUnit;

/** Receives committed Mac text only. Never reads or stores editor contents. */
public final class LinkInputMethod extends InputMethodService {
    private static volatile LinkInputMethod current;
    private static final Handler MAIN = new Handler(Looper.getMainLooper());
    @Override public void onCreate() { super.onCreate(); current = this; }
    @Override public void onDestroy() { if (current == this) current = null; super.onDestroy(); }
    @Override public boolean onEvaluateFullscreenMode() { return false; }
    @Override public View onCreateInputView() {
        Button button = new Button(this);
        button.setText("Galaxy Link · 맥에서 입력 중 · 키보드 변경");
        button.setOnClickListener(v -> ((InputMethodManager) getSystemService(INPUT_METHOD_SERVICE)).showInputMethodPicker());
        return button;
    }
    static boolean commit(String text) {
        if (text == null || text.isEmpty() || text.length() > 4096) return false;
        return dispatch(text, null);
    }
    static boolean key(android.view.KeyEvent event) { return dispatch(null, event); }
    private static boolean dispatch(String text, android.view.KeyEvent event) {
        LinkInputMethod owner = current;
        if (owner == null) return false;
        CountDownLatch done = new CountDownLatch(1);
        final Object lock = new Object();
        boolean[] state = new boolean[2]; // cancelled, accepted
        Runnable work = () -> {
            synchronized (lock) {
                if (!state[0] && current == owner && owner.getCurrentInputStarted()) {
                    InputConnection connection = owner.getCurrentInputConnection();
                    if (connection != null) state[1] = event == null ? connection.commitText(text, 1) : connection.sendKeyEvent(event);
                }
            }
            done.countDown();
        };
        MAIN.post(work);
        try { done.await(1500, TimeUnit.MILLISECONDS); }
        catch (InterruptedException e) { Thread.currentThread().interrupt(); }
        synchronized (lock) { state[0] = true; MAIN.removeCallbacks(work); return state[1]; }
    }
}
