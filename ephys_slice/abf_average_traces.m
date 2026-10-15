% This code was written to open Clampex abf files, subtract the baseline, and average multiple traces
% Created by Juhee Haam, 7/30/2026

% THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
% EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
% OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
% IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM,
% DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE,
% ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
% DEALINGS IN THE SOFTWARE.

clc;
clear;

%% Parameters
fs = 10000; % sampling rate in Hz
bl_dur = 5; % baseline duration in sec
delay = 1; % delay after the end of puff for the DCZ epoch
epoch_dur = 1; % epoch duration used for comparing DCZ effet to the control.  

%% Directories
% Output files will be saved under the output folder selected
user= getenv('username');
startFolder = ['C:\Users\' user];
projectFolder = uigetdir(startFolder,'Select a project folder (Parent directory Where Input and Ouput folders Are Stored)');
[fileName1, pathName1] = uigetfile('*.*', 'Select a (multi-column) data file', 'multiselect', 'on',projectFolder);

analysis_dir = [projectFolder '\Analysis\'];
[~,~,~] = mkdir(analysis_dir);

file_num = size(fileName1,2);
if file_num ==1
    filename_cell{1} = fileName1;
else
    filename_cell = fileName1;
end

trace_raw = cell(1, file_num);
trace_adj = cell(1, file_num);
trace_len = zeros(1, file_num);
h1 = figure; set(gcf,'position',[ 584          96         725        1234]);

for mm = 1:file_num
    %% Read an abf file
    inFilePath = [pathName1 filename_cell{mm}];
    trace = abfload(inFilePath);
    token = regexp(fileName1{1,mm},'(.*).abf', 'tokens');
    fileInfo = token{1}{1};
    trace_raw{mm} = trace(:,1);
    %% Find the baseline value
    % find when the TTL goes high
    k = 1; p = 0;
    while k < size(trace,1)
        if trace(k, 3) > 4.5
            ttl_s = k; p = 1;
            break
        end
        k = k+1;
    end

   while k < size(trace,1)
        if trace(k, 3) < 4.5
            ttl_e = k; p = 0;
            break
        end
        k = k+1;
    end
    
    bl_e = k;
    bl_s = k-bl_dur*fs;
    
    bl = mean(trace(bl_s:bl_e,1));
    
    %% Get the baseline adjusted trace 
    trace_adj{mm} = trace(:,1)-bl;
    trace_len(mm) = length(trace);
    out_adj = [analysis_dir fileInfo '_BL_adj.csv']; 
    writematrix(trace_adj{mm}, out_adj);

    subplot(file_num,1,mm);
    t = 1/fs:1/fs:length(trace)/fs;
    plot(t, trace_adj{mm},'k');
    title(fileInfo);
    set(gca,'color','none','XColor','k','YColor','k','FontSize',12, 'GridLineStyle','none');box off;


end

% if any of the files are shorter, trim all data set to the length
len = min(trace_len);
for mm =1:file_num
    trace_adj{mm} = trace_adj{mm}(1:len);
end

trace_adj = cell2mat(trace_adj);
trace_raw = cell2mat(trace_raw);

%% Plot and save
% averaged trace (full fs; for downsampled, see the manuscript figure)
trace_avg = mean(trace_adj,2);
trace_sem = std(trace_adj,1,2)/sqrt(file_num);

h2 = figure; set(gcf,'position', [ 71         250        600         190]);
P = shadedErrorBar(t, trace_avg, trace_sem,'lineProps',{'k-','linewidth',0.7});  
xline(ttl_s/fs); xline(ttl_e/fs);
xlim('tight'); xlabel ('Time (s)')
ylim([-1 2.5]);
ylabel('Delta Vm'); title('');
set(gca,'color','none','XColor','k','YColor','k','FontSize',16, 'GridLineStyle','none');box off;

%% Stat summary
RMP_summary = cell(file_num+1,3);

RMP_summary(1, 2:3) = {"Control", "DCZ"};

for mm = 1:file_num
    RMP_summary{mm+1, 1} = filename_cell{mm};
    RMP_summary{mm+1, 2} = mean(trace_raw(ttl_s-epoch_dur*fs:ttl_s, mm)); % control 
    RMP_summary{mm+1, 3} = mean(trace_raw(delay*fs+ttl_e:delay*fs+ttl_e+epoch_dur*fs, mm)); % DCZ
end

% Save data and figures
saveas(h1,[analysis_dir '-ind_BL_adj'],'fig');
saveas(h2,[analysis_dir '-average_trace'],'fig');
writematrix(trace_adj, [analysis_dir 'BL_adj_traces.csv']);
writematrix(trace_raw, [analysis_dir 'Raw_traces.csv']);
writecell(RMP_summary, [analysis_dir 'RMP_stat.csv'])
writecell(RMP_summary, [analysis_dir 'RMP_stat_1s_delay.csv'])

