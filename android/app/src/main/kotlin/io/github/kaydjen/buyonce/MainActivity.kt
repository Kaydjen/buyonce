package io.github.kaydjen.buyonce

import android.app.NotificationChannel
import android.app.NotificationManager
import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        createPurchasesChannel()
    }

    // The channel of the push messages (AndroidManifest.xml names it as the default one);
    // it has to exist before a message arrives, and the user can change it in the system
    // settings. Creating it again is harmless.
    private fun createPurchasesChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val channel = NotificationChannel(
            "purchases",
            "Purchases",
            NotificationManager.IMPORTANCE_DEFAULT,
        )
        getSystemService(NotificationManager::class.java).createNotificationChannel(channel)
    }
}
