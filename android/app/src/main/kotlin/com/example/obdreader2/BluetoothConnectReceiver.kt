package com.example.obdreader2

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.bluetooth.BluetoothDevice
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import androidx.core.app.NotificationCompat

class BluetoothConnectReceiver : BroadcastReceiver() {

    companion object {
        private const val AUTO_NOTIF_CHANNEL = "obd_auto_connect"
        private const val AUTO_NOTIF_ID      = 50
    }

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != BluetoothDevice.ACTION_ACL_CONNECTED) return

        val device: BluetoothDevice? = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            intent.getParcelableExtra(BluetoothDevice.EXTRA_DEVICE, BluetoothDevice::class.java)
        } else {
            @Suppress("DEPRECATION")
            intent.getParcelableExtra(BluetoothDevice.EXTRA_DEVICE)
        }

        val connectedAddress = device?.address ?: return

        val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        val autoConnect  = prefs.getBoolean("flutter.autoConnectEnabled", false)
        val savedAddress = prefs.getString("flutter.lastDeviceAddress", "") ?: ""
        val deviceName   = prefs.getString("flutter.lastDeviceName", "OBD eszköz") ?: "OBD eszköz"
        val connType     = prefs.getString("flutter.lastConnectionType", "classic") ?: "classic"

        if (!autoConnect || savedAddress.isEmpty()) return
        if (connectedAddress != savedAddress) return

        OBDForegroundService.start(
            context,
            deviceAddress = if (connType == "classic") connectedAddress else null,
            deviceName    = deviceName,
        )
        showAutoConnectNotification(context, deviceName, connectedAddress)
    }

    private fun showAutoConnectNotification(
        context: Context,
        deviceName: String,
        address: String
    ) {
        ensureAutoConnectChannel(context)

        val tapIntent = PendingIntent.getActivity(
            context, 0,
            Intent(context, MainActivity::class.java).apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
                putExtra("auto_connect_triggered", true)
                putExtra("device_address", address)
            },
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )

        val notif = NotificationCompat.Builder(context, AUTO_NOTIF_CHANNEL)
            .setSmallIcon(android.R.drawable.stat_sys_data_bluetooth)
            .setContentTitle("OBD eszköz csatlakozott")
            .setContentText("$deviceName — koppints az adatok megtekintéséhez")
            .setContentIntent(tapIntent)
            .setAutoCancel(true)
            .setPriority(NotificationCompat.PRIORITY_DEFAULT)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .build()

        val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        nm.notify(AUTO_NOTIF_ID, notif)
    }

    private fun ensureAutoConnectChannel(context: Context) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val nm = context.getSystemService(NotificationManager::class.java)
            if (nm.getNotificationChannel(AUTO_NOTIF_CHANNEL) != null) return
            val channel = NotificationChannel(
                AUTO_NOTIF_CHANNEL,
                "OBD automatikus csatlakozás",
                NotificationManager.IMPORTANCE_DEFAULT
            ).apply {
                description = "Értesítés OBD eszköz csatlakozásakor"
                setShowBadge(false)
            }
            nm.createNotificationChannel(channel)
        }
    }
}
