package app.fortis.wear.presentation

import android.content.Context
import java.io.File
import java.io.FileWriter
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

class SensorDataLogger(private val context: Context) {

    private var fileWriter: FileWriter? = null
    private var lastAccelData = floatArrayOf(0f, 0f, 0f)
    private var lastGyroData = floatArrayOf(0f, 0f, 0f)

    fun startLogging(exerciseName: String) {
        try {
            val timestamp = SimpleDateFormat("yyyyMMdd_HHmmss", Locale.getDefault()).format(Date())
            val fileName = "${exerciseName}_${timestamp}.csv"
            val file = File(context.filesDir, fileName)

            fileWriter = FileWriter(file)
            fileWriter?.append("timestamp,ax,ay,az,gx,gy,gz\n")
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    fun stopLogging() {
        try {
            fileWriter?.flush()
            fileWriter?.close()
            fileWriter = null
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    // 두 센서 데이터를 모두 받아 한 줄로 기록
    fun logData(timestamp: Long, accel: FloatArray, gyro: FloatArray) {
        lastAccelData = accel
        lastGyroData = gyro
        try {
            fileWriter?.append("$timestamp,${accel[0]},${accel[1]},${accel[2]},${gyro[0]},${gyro[1]},${gyro[2]}\n")
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }
}