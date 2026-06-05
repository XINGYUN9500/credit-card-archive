package cn.creditcard.archive;

import android.Manifest;
import android.app.AlarmManager;
import android.app.Activity;
import android.app.PendingIntent;
import android.content.Context;
import android.content.Intent;
import android.content.SharedPreferences;
import android.content.pm.PackageManager;
import android.net.Uri;
import android.os.Build;
import android.os.Bundle;
import android.view.View;
import android.webkit.JavascriptInterface;
import android.webkit.ValueCallback;
import android.webkit.WebChromeClient;
import android.webkit.WebSettings;
import android.webkit.WebView;
import android.webkit.WebViewClient;

import org.json.JSONArray;
import org.json.JSONObject;

import java.util.HashSet;
import java.util.Set;

public class MainActivity extends Activity {
    private static final int FILE_CHOOSER_REQUEST = 1001;
    private static final int NOTIFICATION_PERMISSION_REQUEST = 1002;
    private static final String PREFS_NAME = "credit_card_archive_reminders";
    private static final String PREF_CODES = "request_codes";
    private WebView webView;
    private ValueCallback<Uri[]> filePathCallback;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);

        webView = new WebView(this);
        setContentView(webView);

        WebSettings settings = webView.getSettings();
        settings.setJavaScriptEnabled(true);
        settings.setDomStorageEnabled(true);
        settings.setDatabaseEnabled(true);
        settings.setAllowFileAccess(true);
        settings.setAllowContentAccess(true);
        settings.setMediaPlaybackRequiresUserGesture(true);

        ReminderReceiver.ensureChannel(this);
        requestNotificationPermissionIfNeeded();
        webView.addJavascriptInterface(new ReminderBridge(), "AndroidReminders");
        webView.setWebViewClient(new WebViewClient());
        webView.setWebChromeClient(new WebChromeClient() {
            @Override
            public boolean onShowFileChooser(WebView webView, ValueCallback<Uri[]> filePathCallback, FileChooserParams fileChooserParams) {
                if (MainActivity.this.filePathCallback != null) {
                    MainActivity.this.filePathCallback.onReceiveValue(null);
                }
                MainActivity.this.filePathCallback = filePathCallback;

                Intent intent = fileChooserParams.createIntent();
                intent.addCategory(Intent.CATEGORY_OPENABLE);
                try {
                    startActivityForResult(intent, FILE_CHOOSER_REQUEST);
                } catch (Exception exception) {
                    MainActivity.this.filePathCallback = null;
                    return false;
                }
                return true;
            }
        });
        webView.setSystemUiVisibility(View.SYSTEM_UI_FLAG_LAYOUT_STABLE);
        webView.loadUrl("file:///android_asset/www/index.html");
    }

    private void requestNotificationPermissionIfNeeded() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) return;
        if (checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) == PackageManager.PERMISSION_GRANTED) return;
        requestPermissions(new String[] { Manifest.permission.POST_NOTIFICATIONS }, NOTIFICATION_PERMISSION_REQUEST);
    }

    private class ReminderBridge {
        @JavascriptInterface
        public void sync(String json) {
            runOnUiThread(() -> scheduleReminders(json));
        }
    }

    private void scheduleReminders(String json) {
        AlarmManager alarmManager = (AlarmManager) getSystemService(Context.ALARM_SERVICE);
        SharedPreferences prefs = getSharedPreferences(PREFS_NAME, MODE_PRIVATE);

        Set<String> previousCodes = prefs.getStringSet(PREF_CODES, new HashSet<>());
        for (String codeText : previousCodes) {
            try {
                cancelAlarm(alarmManager, Integer.parseInt(codeText));
            } catch (NumberFormatException ignored) {}
        }

        Set<String> nextCodes = new HashSet<>();
        try {
            JSONArray reminders = new JSONArray(json);
            long now = System.currentTimeMillis();
            for (int index = 0; index < reminders.length(); index++) {
                JSONObject item = reminders.getJSONObject(index);
                long reminderAt = item.optLong("reminderAt");
                if (reminderAt <= now) continue;

                String key = item.optString("id", item.optString("title", "reminder") + reminderAt);
                int requestCode = Math.abs(key.hashCode());
                Intent intent = new Intent(this, ReminderReceiver.class);
                intent.putExtra("title", item.optString("title", "信用卡提醒"));
                intent.putExtra("body", item.optString("meta", "有一条信用卡事项需要处理"));
                intent.putExtra("requestCode", requestCode);

                PendingIntent pendingIntent = PendingIntent.getBroadcast(
                        this,
                        requestCode,
                        intent,
                        PendingIntent.FLAG_UPDATE_CURRENT | PendingIntent.FLAG_IMMUTABLE
                );
                alarmManager.set(AlarmManager.RTC_WAKEUP, reminderAt, pendingIntent);
                nextCodes.add(String.valueOf(requestCode));
            }
        } catch (Exception ignored) {
            return;
        }

        prefs.edit().putStringSet(PREF_CODES, nextCodes).apply();
    }

    private void cancelAlarm(AlarmManager alarmManager, int requestCode) {
        Intent intent = new Intent(this, ReminderReceiver.class);
        PendingIntent pendingIntent = PendingIntent.getBroadcast(
                this,
                requestCode,
                intent,
                PendingIntent.FLAG_NO_CREATE | PendingIntent.FLAG_IMMUTABLE
        );
        if (pendingIntent != null) {
            alarmManager.cancel(pendingIntent);
            pendingIntent.cancel();
        }
    }

    @Override
    protected void onActivityResult(int requestCode, int resultCode, Intent data) {
        super.onActivityResult(requestCode, resultCode, data);
        if (requestCode != FILE_CHOOSER_REQUEST || filePathCallback == null) {
            return;
        }
        Uri[] results = null;
        if (resultCode == RESULT_OK && data != null) {
            Uri uri = data.getData();
            if (uri != null) {
                results = new Uri[] { uri };
            }
        }
        filePathCallback.onReceiveValue(results);
        filePathCallback = null;
    }

    @Override
    public void onBackPressed() {
        if (webView != null && webView.canGoBack()) {
            webView.goBack();
            return;
        }
        super.onBackPressed();
    }
}
