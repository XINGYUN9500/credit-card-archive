package cn.creditcard.archive;

import android.app.Notification;
import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.app.PendingIntent;
import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.os.Build;

public class ReminderReceiver extends BroadcastReceiver {
    public static final String CHANNEL_ID = "credit_card_archive_reminders";

    @Override
    public void onReceive(Context context, Intent intent) {
        ensureChannel(context);

        Intent openIntent = new Intent(context, MainActivity.class);
        openIntent.setFlags(Intent.FLAG_ACTIVITY_NEW_TASK | Intent.FLAG_ACTIVITY_CLEAR_TOP);
        PendingIntent openPendingIntent = PendingIntent.getActivity(
                context,
                0,
                openIntent,
                PendingIntent.FLAG_UPDATE_CURRENT | PendingIntent.FLAG_IMMUTABLE
        );

        String title = intent.getStringExtra("title");
        String body = intent.getStringExtra("body");
        int requestCode = intent.getIntExtra("requestCode", 1);

        Notification.Builder builder = Build.VERSION.SDK_INT >= Build.VERSION_CODES.O
                ? new Notification.Builder(context, CHANNEL_ID)
                : new Notification.Builder(context);
        Notification notification = builder
                .setSmallIcon(android.R.drawable.ic_dialog_info)
                .setContentTitle(title == null ? "信用卡提醒" : title)
                .setContentText(body == null ? "有一条信用卡事项需要处理" : body)
                .setStyle(new Notification.BigTextStyle().bigText(body == null ? "" : body))
                .setContentIntent(openPendingIntent)
                .setAutoCancel(true)
                .build();

        NotificationManager manager = (NotificationManager) context.getSystemService(Context.NOTIFICATION_SERVICE);
        manager.notify(requestCode, notification);
    }

    public static void ensureChannel(Context context) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return;
        NotificationManager manager = (NotificationManager) context.getSystemService(Context.NOTIFICATION_SERVICE);
        NotificationChannel channel = new NotificationChannel(
                CHANNEL_ID,
                "信用卡提醒",
                NotificationManager.IMPORTANCE_DEFAULT
        );
        channel.setDescription("账单日、还款日、年费日和活动到期提醒");
        manager.createNotificationChannel(channel);
    }
}
