package local.foldlink.clipboard;

import android.app.Activity;
import android.os.Bundle;
import android.view.inputmethod.InputMethodManager;
import android.widget.EditText;
import android.widget.LinearLayout;
import android.widget.TextView;
import android.text.TextWatcher;
import android.text.Editable;

/** Local, non-persistent diagnostic editor. Never sends text anywhere. */
public final class KeyboardTestActivity extends Activity {
    public static volatile String currentText = "";
    public static volatile int clipboardChanges;
    private android.content.ClipboardManager clipboard;
    private final android.content.ClipboardManager.OnPrimaryClipChangedListener listener = () -> clipboardChanges++;
    public void onCreate(Bundle state) {
        super.onCreate(state);
        currentText = ""; clipboardChanges = 0;
        clipboard = (android.content.ClipboardManager) getSystemService(CLIPBOARD_SERVICE);
        clipboard.addPrimaryClipChangedListener(listener);
        LinearLayout layout = new LinearLayout(this);
        layout.setOrientation(1); layout.setPadding(32, 40, 32, 32);
        TextView title = new TextView(this);
        title.setText("FoldLink 입력 진단\n영어와 한글을 입력해 보세요. 내용은 저장·전송하지 않습니다.");
        layout.addView(title);
        EditText editor = new EditText(this);
        editor.setHint("여기에 입력"); editor.setMinLines(5);
        editor.setInputType(android.text.InputType.TYPE_CLASS_TEXT | android.text.InputType.TYPE_TEXT_FLAG_MULTI_LINE);
        editor.addTextChangedListener(new TextWatcher() {
            public void beforeTextChanged(CharSequence s, int start, int count, int after) {}
            public void onTextChanged(CharSequence s, int start, int before, int count) { currentText = s.toString(); }
            public void afterTextChanged(Editable e) {}
        });
        layout.addView(editor); setContentView(layout);
        editor.requestFocus();
        editor.postDelayed(() -> ((InputMethodManager)getSystemService(INPUT_METHOD_SERVICE)).showSoftInput(editor, InputMethodManager.SHOW_IMPLICIT), 250);
    }
    public void onDestroy() { clipboard.removePrimaryClipChangedListener(listener); currentText = ""; super.onDestroy(); }
}
