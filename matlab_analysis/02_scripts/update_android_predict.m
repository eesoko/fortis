% =========================================================================
% [ SCRIPT ]    : update_android_predict.m
% [ VERSION ]   : 5.1 (Final Simplified Version)
% [ AUTHOR ]    : Fortis Project (with Gemini)
% [ DATE ]      : 2025-09-18
%
% [ OVERVIEW ]
%   'model_update_config.m' 파일의 설정을 읽어, 새로운 예측 모델을
%   C코드로 변환한 뒤, 안드로이드 'prediction' 폴더의 내용물을
%   자동으로 교체하는 최종 스크립트.
% =========================================================================

clear; clc;

%% --- 1. 설정 파일 로드 ---
fprintf('--- 1. 설정 파일 로드 시작 ---\n');
if ~exist('model_update_config.m', 'file')
    error("'model_update_config.m' 파일을 찾을 수 없습니다.");
end
config = model_update_config();
fprintf('  > 모델 파일: %s\n', config.new_model_file);
fprintf('  > 타겟 폴더: %s\n', config.prediction_folder_path);
fprintf('--- 설정 로드 완료 ---\n\n');


%% --- 2. 새로운 예측 C/C++ 코드 생성 ---
fprintf('--- 2. 새로운 예측 C/C++ 코드 생성 시작 ---\n');

% 2-1. 'cleanModel.mat' 생성 (모델 객체 자동 감지)
fprintf('  > 2-1. 모델 파일 분석 및 "cleanModel.mat" 생성 중...\n');
model_file_path = fullfile('..', '03_models', config.new_model_file);
if ~exist(model_file_path, 'file')
    error("모델 파일 '%s'을(를) '03_models' 폴더에서 찾을 수 없습니다.", config.new_model_file);
end

file_vars = whos('-file', model_file_path);
if isempty(file_vars)
    error("모델 파일 '%s'이(가) 비어있습니다.", config.new_model_file);
end

top_level_var_name = file_vars(1).name;
original_data = load(model_file_path);
model_struct = original_data.(top_level_var_name);

model_fields = fieldnames(model_struct);
actual_model_field_name = '';
for i = 1:length(model_fields)
    field_name = model_fields{i};
    if ~contains(field_name, {'Fcn', 'Variables', 'About', 'HowToPredict'})
        actual_model_field_name = field_name;
        break;
    end
end

if isempty(actual_model_field_name)
    error("모델 구조체 내부에서 실제 모델 객체를 자동으로 찾지 못했습니다.");
end

actual_model = model_struct.(actual_model_field_name);
fprintf('    - 모델 객체 자동 감지 완료: %s.%s\n', top_level_var_name, actual_model_field_name);
save('cleanModel.mat', 'actual_model', '-v7.3');
fprintf('    - "cleanModel.mat" 생성 완료.\n');

% 2-2. C/C++ 코드 생성
fprintf('  > 2-2. C/C++ 코드 생성 중...\n');
codegen_folder = fullfile(pwd, 'codegen');
if exist(codegen_folder, 'dir')
    rmdir(codegen_folder, 's');
end
sample_input = coder.typeof(double(0), [1, 32], [0, 0]);
codegen predict_exercise_index -config coder.config('lib') -args {sample_input};
fprintf('    - 예측 관련 C/C++ 코드 생성 완료.\n\n');


%% --- 3. 안드로이드 'prediction' 폴더 업데이트 ---
fprintf('--- 3. 안드로이드 "prediction" 폴더 업데이트 시작 ---\n');
predict_codegen_path = fullfile(codegen_folder, 'lib', 'predict_exercise_index');
if ~exist(config.prediction_folder_path, 'dir')
    error("타겟 폴더 '%s'를 찾을 수 없습니다. 경로를 확인해주세요.", config.prediction_folder_path);
end

% 3-1. 기존 prediction 폴더 내용물 삭제
fprintf('  > 3-1. 기존 "prediction" 폴더 내용물 삭제 중...\n');
delete(fullfile(config.prediction_folder_path, '*.*'));
fprintf('    - 내용물 삭제 완료.\n');

% 3-2. 새로 생성된 .c 와 .h 파일만 복사
fprintf('  > 3-2. 새로운 .c, .h 파일 복사 중...\n');
copyfile(fullfile(predict_codegen_path, '*.c'), config.prediction_folder_path);
copyfile(fullfile(predict_codegen_path, '*.h'), config.prediction_folder_path);
fprintf('    - 파일 복사 완료.\n');


fprintf('\n*** 모든 과정이 성공적으로 완료되었습니다! ***\n');
fprintf('이제 안드로이드 스튜디오에서 "Sync Now"를 누르고 빌드하세요.\n');