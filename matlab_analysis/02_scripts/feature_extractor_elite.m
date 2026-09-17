% =========================================================================
% [ SCRIPT ]    : feature_extractor_elite.m
% [ VERSION ]   : 2.1
% [ AUTHOR ]    : Fortis Project
% [ DATE ]      : 2025-09-12
%
% [ OVERVIEW ]
%   '손목의 물리' 원칙에 기반한 핵심 정예 특징(Elite Features)을 추출.
%   추가: 중력 정렬 기반 물리 피처(평면성, 기울기, 비대칭, 전환 날카로움 등)
% =========================================================================

clear; clc;

%% --- 1. 경로 설정 및 폴더 선택 ---
[current_script_path, ~, ~] = fileparts(mfilename('fullpath'));
output_folder = fullfile(current_script_path, '..', '01_data', 'processed');
if ~exist(output_folder, 'dir'), mkdir(output_folder); end
input_folder = uigetdir(current_script_path, 'Select the folder containing CSV files');
if isequal(input_folder, 0), disp('User selected Cancel'); return; end

%% --- 2. 파일 스캔 및 테이블 초기화 ---
csv_files = dir(fullfile(input_folder, '*.csv'));
if isempty(csv_files), disp('No CSV files found.'); return; end
feature_table = table();
fprintf('Starting Elite Feature extraction for %d files...\n', length(csv_files));

%% --- 3. 특징 추출 메인 루프 ---
for i = 1:length(csv_files)
    file_name = csv_files(i).name;
    full_path = fullfile(input_folder, file_name);
    fprintf('  - Processing (%d/%d): %s\n', i, length(csv_files), file_name);
    
    try
        data_table = readtable(full_path);

        % --- 입력 컬럼 확인 ---
        req = {'ax','ay','az','gx','gy','gz'};
        if ~all(ismember(req, data_table.Properties.VariableNames))
            error('Required columns missing. Need ax,ay,az,gx,gy,gz');
        end
        
        % --- 원시 신호 ---
        ax = data_table.ax; ay = data_table.ay; az = data_table.az;
        gx = data_table.gx; gy = data_table.gy; gz = data_table.gz;
        N  = height(data_table);
        Fs = 50;                 % 샘플링 주파수(가정)
        t  = (0:N-1).'/Fs;

        % --- 기본 물리량 ---
        accel_mag = sqrt(ax.^2 + ay.^2 + az.^2);
        gyro_mag  = sqrt(gx.^2 + gy.^2 + gz.^2);

        % ==================== 기존 정예 특징 ====================
        % 기둥 1: 자세(Orientation)
        f1_mean_ax = mean(ax); f1_mean_ay = mean(ay); f1_mean_az = mean(az);
        f1_std_ax  = std(ax);  f1_std_ay  = std(ay);  f1_std_az  = std(az);

        % 기둥 2: 궤적(Trajectory)
        f2_rms_gx = rms(gx); f2_rms_gy = rms(gy); f2_rms_gz = rms(gz);
        f2_corr_ax_ay = safe_corr(ax, ay);
        f2_corr_ay_gz = safe_corr(ay, gz);

        % 기둥 3: 주기/강도(Periodicity & Intensity)
        f3_rms_accel_mag  = rms(accel_mag);
        f3_range_accel_mag= range(accel_mag);
        f3_rms_gyro_mag   = rms(gyro_mag);

        [P1, f1] = periodogram(accel_mag, [], [], Fs);
        [~, loc1] = max(P1);     f3_dom_freq_accel = f1(loc1);

        [P2, f2] = periodogram(gyro_mag, [], [], Fs);
        [~, loc2] = max(P2);     f3_dom_freq_gyro  = f2(loc2);

        % 숨겨진 보석: 운동의 질(Quality)
        jx = gradient(ax)*Fs; jy = gradient(ay)*Fs; jz = gradient(az)*Fs;
        jerk_mag = sqrt(jx.^2 + jy.^2 + jz.^2);
        f4_mean_jerk_mag = mean(jerk_mag);
        f4_std_jerk_mag  = std(jerk_mag);
        f4_sma_accel     = mean(abs(ax)+abs(ay)+abs(az));
        f4_sma_gyro      = mean(abs(gx)+abs(gy)+abs(gz));

        % ==================== 추가 물리 핵심 특징 ====================
        % 1) 중력 추정 및 정렬 성분
        g_vec = [mean(ax), mean(ay), mean(az)];
        if norm(g_vec)==0, g_hat = [0 0 1]; else, g_hat = g_vec / norm(g_vec); end
        a = [ax ay az];
        a_par = a * g_hat.';                 % a∥ = a·ĝ
        a_perp_vec = a - a_par.*g_hat;       % a⊥ 벡터
        a_perp = sqrt(sum(a_perp_vec.^2,2)); % |a⊥|

        % 2) 평면성(주 운동면 비)
        var_par  = var(a_par);
        var_perp = var(a_perp);
        f5_plane_ratio = var_par / max(var_par + var_perp, eps);  % 0~1

        % 3) 손목 기울기(워치 z축 대비)
        z_watch = [0 0 1];
        tilt_deg = acosd( max(-1,min(1, g_hat * z_watch.')) );    % 0~180
        f5_tilt_mean = tilt_deg;
        % 기울기 변동(근사): g_hat을 창 없이 전구간 평균으로 잡았으니 변동은 a_par 표준편차로 근사
        f5_tilt_var_proxy = std(a_par);

        % 4) 상·하 비대칭(상승/하강 적분 비, 부호 기반 근사)
        asc = a_par;  asc(asc<0)=0;
        ecc = -a_par; ecc(ecc<0)=0;
        Aasc = trapz(t, asc);  Aecc = trapz(t, ecc);
        f5_asym_BE = Aasc / max(Aecc, eps);  % >1이면 상승 지배

        % 5) 전환 날카로움(저크 피크)
        j_par = gradient(a_par)*Fs;
        f5_turn_sharp = prctile(abs(j_par), 95);   % 상위 분위수로 안정화

        % 6) 회전 휴지 비율(각속도 저역 구간 비)
        Omega0 = deg2rad(10);                      % ≈10°/s
        hold_ratio_omega = mean(gyro_mag < Omega0);
        f5_hold_ratio_w = hold_ratio_omega;

        % 7) 이동 듀티(움직임 존재 비율)
        A0 = 0.15;                                 % g 단위 가정 데이터라면 조정
        move_mask = (abs(a_par) > A0) | (gyro_mag > deg2rad(25));
        f5_duty_move = mean(move_mask);

        % 8) 대략적 분당 반복수(피크 기반 근사)
        [pks, locs] = findpeaks(a_par, 'MinPeakDistance', round(0.5*Fs)); % >=0.5s 간격
        duration_min = N/Fs/60;
        f5_rpm_est = numel(locs) / max(duration_min, eps);

        % 9) 경로 적분(운동량 유사 척도)
        f5_E_accel = trapz(t, abs(a_par)) + trapz(t, a_perp);   % 선형 합
        f5_E_gyro  = trapz(t, gyro_mag);

        % 10) 가속 PCA 1축성(한 축 지배 여부)
        [coeff,~,latent] = pca(a, 'Algorithm','svd','Centered',true);
        evr = latent / sum(latent);
        f5_pca_evr1 = evr(1);   % 1축 설명력

        % 11) 스펙트럴 플랫니스(리듬 날카로움)
        [P_acc, ~] = periodogram(a_par, [], [], Fs);
        sf = geomean(P_acc + eps) / mean(P_acc + eps);
        f5_spec_flat = sf;

        % =============================================================

        % --- 결과 테이블 생성 ---
        feature_row = [ ...
            f1_mean_ax, f1_mean_ay, f1_mean_az, f1_std_ax, f1_std_ay, f1_std_az, ...
            f2_rms_gx, f2_rms_gy, f2_rms_gz, f2_corr_ax_ay, f2_corr_ay_gz, ...
            f3_rms_accel_mag, f3_range_accel_mag, f3_rms_gyro_mag, f3_dom_freq_accel, f3_dom_freq_gyro, ...
            f4_mean_jerk_mag, f4_std_jerk_mag, f4_sma_accel, f4_sma_gyro, ...
            f5_plane_ratio, f5_tilt_mean, f5_tilt_var_proxy, f5_asym_BE, f5_turn_sharp, ...
            f5_hold_ratio_w, f5_duty_move, f5_rpm_est, f5_E_accel, f5_E_gyro, ...
            f5_pca_evr1, f5_spec_flat ...
        ];

        var_names = { ...
            'mean_ax','mean_ay','mean_az','std_ax','std_ay','std_az', ...
            'rms_gx','rms_gy','rms_gz','corr_ax_ay','corr_ay_gz', ...
            'rms_accel_mag','range_accel_mag','rms_gyro_mag','dom_freq_accel','dom_freq_gyro', ...
            'mean_jerk_mag','std_jerk_mag','sma_accel','sma_gyro', ...
            'plane_ratio','tilt_mean_deg','tilt_var_proxy','asym_BE','turn_sharp', ...
            'hold_ratio_omega','duty_move','rpm_est','E_accel','E_gyro', ...
            'pca_evr1','spec_flatness' ...
        };

        temp_table = array2table(feature_row, 'VariableNames', var_names);

        % 파일명에서 종목명 파싱(기존 규칙 유지)
        name_parts = split(file_name, '_');
        temp_table.exerciseName = string(name_parts{1});

        feature_table = [feature_table; temp_table];

    catch ME
        fprintf('Could not process file: %s. Error: %s\n', file_name, ME.message);
    end
end

%% --- 4. 결과 저장 ---
if ~isempty(feature_table)
    timestamp = datestr(now, 'yyyy-mm-dd_HHMMSS');
    output_filename = ['feature_table_elite_', timestamp, '.csv'];
    output_path = fullfile(output_folder, output_filename);
    writetable(feature_table, output_path);
    
    fprintf('\n>> Elite feature extraction complete!\n');
    fprintf('>> Features saved to:\n   %s\n', output_path);
else
    disp('No data was processed.');
end

%% --- 유틸 ---
function r = safe_corr(x,y)
    if numel(x)~=numel(y) || numel(x)<3 || std(x)==0 || std(y)==0
        r = 0;
    else
        C = corrcoef(x,y);
        r = C(1,2);
    end
end
