package app.fortis.wear.presentation

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape // 에러 해결 1: RoundedCornerShape import
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.painterResource // 에러 해결 2: painterResource import
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.viewmodel.compose.viewModel
import androidx.wear.compose.foundation.lazy.ScalingLazyColumn
import androidx.wear.compose.foundation.lazy.items
import androidx.wear.compose.foundation.lazy.rememberScalingLazyListState // 에러 해결 3: rememberScalingLazyListState import
import androidx.wear.compose.material.* // 에러 해결 4: Icon 등 Material 컴포넌트를 위해 와일드카드 import
import androidx.wear.compose.navigation.SwipeDismissableNavHost
import androidx.wear.compose.navigation.composable
import androidx.wear.compose.navigation.rememberSwipeDismissableNavController
import app.fortis.wear.R // 에러 해결 5: R.drawable 리소스 사용을 위한 import
import app.fortis.wear.presentation.theme.FortisTheme
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContent {
            val viewModel: MainViewModel = viewModel()
            FortisTheme {
                WearAppNavigation(viewModel = viewModel)
            }
        }
    }
}

@Composable
fun WearAppNavigation(viewModel: MainViewModel) {
    val navController = rememberSwipeDismissableNavController()
    val repCount by viewModel.repCount.collectAsState()
    val todaySets by viewModel.todaySets.collectAsState()

    SwipeDismissableNavHost(
        navController = navController,
        startDestination = "main_screen"
    ) {
        composable("main_screen") {
            // --- ▼▼▼ 수정된 부분 1: MainScreen 호출 방식 변경 ▼▼▼ ---
            MainScreen(
                // "오늘의 운동 기록" 버튼을 누르면 해당 화면으로 이동하도록 연결
                onNavigateToTodayWorkout = {
                    navController.navigate("today_workout_screen")
                },
                // "데이터 수집" 버튼을 누르면 해당 화면으로 이동하도록 연결
                onNavigateToDataCollection = {
                    viewModel.setDataCollectionMode(true) // 데이터 수집 모드 활성화
                    navController.navigate("collection_selection_screen")
                },
                // "운동 시작" 버튼을 누르면 카운터 화면으로 이동하도록 연결
                onNavigateToCounter = { exerciseType ->
                    viewModel.setDataCollectionMode(false) // 카운팅 모드 활성화
                    viewModel.onExerciseSelected(exerciseType)
                    navController.navigate("counter_screen/$exerciseType")
                }
            )
            // --- ▲▲▲ 수정된 부분 1 ---
        }

        composable("today_workout_screen") {
            TodayWorkoutScreen(sets = todaySets)
        }

        composable("collection_selection_screen") {
            ExerciseSelectionScreen { exerciseName ->
                viewModel.onExerciseSelected(exerciseName)
                navController.navigate("logging_screen/$exerciseName")
            }
        }

        composable("logging_screen/{exerciseName}") { backStackEntry ->
            val exerciseName = backStackEntry.arguments?.getString("exerciseName") ?: "기록 중"
            LoggingScreen(
                exerciseName = exerciseName,
                onStopLoggingClick = {
                    viewModel.onWorkoutEnd()
                    navController.popBackStack()
                }
            )
        }

        composable("counter_screen/{exerciseName}") { backStackEntry ->
            val exerciseName = backStackEntry.arguments?.getString("exerciseName") ?: "운동"
            CounterScreen(
                exerciseName = exerciseName,
                count = repCount,
                onSetCompleteClick = {
                    viewModel.onSetComplete()
                },
                onEndWorkoutClick = {
                    viewModel.onWorkoutEnd()
                    navController.popBackStack()
                }
            )
        }
    }
}

// --- ▼▼▼ 수정된 부분 2: MainScreen 전체 재설계 ▼▼▼ ---
@Composable
fun MainScreen(
    onNavigateToTodayWorkout: () -> Unit,
    onNavigateToDataCollection: () -> Unit,
    onNavigateToCounter: (String) -> Unit
) {
    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(horizontal = 16.dp),
        verticalArrangement = Arrangement.Center,
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        Text("Fortis", fontSize = 24.sp, fontWeight = FontWeight.Bold)
        Spacer(modifier = Modifier.height(16.dp))

        // 오늘의 운동 기록 버튼
        Button(
            onClick = onNavigateToTodayWorkout,
            modifier = Modifier.fillMaxWidth(),
            colors = ButtonDefaults.buttonColors(backgroundColor = Color(0xFF0056B3))
        ) {
            // Row를 사용해 가로 정렬을 명확히 합니다.
            Row(verticalAlignment = Alignment.CenterVertically) {
                Icon(
                    painter = painterResource(id = R.drawable.ic_history),
                    contentDescription = "운동 기록"
                )
                Spacer(Modifier.width(8.dp)) // 아이콘과 텍스트 사이 간격
                Text("운동 기록")
            }
        }

        Spacer(modifier = Modifier.height(8.dp))

        // 운동 시작 버튼
        Button(
            onClick = { onNavigateToCounter(ExerciseType.DUMBBELL_CURL) },
            modifier = Modifier.fillMaxWidth(),
            colors = ButtonDefaults.buttonColors(backgroundColor = MaterialTheme.colors.primary)
        ) {
            // Row를 사용해 가로 정렬을 명확히 합니다.
            Row(verticalAlignment = Alignment.CenterVertically) {
                Icon(
                    painter = painterResource(id = R.drawable.ic_fitness),
                    contentDescription = "운동 시작"
                )
                Spacer(Modifier.width(8.dp)) // 아이콘과 텍스트 사이 간격
                Text("운동 시작")
            }
        }

        Spacer(modifier = Modifier.height(8.dp))

        // 데이터 수집 버튼
        Button(
            onClick = onNavigateToDataCollection,
            modifier = Modifier.fillMaxWidth(),
            colors = ButtonDefaults.buttonColors(backgroundColor = Color.DarkGray)
        ) {
            // Row를 사용해 가로 정렬을 명확히 합니다.
            Row(verticalAlignment = Alignment.CenterVertically) {
                Icon(
                    painter = painterResource(id = R.drawable.ic_data_collect),
                    contentDescription = "데이터 수집"
                )
                Spacer(Modifier.width(8.dp)) // 아이콘과 텍스트 사이 간격
                Text("데이터 수집")
            }
        }
    }
}
// --- ▲▲▲ 수정된 부분 2 ---

@Composable
fun CounterScreen(
    exerciseName: String,
    count: Int,
    onSetCompleteClick: () -> Unit,
    onEndWorkoutClick: () -> Unit
) {
    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(16.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.SpaceAround
    ) {
        Text(text = exerciseName, fontSize = 22.sp, textAlign = TextAlign.Center)
        Text(text = count.toString(), fontSize = 72.sp, fontWeight = FontWeight.Bold)
        Column {
            Button(
                onClick = onSetCompleteClick,
                modifier = Modifier.fillMaxWidth()
            ) {
                Text("세트 종료 (저장)")
            }
            Spacer(modifier = Modifier.height(8.dp))
            Button(
                onClick = onEndWorkoutClick,
                colors = ButtonDefaults.buttonColors(backgroundColor = MaterialTheme.colors.error),
                modifier = Modifier.fillMaxWidth()
            ) {
                Text("전체 운동 종료")
            }
        }
    }
}

@Composable
fun TodayWorkoutScreen(sets: List<WorkoutSet>) {
    ScalingLazyColumn(
        modifier = Modifier.fillMaxSize(),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(8.dp)
    ) {
        item {
            Text(
                text = "오늘의 운동 기록",
                style = MaterialTheme.typography.title1,
                modifier = Modifier.padding(bottom = 16.dp)
            )
        }
        if (sets.isEmpty()) {
            item {
                Text(
                    text = "아직 저장된 기록이 없습니다.",
                    modifier = Modifier.padding(top = 24.dp)
                )
            }
        } else {
            items(sets) { set ->
                val timeFormat = SimpleDateFormat("HH:mm:ss", Locale.getDefault())
                val timeString = timeFormat.format(Date(set.timestamp))

                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Column(modifier = Modifier.weight(1f)) {
                        Text(text = set.exerciseName, fontWeight = FontWeight.Bold)
                        Text(text = timeString, fontSize = 12.sp, color = Color.Gray)
                    }
                    Text(text = "${set.reps} 회", fontSize = 20.sp)
                }
            }
        }
    }
}

// --- ▼▼▼ 수정된 부분 3: ExerciseSelectionScreen 재설계 ▼▼▼ ---
@Composable
fun ExerciseSelectionScreen(onExerciseSelected: (String) -> Unit) {
    val listState = rememberScalingLazyListState() // 에러 해결 7: state 변수 추가
    ScalingLazyColumn(
        modifier = Modifier.fillMaxSize(),
        state = listState, // 에러 해결 8: state 연결
        // 에러 해결 9: autoScrollToCentralItem -> autoCentering 파라미터로 변경 시도 (없으면 삭제)
        // autoCentering = AutoCenteringParams(itemIndex = 0), // 라이브러리 버전에 따라 없을 수 있음
        contentPadding = PaddingValues(top = 30.dp, bottom = 30.dp)
    ) {
        item { Text(text = "수집할 운동 선택", modifier = Modifier.padding(bottom = 8.dp)) }

        item { ExerciseButton(exerciseType = ExerciseType.SQUAT) { onExerciseSelected(it) } }
        item { ExerciseButton(exerciseType = ExerciseType.OVERHEAD_PRESS) { onExerciseSelected(it) } }
        item { ExerciseButton(exerciseType = ExerciseType.PUSH_UP) { onExerciseSelected(it) } }
        item { ExerciseButton(exerciseType = ExerciseType.SIDE_LATERAL_RAISE) { onExerciseSelected(it) } }
        item { ExerciseButton(exerciseType = ExerciseType.DUMBBELL_CURL) { onExerciseSelected(it) } }
        item { ExerciseButton(exerciseType = ExerciseType.LUNGE) { onExerciseSelected(it) } }
        item { ExerciseButton(exerciseType = ExerciseType.DUMBBELL_ROW) { onExerciseSelected(it) } }
    }
}

@Composable
fun ExerciseButton(exerciseType: String, onClick: (String) -> Unit) {
    Button(
        onClick = { onClick(exerciseType) },
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 8.dp),
        // 에러 해결 10: containerColor -> backgroundColor
        colors = ButtonDefaults.buttonColors(backgroundColor = Color.DarkGray),
        shape = RoundedCornerShape(12.dp) // 모서리 둥글게
    ) {
        Text(exerciseType, fontSize = 16.sp)
    }
}
// --- ▲▲▲ 수정된 부분 3 ---

@Composable
fun LoggingScreen(exerciseName: String, onStopLoggingClick: () -> Unit) {
    Column(
        modifier = Modifier.fillMaxSize(),
        verticalArrangement = Arrangement.Center,
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        Text(text = exerciseName, fontSize = 24.sp)
        Text(text = "데이터 기록 중...", fontSize = 20.sp, color = Color.Green)
        Spacer(modifier = Modifier.height(20.dp))
        Button(
            onClick = onStopLoggingClick,
            colors = ButtonDefaults.buttonColors(backgroundColor = MaterialTheme.colors.error)
        ) {
            Text("기록 중지")
        }
    }
}