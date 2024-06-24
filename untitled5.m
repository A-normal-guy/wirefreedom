% Genel Parametreler
Fs = 20e6; % Örnekleme frekansı (20 MHz)
Fc = 2.4e9; % Taşıyıcı frekansı (2.4 GHz)
N = 64; % OFDM alt taşıyıcı sayısı
cp_len = 16; % Döngüsel ön ek uzunluğu
num_symbols = 1024; % Sembol sayısı (64'ün katı olmalı)

% 16-QAM Parametreleri
M = 16; % 16-QAM modülasyon seviyesi
k = log2(M); % Her semboldeki bit sayısı

% Kanal Parametreleri
SNR = 30; % Sinyal-gürültü oranı (dB)

% Testler için SNR değerleri
SNR_values = 0:5:30;
% Rastgele veri oluşturma
data = randi([0 M-1], num_symbols, 1); % Rastgele veri

% 16QAM modülasyonu
modData = qammod(data, M, 'UnitAveragePower', true);
% OFDM sembollerinin oluşturulması
ofdmGrid = reshape(modData, N, []); % Veriyi OFDM gridine yerleştir
ifftData = ifft(ofdmGrid, N); % IFFT işlemi

% Döngüsel ön ek ekleme
cp = ifftData(end-cp_len+1:end, :); % Döngüsel ön ek
txSignal = [cp; ifftData]; % OFDM sinyalini oluşturma
% Sinyalin spektrumunu hesapla
txSignal_fft = fftshift(fft(txSignal(:)));
f = (-length(txSignal_fft)/2:length(txSignal_fft)/2-1)*(Fs/length(txSignal_fft));
% Performans sonuçları için depolama
ber_results = zeros(length(SNR_values), 1);

for i = 1:length(SNR_values)
    % AWGN Kanalı
    rxSignal = awgn(txSignal, SNR_values(i), 'measured');

    % OFDM Demodülasyonu
    rxSignal = rxSignal(cp_len+1:end, :); % Döngüsel ön ek çıkarma
    rxData = fft(rxSignal, N); % FFT işlemi
    rxData = reshape(rxData, [], 1); % Veriyi yeniden şekillendir

    % 16QAM Demodülasyonu
    demodData = qamdemod(rxData, M, 'UnitAveragePower', true);

    % Bit Hata Oranı hesaplama
    [numErrors, ber] = biterr(data, demodData);
    ber_results(i) = ber;
end
% BER sonuçlarını tablo olarak yazdırma
disp('SNR (dB)     BER');
disp([SNR_values' ber_results]);

% Sinyal spektrumu
figure;
plot(f/1e6, abs(txSignal_fft));
title('Gönderilen Sinyalin Spektrumu');
xlabel('Frekans (MHz)');
ylabel('Genlik');

% BER eğrisi
figure;
semilogy(SNR_values, ber_results, '-o');
title('SNR vs BER');
xlabel('SNR (dB)');
ylabel('Bit Hata Oranı (BER)');
grid on;

% Konstellasyon diyagramı
rxSignal = awgn(txSignal, SNR, 'measured');
rxSignal = rxSignal(cp_len+1:end, :);
rxData = fft(rxSignal, N);
rxData = reshape(rxData, [], 1);
demodData = qamdemod(rxData, M, 'UnitAveragePower', true);

figure;
scatterplot(rxData);
title('16-QAM Konstellasyon Diyagramı');

% Gönderilen ve alınan sinyal dalga şekli
figure;
subplot(2,1,1);
plot(real(txSignal(:)));
title('Gönderilen Sinyal');
subplot(2,1,2);
plot(real(rxSignal(:)));
title('Alınan Sinyal');

