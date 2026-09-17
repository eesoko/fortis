package app.fortis.wear.presentation

import androidx.room.Dao
import androidx.room.Insert
import androidx.room.Query
import kotlinx.coroutines.flow.Flow

// @Dao 어노테이션은 Room에게 이 인터페이스가 데이터베이스 접근 객체(DAO)임을 알려줍니다.
@Dao
interface WorkoutDao {

    // @Insert 어노테이션은 새로운 데이터를 삽입하는 함수임을 나타냅니다.
    // suspend 키워드는 이 함수가 코루틴 내에서 비동기적으로 실행되어야 함을 의미합니다.
    // (데이터베이스 작업은 메인 스레드를 막을 수 있으므로 항상 비동기 처리)
    @Insert
    suspend fun insertSet(workoutSet: WorkoutSet)

    // @Query 어노테이션은 데이터베이스에 직접 질문(쿼리)하는 함수임을 나타냅니다.
    // "SELECT * FROM workout_sets WHERE ..."는 SQL 쿼리문입니다.
    // 오늘의 시작(자정)부터 지금까지의 모든 기록을 시간 순서대로 가져옵니다.
    @Query("SELECT * FROM workout_sets WHERE timestamp >= :todayTimestamp ORDER BY timestamp DESC")
    fun getTodaySets(todayTimestamp: Long): Flow<List<WorkoutSet>>
}