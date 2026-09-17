% =========================================================================
% [ SCRIPT ]    : update_android_model.m
% [ VERSION ]   : 3.0 (Smart Auto-Detection Version)
% [ AUTHOR ]    : Fortis Project (with Gemini)
% [ DATE ]      : 2025-09-17
%
% [ OVERVIEW ]
%   'model_update_config.m' 파일의 설정을 읽어, .mat 파일 내부를
%   자동으로 분석하여 모델 변수 이름을 찾고, 안드로이드 프로젝트에
%   자동으로 이식하는 최종 자동화 스크립트.
% =========================================================================

clear; clc;

%% --- 설정 파일 로드 ---

fprintf('--- 설정 파일 로드 시작 ---\n');
if ~exist('model_update_config.m', 'file')
    error("'model_update_config.m' 파일을 찾을 수 없습니다. 설정 파일을 먼저 생성해주세요.");
end
config = model_update_config();
fprintf('  > 모델: %s\n', config.new_model_file);
fprintf('  > 경로: %s\n', config.android_cpp_path);
fprintf('--- 설정 파일 로드 완료 ---\n\n');


%% --- 1단계: 새로운 C/C++ 코드 생성 ---

fprintf('--- 1단계: 새로운 C/C++ 코드 생성 시작 ---\n');

% 1-1. '깨끗한' 모델 파일 생성 (모델 변수 이름 자동 감지)
fprintf('  > 1-1. 새로운 모델 파일 (%s) 자동 분석 및 정리 중...\n', config.new_model_file);

model_file_path = fullfile('..', '03_models', config.new_model_file);
if ~exist(model_file_path, 'file')
    error("모델 파일 '%s'을(를) '03_models' 폴더에서 찾을 수 없습니다.", config.new_model_file);
end

% .mat 파일 내부 변수 정보 읽기
file_vars = whos('-file', model_file_path);
if isempty(file_vars)
    error("모델 파일 '%s'이(가) 비어있거나 변수를 포함하고 있지 않습니다.", config.new_model_file);
end

% .mat 파일 안에 있는 struct 변수 이름 찾기
found_model_var = false;
for i = 1:length(file_vars)
    if strcmp(file_vars(i).class, 'struct')
        top_level_var_name = file_vars(i).name;
        found_model_var = true;
        break;
    end
end
if ~found_model_var
    error("모델 파일에서 struct 형태의 모델 변수를 찾지 못했습니다.");
end

original_data = load(model_file_path);
model_struct = original_data.(top_level_var_name);

% struct 내부에서 실제 모델 객체 필드 이름 찾기
model_fields = fieldnames(model_struct);
found_model_obj = false;
for i = 1:length(model_fields)
    field_name = model_fields{i};
    % 일반적으로 모델 객체는 predictFcn 같은 필드를 가지지 않음
    if ~contains(field_name, 'Fcn') && ~contains(field_name, 'Variables')
        actual_model_field_name = field_name;
        found_model_obj = true;
        break;
    end
end
if ~found_model_obj
    error("모델 구조체 내부에서 실제 모델 객체(예: ClassificationSVM)를 찾지 못했습니다.");
end

% 최종 모델 객체 추출
actual_model = model_struct.(actual_model_field_name);
fprintf('    - 모델 변수 자동 감지 완료: %s.%s\n', top_level_var_name, actual_model_field_name);

save('cleanModel.mat', 'actual_model', '-v7.3');
fprintf('    - "cleanModel.mat" 파일 생성 완료.\n');

% ... (이하 코드 생성 및 파일 복사/업데이트 로직은 이전과 동일) ...

% 1-2. C/C++ 코드 생성
fprintf('  > 1-2. C/C++ 코드 생성 중...\n');
codegen_folder = fullfile(pwd, 'codegen');
if exist(codegen_folder, 'dir')
    rmdir(codegen_folder, 's');
end
sample_input = coder.typeof(double(0), [1, 32], [0, 0]);
codegen predict_exercise -config coder.config('lib') -args {sample_input} -report -nargout 0;
fprintf('    - C/C++ 코드 생성 완료.\n');


%% --- 2단계: 안드로이드 프로젝트 파일 업데이트 ---

fprintf('--- 2단계: 안드로이드 프로젝트 파일 업데이트 시작 ---\n');

predict_codegen_path = fullfile(codegen_folder, 'lib', 'predict_exercise');
if ~exist(predict_codegen_path, 'dir')
    error('코드 생성 폴더를 찾을 수 없습니다. 1단계가 실패했을 수 있습니다.');
end

predict_files_struct = dir(predict_codegen_path);
predict_filenames = {predict_files_struct.name};
predict_filenames = predict_filenames(~ismember(predict_filenames, {'.', '..', 'examples', 'html'}));

fprintf('  > 2-1. 기존 예측 관련 파일 삭제 중...\n');
for i = 1:length(predict_filenames)
    target_file = fullfile(config.android_cpp_path, predict_filenames{i});
    if exist(target_file, 'file') && ~strcmp(predict_filenames{i}, 'tmwtypes.h')
        delete(target_file);
    end
end
fprintf('    - 기존 파일 삭제 완료.\n');

fprintf('  > 2-2. 새로운 예측 관련 파일 복사 중...\n');
for i = 1:length(predict_filenames)
    source_file = fullfile(predict_codegen_path, predict_filenames{i});
    copyfile(source_file, config.android_cpp_path);
end
fprintf('    - 새로운 파일 복사 완료.\n');

fprintf('  > 2-3. CMakeLists.txt 파일 자동 업데이트 중...\n');
cmake_path = fullfile(config.android_cpp_path, 'CMakeLists.txt');
cmake_content = fileread(cmake_path);

cmake_lines = strsplit(cmake_content, '\n');
predict_files_c = predict_filenames(endsWith(predict_filenames, '.c'));

start_lib_idx = find(contains(cmake_lines, 'add_library('), 1);
end_lib_idx = find(contains(cmake_lines, ')'), 1, 'last');

% CMakeLists.txt에서 add_library 섹션 내의 모든 .c 파일 목록을 가져옴
existing_c_files = {};
for i = (start_lib_idx + 1):end_lib_idx
    line = strtrim(cmake_lines{i});
    if endsWith(line, '.c') || endsWith(line, '.cpp')
        existing_c_files{end+1} = line;
    end
end

% 기존 예측 파일 목록을 식별 (predict_exercise.c와 관련된 모든 파일)
% predict_exercise.c 자체가 예측의 시작점이므로, 이것과 관련된 파일들을 제거
% 여기서는 간단하게, feature_extractor_codegen 관련 파일과 native-lib.cpp를 제외한
% 나머지를 예측 관련으로 간주하고 교체하는 방식을 사용
essential_files = {'native-lib.cpp', 'feature_extractor_codegen.c', 'feature_extractor_codegen_data.c', ...
                   'feature_extractor_codegen_emxutil.c', 'feature_extractor_codegen_initialize.c', ...
                   'feature_extractor_codegen_terminate.c'}; % 이 파일들은 유지
                   
non_predict_files = intersect(existing_c_files, essential_files);

% 새로운 전체 파일 목록 생성
new_c_file_list = [non_predict_files, predict_files_c];
new_c_file_list = unique(new_c_file_list, 'stable'); % 중복 제거 및 순서 유지

% CMakeLists.txt 재구성
new_cmake_lines = cmake_lines(1:start_lib_idx);
for i = 1:length(new_c_file_list)
    new_cmake_lines{end+1} = ['    ' new_c_file_list{i}];
end
new_cmake_lines = [new_cmake_lines, cmake_lines(end_lib_idx:end)'];

new_cmake_content = strjoin(new_cmake_lines, '\n');

fid = fopen(cmake_path, 'w');
fprintf(fid, '%s', new_cmake_content);
fclose(fid);
fprintf('    - CMakeLists.txt 업데이트 완료.\n');


fprintf('\n*** 모든 과정이 성공적으로 완료되었습니다! ***\n');
fprintf('이제 안드로이드 스튜디오에서 "Sync Now"를 누르고 빌드하세요.\n');