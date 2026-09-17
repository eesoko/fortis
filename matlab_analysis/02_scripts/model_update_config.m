% =========================================================================
% [ CONFIG FILE ] : model_update_config.m (Version 2.0)
% =========================================================================

function config = model_update_config()
    % --- 설정 (사용자 수정 필요) ---

    % 1. 새로 내보내기 한 모델 파일의 이름을 입력하세요. (예: 'myEnsembleModel_v1.mat')
    config.new_model_file = 'myEnsembleModel_v2.mat'; 

    % 2. 안드로이드 프로젝트의 cpp/prediction 폴더 (레포 기준 상대경로)
    thisDir  = fileparts(mfilename('fullpath'));   % matlab_analysis/02_scripts
    repoRoot = fullfile(thisDir, '..', '..');
    config.prediction_folder_path = fullfile(repoRoot, 'wear-app', 'app', 'src', 'main', 'cpp', 'prediction');
end