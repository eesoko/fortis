% =========================================================================
% [ SCRIPT ]    : generate_cpp.m (v11 - "How To Predict" 완전 반영)
% =========================================================================

disp('>> 최종 빌드 자동화 스크립트를 시작합니다...');

%% --- ⚙️ 설정 (Configuration) ⚙️ ---
original_model_name = 'mySVMModel.mat';

%% --- 1단계: 모델 분석 ---
original_model_path = fullfile('..', '03_models', original_model_name);
disp(['>> 원본 모델: ', original_model_path, ' 를 분석합니다.']);
s = load(original_model_path);
model_variable_name = fields(s);
model_struct = s.(model_variable_name{1}); % c. 즉, 가장 바깥쪽 struct (상자)

% 상자 안의 실제 모델 '알맹이' 추출
known_model_fields = {'ClassificationSVM', 'ClassificationKNN'};
model_object = model_struct;
for i = 1:numel(known_model_fields)
    if isfield(model_struct, known_model_fields{i})
        model_object = model_struct.(known_model_fields{i});
        break;
    end
end
model_class_name = class(model_object);
disp(['>> 모델 타입: ', model_class_name, '을 감지했습니다.']);

%% --- 2단계: 필요한 부품(스크립트) 동적 호출 ---
param_extractor_name_str = ['getParameters_', model_class_name];
predictor_name_str = ['predictExercise_', model_class_name];
param_extractor_func = str2func(param_extractor_name_str);
sensor_data_type = coder.typeof(0, [inf, 6]);

% --- ▼▼▼ [핵심] '재료 준비 파트'에 '상자(model_struct)'와 '알맹이(model_object)'를 모두 전달합니다. ▼▼▼
disp(['   - 파라미터 추출기: ', param_extractor_name_str, '.m 를 호출합니다.']);
final_codegen_args = param_extractor_func(model_struct, model_object, sensor_data_type);

disp(['   - 예측 실행기: ', predictor_name_str, '.m 를 C++로 변환합니다.']);

%% --- 3단계: C++ 코드 생성 ---
cfg = coder.config('lib');
cfg.TargetLang = 'C++';
cfg.GenerateReport = false;
codegen_folder = fullfile(pwd, 'codegen_temp');

codegen(predictor_name_str, '-config', cfg, '-args', final_codegen_args, '-d', codegen_folder);

disp('>> Codegen 실행 완료.');

%% --- 4단계 & 5단계: 파일 복사 및 정리 ---
android_project_path = 'C:\Users\SeokHoLee\StudioProjects\Fortis';
output_folder = fullfile(android_project_path, 'app', 'src', 'main', 'cpp');
source_folder = fullfile(codegen_folder, 'lib', predictor_name_str);

if isfolder(source_folder)
    copyfile(fullfile(source_folder, '*.cpp'), output_folder);
    copyfile(fullfile(source_folder, '*.h'), output_folder);
    disp('>> 모든 C++ 파일이 성공적으로 안드로이드 프로젝트에 복사되었습니다.');
    rmdir(codegen_folder, 's');
    disp('>> 빌드 자동화 스크립트가 성공적으로 완료되었습니다. ✨');
else
    disp('>> [오류] C++ 파일이 생성되지 않았거나 소스 폴더를 찾을 수 없습니다.');
end