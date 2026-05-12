package com.example.obdreader2

import android.app.*
import android.bluetooth.BluetoothManager
import android.bluetooth.BluetoothSocket
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder
import android.os.PowerManager
import androidx.core.app.NotificationCompat
import kotlinx.coroutines.*
import java.io.IOException
import java.io.InputStream
import java.util.UUID

class OBDForegroundService : Service() {

    private var wakeLock: PowerManager.WakeLock? = null
    private val serviceScope = CoroutineScope(Dispatchers.IO + SupervisorJob())
    private var connectJob: Job? = null

    @Volatile private var btSocket: BluetoothSocket? = null

    companion object {
        internal const val CHANNEL_ID = "obd_connection"
        internal const val NOTIF_ID   = 1

        private val SPP_UUID = UUID.fromString("00001101-0000-1000-8000-00805F9B34FB")

        @Volatile
        var instance: OBDForegroundService? = null

        fun start(context: Context, deviceAddress: String? = null, deviceName: String? = null) {
            val intent = Intent(context, OBDForegroundService::class.java).apply {
                deviceAddress?.let { putExtra("device_address", it) }
                deviceName?.let  { putExtra("device_name",    it) }
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
        }

        fun stop(context: Context) {
            context.stopService(Intent(context, OBDForegroundService::class.java))
        }
    }

    override fun onCreate() {
        super.onCreate()
        instance = this
        ensureNotificationChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(
                NOTIF_ID,
                buildNotification("ÓE-BD2", "OBD kapcsolat aktív"),
                ServiceInfo.FOREGROUND_SERVICE_TYPE_CONNECTED_DEVICE
            )
        } else {
            startForeground(NOTIF_ID, buildNotification("ÓE-BD2", "OBD kapcsolat aktív"))
        }

        if (wakeLock == null || !wakeLock!!.isHeld) {
            val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
            wakeLock = pm.newWakeLock(
                PowerManager.PARTIAL_WAKE_LOCK,
                "OBDForegroundService::PollWakeLock"
            ).also { it.acquire(4 * 60 * 60 * 1000L /* 4 óra */) }
        }

        val address = intent?.getStringExtra("device_address")
        val name    = intent?.getStringExtra("device_name") ?: "OBD eszköz"
        if (address != null && connectJob?.isActive != true && btSocket == null) {
            connectInBackground(address, name)
        }

        return START_STICKY
    }

    private fun connectInBackground(address: String, deviceName: String) {
        connectJob = serviceScope.launch {
            updateNotification(deviceName, "Csatlakozás...")
            try {
                val btAdapter = (getSystemService(Context.BLUETOOTH_SERVICE) as? BluetoothManager)
                    ?.adapter ?: return@launch

                btAdapter.cancelDiscovery()
                val socket = btAdapter.getRemoteDevice(address)
                    .createRfcommSocketToServiceRecord(SPP_UUID)
                socket.connect()
                btSocket = socket

                val out = socket.outputStream
                val inp = socket.inputStream

                // ELM327 init
                out.write("AT Z\r".toByteArray()); out.flush()
                delay(1200)
                if (!isActive || !socket.isConnected) return@launch

                for (cmd in listOf("AT E0", "AT L0", "AT H0", "AT S0", "AT AL")) {
                    if (!isActive) return@launch
                    out.write("$cmd\r".toByteArray()); out.flush()
                    try {
                        withTimeout(4_000) { readUntilPrompt(inp) }
                    } catch (_: IOException) { break }
                      catch (_: kotlinx.coroutines.TimeoutCancellationException) { break }
                    delay(80)
                }

                if (!isActive) return@launch
                updateNotification(deviceName, "OBD csatlakozva — koppints az adatokhoz")

                // Keep-alive loop
                while (isActive && socket.isConnected) {
                    delay(12_000)
                    if (!isActive) break
                    try {
                        out.write("AT\r".toByteArray()); out.flush()
                        try {
                            withTimeout(4_000) { readUntilPrompt(inp) }
                        } catch (_: kotlinx.coroutines.TimeoutCancellationException) { break }
                    } catch (_: IOException) { break }
                }

            } catch (e: CancellationException) {
                throw e
            } catch (_: Exception) {
                if (!isActive) return@launch
                updateNotification("OBD", "Csatlakozás sikertelen — koppints az újrapróbáláshoz")
            } finally {
                if (btSocket?.isConnected == false) {
                    btSocket?.close()
                    btSocket = null
                }
            }
        }
    }

    private fun readUntilPrompt(inp: InputStream): String {
        val sb = StringBuilder()
        val buf = ByteArray(1)
        while (true) {
            val n = inp.read(buf)
            if (n < 0) break
            sb.append(buf[0].toInt().toChar())
            if (sb.endsWith(">")) break
        }
        return sb.toString()
    }

    fun releaseSocket() {
        connectJob?.cancel()
        btSocket?.close()
        btSocket = null
    }

    private fun updateNotification(title: String, text: String) {
        val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        nm.notify(NOTIF_ID, buildNotification(title, text))
    }

    private fun buildNotification(title: String, text: String): Notification {
        val tapIntent = PendingIntent.getActivity(
            this, 0,
            Intent(this, MainActivity::class.java).apply {
                addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_REORDER_TO_FRONT)
                putExtra("auto_connect_triggered", true)
            },
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle(title)
            .setContentText(text)
            .setSmallIcon(android.R.drawable.stat_sys_data_bluetooth)
            .setContentIntent(tapIntent)
            .setOngoing(true)
            .setSilent(true)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .build()
    }

    private fun ensureNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val nm = getSystemService(NotificationManager::class.java)
            if (nm.getNotificationChannel(CHANNEL_ID) != null) return
            val channel = NotificationChannel(
                CHANNEL_ID,
                "OBD kapcsolat",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Aktív OBD kapcsolat értesítése"
                setShowBadge(false)
            }
            nm.createNotificationChannel(channel)
        }
    }

    override fun onDestroy() {
        instance = null
        connectJob?.cancel()
        btSocket?.close()
        btSocket = null
        serviceScope.cancel()

        wakeLock?.let { if (it.isHeld) it.release() }
        wakeLock = null

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            stopForeground(STOP_FOREGROUND_REMOVE)
        } else {
            @Suppress("DEPRECATION")
            stopForeground(true)
        }
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null
}
