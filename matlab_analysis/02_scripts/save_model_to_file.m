% =========================================================================
% [ SCRIPT ]    : save_model_to_file.m
% [ VERSION ]   : 1.0
% [ AUTHOR ]    : Fortis Project (with Gemini)
% [ DATE ]      : 2025-09-17
%
% [ OVERVIEW ]
%   현재 MATLAB 작업 공간(Workspace)에 있는 모델 변수를
%   지정한 파일 이름으로 '03_models' 폴더에 .mat 파일로 저장합니다.
% =========================================================================

%% --- 설정 (사용자 수정 필요) ---

% 1. 작업 공간에 있는 모델 변수의 '이름'을 따옴표 안에 정확히 입력하세요.
workspace_variable_name = 'myEnsembleModel';

% 2. 저장할 .mat 파일의 '이름'을 따옴표 안에 입력하세요.
%    반드시 '.mat' 확장자를 포함해야 합니다.
output_filename = 'myEnsembleModel_v2.mat';


%% --- 파일 저장 로직 (수정 불필요) ---

fprintf('--- 모델 파일 저장 시작 ---\n');

% 현재 스크립트(02_scripts) 위치를 기준으로 '03_models' 폴더 경로를 설정합니다.
models_folder = '../03_models';

if ~exist(models_folder, 'dir')
    error("'03_models' 폴더를 찾을 수 없습니다. 현재 작업 경로가 '02_scripts'가 맞는지 확인해주세요.");
end

% 저장할 전체 파일 경로를 생성합니다.
full_save_path = fullfile(models_folder, output_filename);

% 작업 공간에 해당 변수가 있는지 확인합니다.
if ~exist(workspace_variable_name, 'var')
    error("작업 공간에 '%s' 변수가 없습니다. 'workspace_variable_name' 설정을 확인해주세요.", workspace_variable_name);
end

% save 함수를 사용하여 지정된 변수를 파일로 저장합니다.
save(full_save_path, workspace_variable_name);

fprintf('성공적으로 모델을 다음 위치에 저장했습니다:\n');
fprintf('>> %s\n', full_save_path);