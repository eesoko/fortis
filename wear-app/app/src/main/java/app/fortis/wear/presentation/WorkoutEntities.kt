package app.fortis.wear.presentation

// 여러 파일에서 함께 사용할 약속(정의)들을 모아두는 곳입니다.

object ExerciseType {
    const val DUMBBELL_CURL = "Dumbbell Curl"
    const val SQUAT = "Squat"
    const val OVERHEAD_PRESS = "Overhead Press"
    const val PUSH_UP = "Push Up"
    const val SIDE_LATERAL_RAISE = "Side Lateral Raise"
    const val LUNGE = "Lunge"
    const val DUMBBELL_ROW = "Dumbbell Row"
}
enum class DumbbellCurlState {
    READY,
    LIFTING,
    LOWERING
}

enum class SquatState {
    READY,
    DESCENDING,
    ASCENDING
}
