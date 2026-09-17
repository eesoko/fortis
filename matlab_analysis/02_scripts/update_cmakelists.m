% =========================================================================
% [ SCRIPT ]    : update_cmakelists.m
% [ PURPOSE ]   : features/와 prediction/ 폴더의 .c 파일들을 자동으로
%                 스캔해서 CMakeLists.txt 파일을 생성한다.
%                 - 중복 유틸 파일(prediction 쪽)은 제외
%                 - tmwtypes.h 문제 해결 위해 include path 추가
%                 - OpenMP 라이브러리 자동 링크
% =========================================================================

function update_cmakelists()

    % --- Android Studio cpp 디렉토리 (레포 기준 상대경로) ---
    thisDir  = fileparts(mfilename('fullpath'));   % matlab_analysis/02_scripts
    repoRoot = fullfile(thisDir, '..', '..');
    cppDir   = fullfile(repoRoot, 'wear-app', 'app', 'src', 'main', 'cpp');
    % --- 타겟 서브폴더 ---
    featureDir = fullfile(cppDir, 'features');
    predictionDir = fullfile(cppDir, 'prediction');
    
    % --- 소스 파일 목록 가져오기 ---
    featureFiles = dir(fullfile(featureDir, '*.c'));
    predictionFiles = dir(fullfile(predictionDir, '*.c'));
    
    % --- 중복 유틸 파일 목록 정의 ---
    duplicateNames = { ...
        'insertionsort.c', 'introsort.c', 'minOrMax.c', ...
        'rtGetInf.c', 'rtGetNaN.c', 'rt_nonfinite.c' ...
    };
    
    % --- predictionFiles에서 중복 유틸 제거 ---
    predictionFiles = predictionFiles(~ismember({predictionFiles.name}, duplicateNames));
    
    % --- 출력 파일 ---
    cmakeFile = fullfile(cppDir, 'CMakeLists.txt');
    fid = fopen(cmakeFile, 'w');
    if fid == -1
        error('CMakeLists.txt 파일을 열 수 없습니다: %s', cmakeFile);
    end
    
    % --- 헤더 작성 ---
    fprintf(fid, 'cmake_minimum_required(VERSION 3.10)\n');
    fprintf(fid, 'project(FortisNative LANGUAGES C CXX)\n\n');
    
    fprintf(fid, 'add_library(native-lib SHARED\n');
    fprintf(fid, '    native-lib.cpp\n');
    
    % --- features 소스 추가 ---
    for f = featureFiles'
        fprintf(fid, '    features/%s\n', f.name);
    end
    
    % --- prediction 소스 추가 ---
    for f = predictionFiles'
        fprintf(fid, '    prediction/%s\n', f.name);
    end
    
    fprintf(fid, ')\n\n');
    
    fprintf(fid, 'find_library(log-lib log)\n');
    
    % --- OpenMP 찾기 ---
    fprintf(fid, 'find_package(OpenMP REQUIRED)\n');
    fprintf(fid, 'if(OpenMP_CXX_FOUND)\n');
    fprintf(fid, '    target_link_libraries(native-lib ${log-lib} OpenMP::OpenMP_CXX)\n');
    fprintf(fid, 'else()\n');
    fprintf(fid, '    message(FATAL_ERROR "OpenMP not found")\n');
    fprintf(fid, 'endif()\n\n');
    
    % --- include 경로 추가 (tmwtypes.h 문제 방지) ---
    fprintf(fid, 'target_include_directories(native-lib PRIVATE ${CMAKE_CURRENT_SOURCE_DIR})\n');
    
    fclose(fid);
    
    fprintf('✅ CMakeLists.txt 업데이트 완료: %s\n', cmakeFile);
end
