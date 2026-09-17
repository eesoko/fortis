% =========================================================================
% [ SCRIPT ]    : export_onnx.m (v3 - 올바른 속성 이름 사용)
% [ OVERVIEW ]
%   훈련된 MATLAB 모델(.mat)을 범용 AI 표준 형식인 ONNX(.onnx) 파일로
%   변환하여 안드로이드 프로젝트로 전달하는 자동화 스크립트입니다.
% =========================================================================

disp('>> ONNX 모델 변환 및 배포 스크립트를 시작합니다...');

%% --- ⚙️ 설정 (Configuration) ⚙️ ---
original_model_name = 'mySVMModel.mat'; 

% --- (이하 모든 과정은 100% 자동으로 처리됩니다) ---
original_model_path = fullfile('..', '03_models', original_model_name);
android_project_path = 'C:\Users\SeokHoLee\StudioProjects\Fortis';
output_folder = fullfile(android_project_path, 'app', 'src', 'main', 'assets');

[~, model_base_name, ~] = fileparts(original_model_name);
onnx_output_name = [model_base_name, '.onnx'];
onnx_output_path = fullfile(output_folder, onnx_output_name);

%% --- 1단계: 모델 로드 및 실제 객체 추출 ---
disp(['>> 원본 모델: ', original_model_path, ' 를 로드합니다.']);
s = load(original_model_path);
model_variable_name = fields(s);
model_struct = s.(model_variable_name{1}); % '상자'를 먼저 로드

% --- ▼▼▼ [핵심 수정 1] 상자('model_struct')에서 특징 개수를 먼저 얻어냅니다. ▼▼▼
if isprop(model_struct, 'RequiredVariables')
    num_features = numel(model_struct.RequiredVariables);
    disp(['   - ', num2str(num_features), '개의 특징(feature) 개수를 확인했습니다.']);
else
    error('모델 파일에서 특징 정보(RequiredVariables)를 찾을 수 없습니다.');
end

% 상자 안의 실제 모델 '알맹이'를 꺼냅니다.
if isprop(model_struct, 'ClassificationSVM')
    trained_model = model_struct.ClassificationSVM;
    disp('   - 성공적으로 SVM 모델 객체(알맹이)를 추출했습니다.');
else
    trained_model = model_struct; % 다른 종류의 모델일 경우
end

% 입력 데이터의 형식(크기)을 ONNX에 알려주기 위한 샘플 데이터 생성
sample_input = rand(1, num_features, 'single'); % 타입을 single(float)로 지정

%% --- 2단계: ONNX 파일로 변환 ---
disp(['>> 모델을 ONNX 형식으로 변환합니다: ', onnx_output_path]);

try
    exportONNX(trained_model, onnx_output_path, 'InputData', {sample_input});
    
    disp('   - 성공적으로 ONNX 파일을 생성했습니다.');
    
catch ME
    disp('   - [오류] ONNX 변환에 실패했습니다.');
    disp('     - 오류 메시지:');
    disp(ME.message);
    disp('     - 모델이 ONNX 변환을 지원하는지 확인하세요.');
    return;
end

%% --- 3단계: 확인 ---
if exist(onnx_output_path, 'file')
    disp(['>> ', onnx_output_name, ' 파일이 성공적으로 안드로이드 프로젝트 폴더에 저장되었습니다. ✨']);
else
    disp('>> [실패] 최종 ONNX 파일이 생성되지 않았습니다. 과정을 다시 확인해주세요.');
end