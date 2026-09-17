package app.fortis.wear.presentation

import androidx.room.Entity
import androidx.room.PrimaryKey

// @Entity 어노테이션은 Room에게 이 클래스를 데이터베이스의 '테이블'로 사용하라고 알려줍니다.
// tableName 속성은 테이블의 이름을 'workout_sets'로 지정합니다.
@Entity(tableName = "workout_sets")
data class WorkoutSet(
    // @PrimaryKey 어노테이션은 'id'를 이 테이블의 고유 식별자(주키)로 지정합니다.
    // autoGenerate = true는 id 값을 1, 2, 3, ... 처럼 자동으로 증가시켜줍니다.
    @PrimaryKey(autoGenerate = true)
    val id: Int = 0,

    val exerciseName: String,
    val reps: Int,
    val timestamp: Long = System.currentTimeMillis() // 기본값으로 현재 시간을 저장
)