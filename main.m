% =========================================================================
% Communication Systems Project - BSc
% Instructor: Dr. Yazdian
% Team: Alireza Jafari, Mohammad Ehsan Amoo, Mohammad Javad Naghdi, 
%       MohammadReza Abazari
% =========================================================================
% Description: FM Signal Receiver using RTL-SDR Hardware
% This code receives FM radio signals, applies filtering, demodulates,
% and plays the audio output
% =========================================================================

close all;          % Close all figure windows
clear all;          % Clear all variables from workspace
clc;                % Clear command window

%% ========================= CONFIGURATION ==============================
% Receiver Parameters
fc = 99.25e6;                   % Center frequency (Hz) - Initial FM station
FrontEndSampleRate = 1000e3;    % Sampling rate (samples/second)
FrameLength = 375000;           % Number of samples per frame

% Initialize RTL-SDR Receiver Object
hSDRrRx = comm.SDRRTLReceiver(...
    'CenterFrequency',   fc, ...          % Tuning frequency
    'EnableTunerAGC',    true, ...        % Automatic gain control
    'SampleRate',        FrontEndSampleRate, ...  % Sampling rate
    'SamplesPerFrame',   FrameLength, ...         % Frame size
    'OutputDataType',    'double');               % Output data type

disp('Initialization completed successfully');

%% ======================== SIGNAL PROCESSING PARAMETERS =================
N = 1;                          % Number of frames
L = FrameLength * N;            % Total samples for FFT
Fs = FrontEndSampleRate;        % Sampling frequency

% Prepare frequency axis for FFT
NFFT = 2^nextpow2(L);           % Next power of 2 for efficient FFT
f = Fs/2 * linspace(0, 1, NFFT/2+1);  % Frequency vector (Hz)

%% ======================== LOAD FILTERS =================================
% Load Low-Pass Filters (LPF)
lpf22;          % Loads 'lp222' global variable (audio LPF)
global lp222;

lpf4030;        % Loads 'klpf4030' global variable
global klpf4030;

lpf15bah;       % Loads 'klpf' global variable  
global klpf;

% Load Band-Pass Filter (BPF)
BPF15BAH;       % Loads 'kbpf' global variable
global kbpf;

%% ========================= CONTROL VARIABLES ===========================
n = 0;                          % Frame counter
cnt = 0;                        % Frequency scanning counter
RadioFrequency = zeros(1, 8);   % Array to store detected frequencies
flag = 0;                       % Signal detection flag
flag_t = 0;                     % Signal capture flag
capture_v = 0;                  % Store captured signal power
fd = 0;                         % Frequency deviation

%% ========================= MAIN RECEPTION LOOP =========================
% Check if RTL-SDR device is connected
if ~isempty(sdrinfo(hSDRrRx.RadioAddress))
    
    while true  % Continuous reception loop
        
        % Step 1: Receive raw signal from SDR
        yt = step(hSDRrRx);     % y(t) = received baseband signal
        
        % Step 2: Apply Band-Pass Filtering (Jafari's method)
        % Removes out-of-band noise and interference
        ylpf = filter(klpf, 1, yt);
        
        % Step 3: Calculate Signal Power using FFT
        Y = 1000 * abs(fft(ylpf, NFFT)) / NFFT;  % Amplitude spectrum
        power = sum(Y .* Y);                     % Total signal power
        
        % Step 4: Signal Detection Based on Power Threshold
        if(power >= 45000)  % Valid FM signal detected
            
            % Step 5: FM Demodulation Process
            % Create delay element for quadrature demodulation
            h = dfilt.delay(1);                    % 1 sample delay
            y2t = conj(filter(h, ylpf));           % Delayed & conjugated signal
            y3t = 10 * angle(y2t .* ylpf);         % Phase difference = message signal
            
            % Step 6: Low-Pass Filter demodulated signal
            % Removes high-frequency noise and extracts audio
            m = filter(lp222, 1, y3t);
            
            % Step 7: Play Audio
            n = n + 1;  % Frame counter
            % Decimate signal to reduce sample rate for audio playback
            % Original: 1 MS/s -> Decimated: 100 kS/s (appropriate for sound card)
            sound(decimate(m, 10), 100e3);
            
            % Optional: Store detected frequencies (commented)
            % cnt = cnt + 1;
            % if(cnt <= 8)
            %     RadioFrequency(cnt) = fc;
            % end
            % disp(RadioFrequency)
            
        else
            % No signal detected - scan to next frequency
            disp('No signal detected - scanning...');
            fc = fc + 0.25e6;                       % Increment by 250 kHz
            hSDRrRx.CenterFrequency = fc;           % Tune receiver to new frequency
        end
    end
    
else
    % SDR device not found
    warning(message('SDR:sysobjdemos:MainLoop'));
    disp('Error: RTL-SDR device not connected or not recognized');
end

%% ========================= CLEANUP =====================================
% Release hardware resources when done (won't reach here in infinite loop)
release(hSDRrRx);

%% ========================= ADDITIONAL NOTES ============================
% 1. The commented section shows an alternative method using signal power
%    threshold for frequency scanning
% 
% 2. Filters (lpf22, lpf4030, lpf15bah, BPF15BAH) must be defined in 
%    separate .m files containing filter coefficients
% 
% 3. Typical FM broadcast band: 88-108 MHz
% 
% 4. The decimation factor of 10 reduces sample rate from 1 MHz to 100 kHz,
%    which is suitable for audio playback (standard audio is 44.1 or 48 kHz)
