package app.fortis.wear.presentation

import android.content.Context
import androidx.room.Database
import androidx.room.Room
import androidx.room.RoomDatabase

// @Database 어노테이션은 이 클래스가 Room 데이터베이스 공장임을 선언합니다.
// entities 배열에는 이 데이터베이스에 포함될 모든 테이블(@Entity 클래스) 목록을 알려줍니다.
// version은 데이터베이스의 버전입니다. 나중에 테이블 구조를 변경할 때 이 숫자를 올려야 합니다.
@Database(entities = [WorkoutSet::class], version = 1)
abstract class AppDatabase : RoomDatabase() {

    // 이 데이터베이스가 어떤 DAO(관리자)들을 가지고 있는지 알려줍니다.
    abstract fun workoutDao(): WorkoutDao

    companion object {
        // @Volatile 어노테이션은 INSTANCE 변수가 모든 스레드에서 항상 최신 값을 갖도록 보장합니다.
        @Volatile
        private var INSTANCE: AppDatabase? = null

        // 데이터베이스 인스턴스를 가져오는 함수입니다. (Singleton 패턴)
        // 앱 전체에서 단 하나의 데이터베이스 인스턴스만 생성되도록 보장합니다.
        fun getDatabase(context: Context): AppDatabase {
            return INSTANCE ?: synchronized(this) {
                val instance = Room.databaseBuilder(
                    context.applicationContext,
                    AppDatabase::class.java,
                    "fortis_database" // 데이터베이스 파일의 이름
                ).build()
                INSTANCE = instance
                instance
            }
        }
    }
}