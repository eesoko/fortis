package app.fortis.wear.presentation

import android.app.Application
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.launch

class MainViewModel(application: Application) : AndroidViewModel(application) {

    // --- 1. 화면에 직접적으로 관련된 상태 변수들 ---
    private val _repCount = MutableStateFlow(0)
    val repCount = _repCount.asStateFlow()

    private val _currentExercise = MutableStateFlow<String?>(null)
    val currentExercise = _currentExercise.asStateFlow()

    private val _isDataCollectionMode = MutableStateFlow(false)

    // --- 2. ViewModel이 사용할 전문가(Repository)들을 먼저 명확하게 생성 ---
    // 모든 부품을 lateinit 없이 즉시! 순서대로! 만듭니다.
    private val sensorRepository = SensorRepository(application)
    private val workoutRepository: WorkoutRepository

    // --- 3. 화면에 보여줄 '오늘의 운동 기록' ---
    // 이제 workoutRepository가 이미 완성되어 있으므로, todaySets를 바로 만들 수 있습니다.
    val todaySets: StateFlow<List<WorkoutSet>>

    init {
        // init 블록은 이제 부품을 '조립'하고 '연결'하는 역할에만 집중합니다.

        // 1. DB 전문가 생성
        val workoutDao = AppDatabase.getDatabase(application).workoutDao()
        workoutRepository = WorkoutRepository(workoutDao)

        // 2. 생성된 DB 전문가를 이용해 실시간 데이터 흐름 생성
        todaySets = workoutRepository.getTodaySets().stateIn(
            scope = viewModelScope,
            started = SharingStarted.WhileSubscribed(5000L),
            initialValue = emptyList()
        )

        // 3. 센서 전문가에게 할 일 부여
        sensorRepository.onRepDetected = {
            _repCount.value++
        }
    }

    // --- 이하 함수들은 변경 없음 ---

    fun setDataCollectionMode(isCollecting: Boolean) {
        _isDataCollectionMode.value = isCollecting
    }

    fun onExerciseSelected(exerciseType: String) {
        _currentExercise.value = exerciseType
        _repCount.value = 0
        sensorRepository.startListening(exerciseType, _isDataCollectionMode.value)
    }

    fun onWorkoutEnd() {
        sensorRepository.stopListening()
        _currentExercise.value = null
    }

    fun onSetComplete() {
        val exercise = _currentExercise.value ?: return
        val reps = _repCount.value
        if (reps == 0) return

        viewModelScope.launch {
            val newSet = WorkoutSet(
                exerciseName = exercise,
                reps = reps
            )
            workoutRepository.insertSet(newSet)
            _repCount.value = 0
        }
    }
}