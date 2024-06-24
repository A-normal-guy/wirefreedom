% Genel Parametreler
Fs = 20e6; % Örnekleme frekansı (20 MHz)
Fc = 2.4e9; % Taşıyıcı frekansı (2.4 GHz)
N = 64; % OFDM alt taşıyıcı sayısı
cp_len = 16; % Döngüsel ön ek uzunluğu
M = 16; % 16-QAM modülasyon seviyesi
k = log2(M); % Her semboldeki bit sayısı
SNR = 30; % Sinyal-gürültü oranı (dB)
SNR_values = 0:5:30; % Testler için SNR değerleri

% Video dosyasını oku
fileID = fopen("a.mp4", 'r');
fileData = fread(fileID, '*ubit1'); % Veriyi bit olarak oku
fclose(fileID);

% Veri uzunluğu
numBits = length(fileData);

% Bit sayısını 16'nın katı olacak şekilde ayarla
numPadBits = mod(numBits, k);
if numPadBits > 0
    padBits = k - numPadBits;
    fileData = [fileData; zeros(padBits, 1)];
end

% Bit sayısını sembol sayısına çevir
num_symbols = length(fileData) / k;

% Bitleri sembollere dönüştür
data = bi2de(reshape(fileData, k, []).', 'left-msb');

% 16QAM modülasyonu
modData = qammod(data, M, 'UnitAveragePower', true);

% OFDM için veriyi hazırlama
numOFDMSymbols = ceil(length(modData) / N);
totalSymbols = numOFDMSymbols * N;

% Veriyi dolduracak şekilde sıfırlarla doldurma
modData = [modData; zeros(totalSymbols - length(modData), 1)];

% OFDM sembollerinin oluşturulması
ofdmGrid = reshape(modData, N, numOFDMSymbols); % Veriyi OFDM gridine yerleştir
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
    rxSignal = reshape(rxSignal, size(txSignal, 1), []); % Yeniden şekillendir
    rxSignal = rxSignal(cp_len+1:end, :); % Döngüsel ön ek çıkarma
    rxData = fft(rxSignal, N); % FFT işlemi
    rxData = reshape(rxData, [], 1); % Veriyi yeniden şekillendir

    % 16QAM Demodülasyonu
    demodData = qamdemod(rxData, M, 'UnitAveragePower', true);

    % Orijinal veri ile aynı boyutta olacak şekilde kırp
    demodData = demodData(1:length(data));

    % Bit Hata Oranı hesaplama
    [numErrors, ber] = biterr(data, demodData);
    ber_results(i) = ber;
end

% En iyi SNR değeri ile alınan sinyali demodüle et
rxSignal = awgn(txSignal, SNR, 'measured');
rxSignal = reshape(rxSignal, size(txSignal, 1), []); % Yeniden şekillendir
rxSignal = rxSignal(cp_len+1:end, :);
rxData = fft(rxSignal, N);
rxData = reshape(rxData, [], 1);
demodData = qamdemod(rxData, M, 'UnitAveragePower', true);

% Orijinal veri ile aynı boyutta olacak şekilde kırp
demodData = demodData(1:length(data));

% Bit verisine dönüştür
rxBits = de2bi(demodData, k, 'left-msb').';
rxBits = rxBits(:);

% Gereksiz dolgu bitlerini çıkar
rxBits = rxBits(1:numBits);

% Veriyi dosyaya yaz
fileID = fopen('output.mp4', 'w');
fwrite(fileID, rxBits, 'ubit1');
fclose(fileID);

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

