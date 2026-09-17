% ===========================================================================
% [ SCRIPT ]    : feature_extractor_codegen.m
% [ VERSION ]   : 3.0
% [ AUTHOR ]    : Fortis Project (Adapted by Gemini and gpt)
% [ DATE ]      : 2025-09-19
%
% [ OVERVIEW ]
%   'feature_extractor_elite.m'에서 C++ 코드 생성이 가능한 순수 계산
%   로직만을 추출한 버전. 파일 입출력, UI, 지원되지 않는 함수 제거.
%   샘플링 주파수(Fs)를 동적 입력으로 받아 처리하도록 수정됨.
%
%
% === 1. 입력 타입 정의 ===
%   INPUT_ARGS = {coder.typeof(0, [Inf, 6], [1, 0]), coder.typeof(0)};
% === 2. 설정 객체 생성 ===
%   cfg = coder.config('lib');        % 정적/동적 라이브러리 생성용 설정
%   cfg.GenerateReport = true;        % 코드 생성 리포트 만들기
%   cfg.EnableOpenMP = false;         % OpenMP 끄기 (JNI 빌드에서 충돌 방지)
% === 3. 타겟 하드웨어 및 코드 생성 설정 ===
%   cfg.HardwareImplementation.ProdHWDeviceType = 'Generic->MATLAB Host Computer';
% === 4. 코드 생성 실행 ===
%   codegen feature_extractor_codegen -args INPUT_ARGS -config cfg -lang:c
%   -report
%
% ===========================================================================
function features = feature_extractor_codegen(raw_data, Fs_actual)
%#codegen % 이 함수가 코드 생성을 위한 함수임을 명시합니다.

% --- 0. 입력 및 상수 정의 ---
ax = raw_data(:,1); ay = raw_data(:,2); az = raw_data(:,3);
gx = raw_data(:,4); gy = raw_data(:,5); gz = raw_data(:,6);
N  = size(raw_data, 1);
Fs = Fs_actual;
t  = (0:N-1).'/Fs;

% 출력 변수의 크기를 1x32로 미리 고정합니다.
features = zeros(1, 32);

% --- 기본 물리량 ---
accel_mag = sqrt(ax.^2 + ay.^2 + az.^2);
gyro_mag  = sqrt(gx.^2 + gy.^2 + gz.^2);

% ==================== 기존 정예 특징 ====================
% 기둥 1: 자세(Orientation)
f1_mean_ax = mean(ax); f1_mean_ay = mean(ay); f1_mean_az = mean(az);
f1_std_ax  = std(ax);  f1_std_ay  = std(ay);  f1_std_az  = std(az);

% 기둥 2: 궤적(Trajectory)
f2_rms_gx = rms(gx); f2_rms_gy = rms(gy); f2_rms_gz = rms(gz);
f2_corr_ax_ay = safe_corr_codegen(ax, ay);
f2_corr_ay_gz = safe_corr_codegen(ay, gz);

% 기둥 3: 주기/강도(Periodicity & Intensity)
f3_rms_accel_mag  = rms(accel_mag);
if isempty(accel_mag)
    f3_range_accel_mag = 0;
else
    f3_range_accel_mag = max(accel_mag) - min(accel_mag);
end
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
g_norm = norm(g_vec);
if g_norm==0, g_hat = [0 0 1]; else, g_hat = g_vec / g_norm; end
a = [ax ay az];
a_par = a * g_hat.';
a_perp_vec = a - a_par.*g_hat;
a_perp = sqrt(sum(a_perp_vec.^2,2));

% 2) 평면성(주 운동면 비)
var_par  = var(a_par);
var_perp = var(a_perp);
f5_plane_ratio = var_par / max(var_par + var_perp, eps);

% 3) 손목 기울기(워치 z축 대비)
z_watch = [0 0 1];
tilt_deg = acosd( max(-1,min(1, g_hat * z_watch.')) );
f5_tilt_mean = tilt_deg;
f5_tilt_var_proxy = std(a_par);

% 4) 상·하 비대칭
asc = a_par;  asc(asc<0)=0;
ecc = -a_par; ecc(ecc<0)=0;
Aasc = trapz(t, asc);  Aecc = trapz(t, ecc);
f5_asym_BE = Aasc / max(Aecc, eps);

% 5) 전환 날카로움
j_par = gradient(a_par)*Fs;
if isempty(j_par)
    f5_turn_sharp = 0;
else
    sorted_j_par = sort(abs(j_par));
    index = ceil(0.95 * length(sorted_j_par));
    f5_turn_sharp = sorted_j_par(index);
end

% 6) 회전 휴지 비율
Omega0 = deg2rad(10);
hold_ratio_omega = mean(gyro_mag < Omega0);
f5_hold_ratio_w = hold_ratio_omega;

% 7) 이동 듀티
A0 = 0.15;
move_mask = (abs(a_par) > A0) | (gyro_mag > deg2rad(25));
f5_duty_move = mean(move_mask);

% 8) 대략적 분당 반복수
[~, locs] = findpeaks(a_par, 'MinPeakDistance', round(0.5*Fs));
duration_min = N/Fs/60;
f5_rpm_est = numel(locs) / max(duration_min, eps);

% 9) 경로 적분
f5_E_accel = trapz(t, abs(a_par)) + trapz(t, a_perp);
f5_E_gyro  = trapz(t, gyro_mag);

% 10) 가속 PCA 1축성
[~,~,latent] = pca(a, 'Algorithm','svd','Centered',true);
sum_latent = sum(latent);
if sum_latent == 0, evr1 = 0; else, evr1 = latent(1) / sum_latent; end
f5_pca_evr1 = evr1;

% 11) 스펙트럴 플랫니스
[P_acc, ~] = periodogram(a_par, [], [], Fs);
sf = geomean(P_acc + eps) / mean(P_acc + eps);
f5_spec_flat = sf;

% ==================== 최종 특징 벡터 할당 ====================
features(1) = f1_mean_ax; features(2) = f1_mean_ay; features(3) = f1_mean_az;
features(4) = f1_std_ax; features(5) = f1_std_ay; features(6) = f1_std_az;
features(7) = f2_rms_gx; features(8) = f2_rms_gy; features(9) = f2_rms_gz;
features(10) = f2_corr_ax_ay; features(11) = f2_corr_ay_gz;
features(12) = f3_rms_accel_mag; features(13) = f3_range_accel_mag;
features(14) = f3_rms_gyro_mag; features(15) = f3_dom_freq_accel;
features(16) = f3_dom_freq_gyro; features(17) = f4_mean_jerk_mag;
features(18) = f4_std_jerk_mag; features(19) = f4_sma_accel;
features(20) = f4_sma_gyro; features(21) = f5_plane_ratio;
features(22) = f5_tilt_mean; features(23) = f5_tilt_var_proxy;
features(24) = f5_asym_BE; features(25) = f5_turn_sharp;
features(26) = f5_hold_ratio_w; features(27) = f5_duty_move;
features(28) = f5_rpm_est; features(29) = f5_E_accel;
features(30) = f5_E_gyro; features(31) = f5_pca_evr1;
features(32) = f5_spec_flat;
end
% --- 유틸 함수 (코드 생성용) ---
function r = safe_corr_codegen(x,y)
    % Coder가 지원하는 corrcoef를 사용하고, std가 0인 경우를 방어합니다.
    if std(x)==0 || std(y)==0
        r = 0;
    else
        C = corrcoef(x,y);
        r = C(1,2);
    end
end