clear;
clc;

%% ========== INPUT / OUTPUT SETUP ==========
input_folder = 'Z:\People\JohnS\Volunteering Work\Dataset_Test\Data_2';
input_masks = 'Z:\People\JohnS\Volunteering Work\Dataset_Test\Masks';
output_folder = 'Z:\People\JohnS\Volunteering Work\Dataset_Test\Version April 19 2025\tSNRHeatmap';
output_excel = 'Z:\People\JohnS\Volunteering Work\Dataset_Test\Version April 19 2025\tSNR_summary.xlsx';

figures_folder = fullfile(output_folder, 'tSNR_Figures');
if ~exist(figures_folder, 'dir')
    mkdir(figures_folder);
end

if ~exist(output_folder, 'dir')
    mkdir(output_folder);
end

%% ========== ANALYSIS LOOP ==========
analysis_folders = dir(input_folder);
analysis_folders = analysis_folders([analysis_folders.isdir] & ~startsWith({analysis_folders.name}, '.'));

for i = 1:length(analysis_folders)
    analysis_name = analysis_folders(i).name;
    analysis_path = fullfile(input_folder, analysis_name);
    output_analysis_path = fullfile(output_folder, analysis_name);

    if ~exist(output_analysis_path, 'dir')
        mkdir(output_analysis_path);
    end

    mask_path = fullfile(input_masks, analysis_name, 'mask_used.img');
    if ~exist(mask_path, 'file')
        fprintf('No mask found for analysis: %s — skipping...\n', analysis_name);
        continue;
    end
    mask_nii = load_nii(mask_path);
    brain_mask = logical(mask_nii.img);

    subject_folders = dir(analysis_path);
    subject_folders = subject_folders([subject_folders.isdir] & ~startsWith({subject_folders.name}, '.'));

    accumulated_tSNR_map = [];
    num_subjects = 0;
    subject_tSNRs = [];
    valid_subjects = {};
    roi_tSNR_matrix = [];

    %% ========== SUBJECT LOOP + tSNR CALCULATION ==========
    for j = 1:length(subject_folders)
        subject_name = subject_folders(j).name;
        subject_path = fullfile(analysis_path, subject_name);

        nii_files = dir(fullfile(subject_path, 'swa*.nii'));
        if isempty(nii_files)
            fprintf('No NIfTI file for subject: %s\n', subject_name);
            continue;
        end

        % Sort by numeric suffix
        file_numbers = zeros(1, numel(nii_files));
        for k = 1:numel(nii_files)
            match = regexp(nii_files(k).name, '(\d{3})\.nii$', 'tokens');
            if isempty(match)
                error('Filename "%s" does not contain a 3-digit number before ".nii"', nii_files(k).name);
            end
            file_numbers(k) = str2double(match{1}{1});
        end
        [~, idx] = sort(file_numbers);
        nii_files = nii_files(idx);

        try
            %% ========== STACK & COMPUTE tSNR ==========
            all_volumes = [];
            for k = 1:length(nii_files)
                nii = load_nii(fullfile(subject_path, nii_files(k).name));
                vol = nii.img;
                if ndims(vol) ~= 3
                    error('File %s is not 3D', nii_files(k).name);
                end
                all_volumes(:,:,:,k) = vol; %#ok<SAGROW>
            end

            mean_data = mean(all_volumes, 4);
            std_data = std(all_volumes, 0, 4);
            std_data(std_data == 0) = NaN;
            tSNR = mean_data ./ std_data;
            tSNR(isnan(tSNR)) = 0;
            tSNR(~brain_mask) = 0;

            % Save individual tSNR
            tSNR_nii = nii;
            tSNR_nii.img = tSNR;
            tSNR_nii.hdr.dime.dim(1) = 3;
            tSNR_nii.hdr.dime.dim(2:4) = size(tSNR);
            tSNR_nii.hdr.dime.dim(5:8) = 1;
            tSNR_nii.hdr.dime.datatype = 16;
            tSNR_nii.hdr.dime.bitpix = 32;
            tSNR_nii.hdr.hist.qform_code = nii.hdr.hist.qform_code;
            tSNR_nii.hdr.hist.sform_code = nii.hdr.hist.sform_code;
            tSNR_nii.hdr.hist.srow_x = nii.hdr.hist.srow_x;
            tSNR_nii.hdr.hist.srow_y = nii.hdr.hist.srow_y;
            tSNR_nii.hdr.hist.srow_z = nii.hdr.hist.srow_z;
            tSNR_nii.hdr.hist.originator = nii.hdr.hist.originator;

            save_nii(tSNR_nii, fullfile(output_analysis_path, [subject_name '_tSNR.nii']));

            % Accumulate tSNR map
            if isempty(accumulated_tSNR_map)
                accumulated_tSNR_map = double(tSNR);
            else
                accumulated_tSNR_map = accumulated_tSNR_map + double(tSNR);
            end
            num_subjects = num_subjects + 1;

            %% ========== SUBJECT MEAN tSNR + ROI tSNRs ==========
            flat_tSNR = tSNR(:);
            flat_tSNR(flat_tSNR == 0) = NaN;
            subject_mean_tSNR = mean(flat_tSNR, 'omitnan');

            % ROI-specific tSNR
            roi_labels = [1, 2, 4, 5];
            roi_tSNRs = NaN(1, numel(roi_labels));
            for r = 1:numel(roi_labels)
                roi_mask = (mask_nii.img == roi_labels(r));
                roi_values = tSNR(roi_mask);
                roi_values(roi_values == 0) = NaN;
                roi_tSNRs(r) = mean(roi_values, 'omitnan');
            end

            if ~isnan(subject_mean_tSNR)
                subject_tSNRs(end+1) = subject_mean_tSNR;
                valid_subjects{end+1} = subject_name;
                roi_tSNR_matrix(end+1, :) = roi_tSNRs;
            end

        catch ME
            fprintf('Error processing subject %s: %s\n', subject_name, ME.message);
        end
    end

    %% ========== SAVE AVERAGE tSNR MAP ==========
    if num_subjects > 0
        avg_tSNR_map = accumulated_tSNR_map / num_subjects;
        avg_tSNR_map(~brain_mask) = 0;

        avg_tSNR_nii = tSNR_nii;
        avg_tSNR_nii.img = avg_tSNR_map;
        avg_tSNR_nii.hdr.dime.dim(1) = 3;
        avg_tSNR_nii.hdr.dime.dim(2:4) = size(avg_tSNR_map);
        avg_tSNR_nii.hdr.dime.dim(5:8) = 1;
        avg_tSNR_nii.hdr.dime.datatype = 16;
        avg_tSNR_nii.hdr.dime.bitpix = 32;

        avg_output_file = fullfile(output_analysis_path, ['Average_tSNR_' analysis_name '.nii']);
        save_nii(avg_tSNR_nii, avg_output_file);

        %% ========== WRITE TO EXCEL ==========
        roi_table = table(valid_subjects', subject_tSNRs', roi_tSNR_matrix(:,1), roi_tSNR_matrix(:,2), ...
            roi_tSNR_matrix(:,3), roi_tSNR_matrix(:,4), ...
            'VariableNames', {'Subject', 'tSNR', 'GM_tSNR', 'WM_tSNR', 'Brainstem_tSNR', 'Cerebellum_tSNR'});

        writetable(roi_table, output_excel, 'Sheet', analysis_name, 'WriteMode', 'overwrite');

        avg_vals = [mean(subject_tSNRs, 'omitnan'), mean(roi_tSNR_matrix, 1, 'omitnan')];
        avg_row = table({'Average'}, avg_vals(1), avg_vals(2), avg_vals(3), avg_vals(4), avg_vals(5), ...
            'VariableNames', {'Subject', 'tSNR', 'GM_tSNR', 'WM_tSNR', 'Brainstem_tSNR', 'Cerebellum_tSNR'});

        writetable(avg_row, output_excel, 'Sheet', analysis_name, 'WriteMode', 'append');

        %% ========== GENERATE & SAVE HEATMAP FIGURE ==========
        avg_tSNR_map(isnan(avg_tSNR_map)) = 0;
        z_dim = size(avg_tSNR_map, 3);
        non_zero_slices = any(avg_tSNR_map(:,:,1:z_dim) > 0, [1,2]);
        non_zero_indices = find(non_zero_slices);

        if ~isempty(non_zero_indices)
            middle_slice_idx = non_zero_indices(round(length(non_zero_indices)/2));
        else
            middle_slice_idx = round(z_dim/2);
        end
        middle_slice = avg_tSNR_map(:,:,middle_slice_idx);

        figure;
        imagesc(middle_slice);
        colormap hot;
        colorbar;
        axis equal;
        axis tight;
        title(sprintf('%s - Average tSNR Middle Slice', analysis_name));
        
        saveas(gcf, fullfile(figures_folder, sprintf('%s_tSNR_Avg_Slice.png', analysis_name)));
        close;
    else
        fprintf('No valid subjects found for analysis: %s\n', analysis_name);
    end
end

fprintf('All masked tSNR maps, Excel summary, and figures saved to: %s\n', output_folder);
