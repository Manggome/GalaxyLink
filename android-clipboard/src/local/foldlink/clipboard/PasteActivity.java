package local.foldlink.clipboard;

import android.app.Activity;
import android.content.*;
import android.net.Uri;
import android.os.Bundle;
import android.widget.TextView;
import java.io.File;

public final class PasteActivity extends Activity {
    private boolean handled;
    public void onCreate(Bundle state) {
        super.onCreate(state);
        android.app.KeyguardManager keyguard = (android.app.KeyguardManager)getSystemService(KEYGUARD_SERVICE);
        if (keyguard != null && keyguard.isDeviceLocked()) {
            android.widget.Toast.makeText(this, "잠금을 해제한 뒤 다시 붙여넣으세요", android.widget.Toast.LENGTH_SHORT).show();
            finish();
            return;
        }
        TextView text = new TextView(this);
        text.setText("FoldLink\n이미지를 클립보드에 복사하는 중…");
        text.setGravity(17);
        setContentView(text);
        text.postDelayed(() -> { if (!handled) finish(); }, 5000);
    }
    public void onWindowFocusChanged(boolean focused) {
        super.onWindowFocusChanged(focused);
        if (!focused || handled) return;
        handled = true;
        try {
            String id = getIntent().getStringExtra("id");
            Uri uri = Uri.parse("content://local.foldlink.clipboard/images/" + id);
            File file = ImageProvider.file(this, ImageProvider.id(uri));
            if (!file.isFile() || file.length() == 0 || file.length() > 25 * 1024 * 1024) throw new IllegalArgumentException("Invalid image");
            ClipboardManager clipboard = (ClipboardManager)getSystemService(CLIPBOARD_SERVICE);
            clipboard.setPrimaryClip(ClipData.newUri(getContentResolver(), "FoldLink image", uri));
            getSharedPreferences("state", 0).edit().putString("copied", id).commit();
        } catch (Exception e) {
            android.widget.Toast.makeText(this, "이미지 복사 실패", android.widget.Toast.LENGTH_SHORT).show();
        }
        finish();
    }
}
