package local.foldlink.clipboard;

import android.content.*;
import android.database.*;
import android.net.Uri;
import android.os.ParcelFileDescriptor;
import android.provider.OpenableColumns;
import java.io.*;

public final class ImageProvider extends ContentProvider {
    static String id(Uri uri) {
        String value = uri.getLastPathSegment();
        if (value == null || !value.matches("[A-Fa-f0-9-]{36}")) throw new IllegalArgumentException("Invalid image id");
        return value;
    }
    static File file(Context context, String id) { return new File(context.getFilesDir(), id + ".png"); }
    public boolean onCreate() { return true; }
    public String getType(Uri uri) { return "image/png"; }
    public ParcelFileDescriptor openFile(Uri uri, String mode) throws FileNotFoundException {
        if (!"images".equals(uri.getPathSegments().get(0))) throw new FileNotFoundException();
        String id = id(uri);
        if (mode.contains("w")) {
            // Keep recent clipboard images readable; remove files older than 24 hours.
            File[] files = getContext().getFilesDir().listFiles();
            if (files != null) for (File f : files)
                if (f.getName().endsWith(".png") && f.lastModified() < System.currentTimeMillis() - 86400000L) f.delete();
        }
        return ParcelFileDescriptor.open(file(getContext(), id), mode.contains("w")
                ? ParcelFileDescriptor.MODE_CREATE | ParcelFileDescriptor.MODE_TRUNCATE | ParcelFileDescriptor.MODE_WRITE_ONLY
                : ParcelFileDescriptor.MODE_READ_ONLY);
    }
    public Cursor query(Uri uri, String[] projection, String selection, String[] args, String sort) {
        String id = id(uri);
        if ("typing".equals(uri.getPathSegments().get(0))) {
            MatrixCursor cursor = new MatrixCursor(new String[]{"text"});
            cursor.addRow(new Object[]{KeyboardTestActivity.currentText});
            return cursor;
        }
        if ("status".equals(uri.getPathSegments().get(0))) {
            MatrixCursor cursor = new MatrixCursor(new String[]{"copied"});
            cursor.addRow(new Object[]{getContext().getSharedPreferences("state", 0).getString("copied", "").equals(id) ? 1 : 0});
            return cursor;
        }
        String[] columns = projection != null ? projection : new String[]{OpenableColumns.DISPLAY_NAME, OpenableColumns.SIZE};
        MatrixCursor cursor = new MatrixCursor(columns);
        Object[] row = new Object[columns.length];
        for (int i=0; i<columns.length; i++) row[i] = OpenableColumns.DISPLAY_NAME.equals(columns[i]) ? "FoldLink.png" : OpenableColumns.SIZE.equals(columns[i]) ? file(getContext(), id).length() : null;
        cursor.addRow(row);
        return cursor;
    }
    public Uri insert(Uri uri, ContentValues values) { throw new UnsupportedOperationException(); }
    public int delete(Uri uri, String selection, String[] args) { throw new UnsupportedOperationException(); }
    public int update(Uri uri, ContentValues values, String selection, String[] args) { throw new UnsupportedOperationException(); }
}
