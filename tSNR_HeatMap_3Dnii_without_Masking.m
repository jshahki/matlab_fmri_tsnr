clc;
clear;

% Input and output folder setup
input_folder = 'Z:\People\JohnS\Volunteering Work\WM_VISION_tSNR\WM_VISION_Data_2'; 
output_folder = 'Z:\People\JohnS\Volunteering Work\WM_VISION_tSNR\Version April 19 2025\tSNRHeatmap';

% Ensure the output directory exists
if ~exist(output_folder, 'dir')
    mkdir(output_folder);
end

% Get all analysis subfolders
analysis_folders = dir(input_folder);
analysis_folders = analysis_folders([analysis_folders.isdir] & ~startsWith({analysis_folders.name}, '.'));

% Loop over each analysis folder
for i = 1:length(analysis_folders)
    analysis_name = analysis_folders(i).name;
    analysis_path = fullfile(input_folder, analysis_name);
    output_analysis_path = fullfile(output_folder, analysis_name);
    
    if ~exist(output_analysis_path, 'dir')
        mkdir(output_analysis_path);
    end

    % Get subject folders
    subject_folders = dir(analysis_path);
    subject_folders = subject_folders([subject_folders.isdir] & ~startsWith({subject_folders.name}, '.'));

    accumulated_tSNR_map = [];
    num_subjects = 0;

    for j = 1:length(subject_folders)
        subject_name = subject_folders(j).name;
        subject_path = fullfile(analysis_path, subject_name);

        % Find NIfTI files starting with 'swa'
        nii_files = dir(fullfile(subject_path, 'swa*.nii'));
        if isempty(nii_files)
            fprintf('No NIfTI file for subject: %s\n', subject_name);
            continue;
        end

        % Sort files based on numeric suffix before .nii (e.g., swa_ABC_057.nii -> 57)
        file_numbers = zeros(1, numel(nii_files));
        for k = 1:numel(nii_files)
            match = regexp(nii_files(k).name, '(\d{3})\.nii$', 'tokens');
            if isempty(match)
                error('Filename "%s" does not contain a 3-digit number before ".nii"', nii_files(k).name);
            end
            file_numbers(k) = str2double(match{1}{1});
        end
        [~, idx] = sort(file_numbers);
        nii_files = nii_files(idx);  % Sort the NIfTI files

        try
            % Load each 3D volume and stack them into 4D
            all_volumes = [];
            for k = 1:length(nii_files)
                nii = load_nii(fullfile(subject_path, nii_files(k).name));
                vol = nii.img;
                if ndims(vol) ~= 3
                    error('File %s is not a 3D volume', nii_files(k).name);
                end
                all_volumes(:,:,:,k) = vol; %#ok<SAGROW>
            end

            % Compute tSNR (mean / std across time)
            mean_data = mean(all_volumes, 4);
            std_data = std(all_volumes, 0, 4);
            std_data(std_data == 0) = NaN;
            tSNR = mean_data ./ std_data;
            tSNR(isnan(tSNR)) = 0;

            % Prepare tSNR NIfTI
            tSNR_nii = nii;  % Use header from last loaded volume
            tSNR_nii.img = tSNR;

            % Fix header for 3D + MNI
            tSNR_nii.hdr.dime.dim(1) = 3;
            tSNR_nii.hdr.dime.dim(2:4) = size(tSNR);
            tSNR_nii.hdr.dime.dim(5:8) = 1;
            tSNR_nii.hdr.dime.datatype = 16;  % float32
            tSNR_nii.hdr.dime.bitpix = 32;

            % Preserve spatial transformation (MNI coordinates)
            tSNR_nii.hdr.hist.qform_code = nii.hdr.hist.qform_code;
            tSNR_nii.hdr.hist.sform_code = nii.hdr.hist.sform_code;
            tSNR_nii.hdr.hist.srow_x = nii.hdr.hist.srow_x;
            tSNR_nii.hdr.hist.srow_y = nii.hdr.hist.srow_y;
            tSNR_nii.hdr.hist.srow_z = nii.hdr.hist.srow_z;
            tSNR_nii.hdr.hist.originator = nii.hdr.hist.originator;

            % Save subject tSNR
            tSNR_output_file = fullfile(output_analysis_path, [subject_name '_tSNR.nii']);
            save_nii(tSNR_nii, tSNR_output_file);

            % Accumulate for group average
            if isempty(accumulated_tSNR_map)
                accumulated_tSNR_map = double(tSNR);
            else
                accumulated_tSNR_map = accumulated_tSNR_map + double(tSNR);
            end
            num_subjects = num_subjects + 1;

        catch ME
            fprintf('Error processing subject %s: %s\n', subject_name, ME.message);
        end
    end

    % Save average tSNR map for this analysis
    if num_subjects > 0
        avg_tSNR_map = accumulated_tSNR_map / num_subjects;
        avg_tSNR_nii = tSNR_nii;  % Reuse last header
        avg_tSNR_nii.img = avg_tSNR_map;

        % Fix header again
        avg_tSNR_nii.hdr.dime.dim(1) = 3;
        avg_tSNR_nii.hdr.dime.dim(2:4) = size(avg_tSNR_map);
        avg_tSNR_nii.hdr.dime.dim(5:8) = 1;
        avg_tSNR_nii.hdr.dime.datatype = 16;
        avg_tSNR_nii.hdr.dime.bitpix = 32;

        % Save
        avg_output_file = fullfile(output_analysis_path, ['Average_tSNR_' analysis_name '.nii']);
        save_nii(avg_tSNR_nii, avg_output_file);
    else
        fprintf('No valid subjects found for analysis: %s\n', analysis_name);
    end
end

fprintf('All tSNR maps saved to: %s\n', output_folder);
