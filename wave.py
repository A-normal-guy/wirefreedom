import numpy as np
import scipy.fftpack
import scipy.signal
import matplotlib.pyplot as plt

# Genel Parametreler
Fs = 20e6  # Örnekleme frekansı (20 MHz)
Fc = 2.4e9  # Taşıyıcı frekansı (2.4 GHz)
N = 64  # OFDM alt taşıyıcı sayısı
cp_len = 16  # Döngüsel ön ek uzunluğu
M = 16  # 16-QAM modülasyon seviyesi
k = int(np.log2(M))  # Her semboldeki bit sayısı
SNR = 30  # Sinyal-gürültü oranı (dB)
SNR_values = np.arange(0, 35, 5)  # Testler için SNR değerleri

# Video dosyasını oku
fileID = open("a.mp4", 'rb')
fileData = np.frombuffer(fileID.read(), dtype=np.uint8)
fileID.close()

# Veri uzunluğu
numBits = len(fileData) * 8

# Bit sayısını 16'nın katı olacak şekilde ayarla
numPadBits = numBits % k
if numPadBits > 0:
    padBits = k - numPadBits
    fileData = np.append(fileData, np.zeros(padBits // 8, dtype=np.uint8))

# Bit sayısını sembol sayısına çevir
fileData_bits = np.unpackbits(fileData)
num_symbols = len(fileData_bits) // k

# Bitleri sembollere dönüştür
data = np.packbits(fileData_bits.reshape(-1, k), axis=-1)

# 16QAM modülasyonu
modData = (2 * np.real(data) - 1) + 1j * (2 * np.imag(data) - 1)

# OFDM için veriyi hazırlama
numOFDMSymbols = int(np.ceil(len(modData) / N))
totalSymbols = numOFDMSymbols * N

# Veriyi dolduracak şekilde sıfırlarla doldurma
modData = np.append(modData, np.zeros(totalSymbols - len(modData)))

# OFDM sembollerinin oluşturulması
ofdmGrid = modData.reshape((N, numOFDMSymbols))  # Veriyi OFDM gridine yerleştir
ifftData = np.fft.ifft(ofdmGrid, axis=0)  # IFFT işlemi

# Döngüsel ön ek ekleme
cp = ifftData[-cp_len:, :]  # Döngüsel ön ek
txSignal = np.vstack([cp, ifftData]).reshape(-1)  # OFDM sinyalini oluşturma

# Sinyalin spektrumunu hesapla
txSignal_fft = np.fft.fftshift(np.fft.fft(txSignal))
f = np.fft.fftfreq(len(txSignal_fft), 1 / Fs)

# Performans sonuçları için depolama
ber_results = []

for snr in SNR_values:
    # AWGN Kanalı
    noise = (np.random.normal(0, 1, txSignal.shape) + 1j * np.random.normal(0, 1, txSignal.shape)) / np.sqrt(2)
    noise_power = 10 ** (-snr / 10)
    rxSignal = txSignal + noise * np.sqrt(noise_power)
    
    # OFDM Demodülasyonu
    rxSignal = rxSignal.reshape((N + cp_len, -1))  # Yeniden şekillendir
    rxSignal = rxSignal[cp_len:, :]  # Döngüsel ön ek çıkarma
    rxData = np.fft.fft(rxSignal, axis=0).reshape(-1)  # FFT işlemi
    
    # 16QAM Demodülasyonu
    demodData = np.round(np.real(rxData)).astype(int) + 1j * np.round(np.imag(rxData)).astype(int)
    
    # Orijinal veri ile aynı boyutta olacak şekilde kırp
    demodData = demodData[:len(data)]
    
    # Bit Hata Oranı hesaplama
    numErrors = np.sum(data != demodData)
    ber = numErrors / len(data)
    ber_results.append(ber)

# En iyi SNR değeri ile alınan sinyali demodüle et
noise = (np.random.normal(0, 1, txSignal.shape) + 1j * np.random.normal(0, 1, txSignal.shape)) / np.sqrt(2)
noise_power = 10 ** (-SNR / 10)
rxSignal = txSignal + noise * np.sqrt(noise_power)
rxSignal = rxSignal.reshape((N + cp_len, -1))  # Yeniden şekillendir
rxSignal = rxSignal[cp_len:, :]
rxData = np.fft.fft(rxSignal, axis=0).reshape(-1)
demodData = np.round(np.real(rxData)).astype(int) + 1j * np.round(np.imag(rxData)).astype(int)

# Orijinal veri ile aynı boyutta olacak şekilde kırp
demodData = demodData[:len(data)]

# Bit verisine dönüştür
demodData_bits = np.packbits(demodData.real.astype(np.uint8)).reshape(-1, 8)
rxBits = demodData_bits[:numBits // 8]

# Gereksiz dolgu bitlerini çıkar
rxBits = rxBits[:numBits // 8]

# Veriyi dosyaya yaz
fileID = open('output.mp4', 'wb')
fileID.write(rxBits.tobytes())
fileID.close()

# BER sonuçlarını tablo olarak yazdırma
print('SNR (dB)     BER')
print(np.column_stack([SNR_values, ber_results]))

# Sinyal spektrumu
plt.figure()
plt.plot(f / 1e6, np.abs(txSignal_fft))
plt.title('Gönderilen Sinyalin Spektrumu')
plt.xlabel('Frekans (MHz)')
plt.ylabel('Genlik')

# BER eğrisi
plt.figure()
plt.semilogy(SNR_values, ber_results, '-o')
plt.title('SNR vs BER')
plt.xlabel('SNR (dB)')
plt.ylabel('Bit Hata Oranı (BER)')
plt.grid(True)

# Konstellasyon diyagramı
plt.figure()
plt.scatter(np.real(rxData), np.imag(rxData))
plt.title('16-QAM Konstellasyon Diyagramı')

# Gönderilen ve alınan sinyal dalga şekli
plt.figure()
plt.subplot(2, 1, 1)
plt.plot(np.real(txSignal))
plt.title('Gönderilen Sinyal')
plt.subplot(2, 1, 2)
plt.plot(np.real(rxSignal))
plt.title('Alınan Sinyal')

plt.show()
