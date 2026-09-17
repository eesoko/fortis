package app.fortis.wear.presentation

import kotlinx.coroutines.flow.Flow
import java.util.Calendar

// DAO를 부품으로 받아, 데이터베이스 관련 작업을 처리하는 전문가입니다.
class WorkoutRepository(private val workoutDao: WorkoutDao) {

    // 새로운 세트 기록을 DB에 저장하도록 DAO에게 요청합니다.
    suspend fun insertSet(workoutSet: WorkoutSet) {
        workoutDao.insertSet(workoutSet)
    }

    // 오늘 날짜의 모든 운동 기록을 DB에서 가져오도록 DAO에게 요청합니다.
    fun getTodaySets(): Flow<List<WorkoutSet>> {
        // '오늘'의 기준이 되는 자정(0시 0분 0초) 타임스탬프를 계산합니다.
        val today = Calendar.getInstance().apply {
            set(Calendar.HOUR_OF_DAY, 0)
            set(Calendar.MINUTE, 0)
            set(Calendar.SECOND, 0)
            set(Calendar.MILLISECOND, 0)
        }
        return workoutDao.getTodaySets(today.timeInMillis)
    }
}