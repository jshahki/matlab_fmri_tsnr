# matlab_fmri_tsnr

This MATLAB script can be used for performing temporal signal to noise ratio calculations on fMRI data using a brain mask.

Briefly, the temporal signal to noise ratio for a given fMRI run can be caluclated voxel-wise by dividing the mean of the signal time series by the standard deviation of the signal time series:

$$
tSNR = \frac{\mathrm{mean}_{\text{signal time series}}}{\mathrm{stdev}_{\text{signal time series}}}
$$

If a brain masked is used, these calculations are performed at each voxel of the brain, and the whole-brain mean tSNR for a given fMRI scanning run can be calculated like so:

$$
\overline{tSNR} = \frac{1}{V} \sum_{v=1}^{V} tSNR(v)
$$

Where V is the total number of voxels accounted for in the brain by the brain mask, and v represents a given brain voxel.

When performed on realigned fMRI volumes, this can give a quick and easy image quality metric for signal intensity and stability. Extreme outliers for a given fMRI run (eg. whole-brain mean tSNRs of nearly 0) can indicate problems with the quality of the data. The plot below gives a good example of this<sup>*</sup>:



*In the case above, the outlier subject was missing data from their cerebellum:



# Instructions for Use: `tsnr_with_masking.m`

This script performs tSNR calculations and incorporates an fMRI-CPCA-derived brain mask for calculating whole-brain tSNR averages. If you do not have an fMRI-CPCA-derived brain mask, then one is provided here in the masks folder. This script is able to run multiple different datasets simultaneously.

## Folder organization

To use this script, your folder organization should roughly follow the following convention:

```
main_directory
├──masks
│   ├──dataset_1
│   │   ├──mask_used.hdr
│   │   └──mask_used.img
│   ├──dataset_2
│   │   ├──mask_used.hdr
│   │   └──mask_used.img
│   ├──dataset_3
│   │   ├──mask_used.hdr
│   │   └──mask_used.img
│   └──...
├──data
│   ├──dataset_1
│   │   ├──sub-01
│   │   │   ├──swa*_001.nii
│   │   │   ├──swa*_002.nii
│   │   │   ├──swa*_003.nii
│   │   │   └──...
│   │   ├──sub-02
│   │   │   ├──swa*_001.nii
│   │   │   ├──swa*_002.nii
│   │   │   ├──swa*_003.nii
│   │   │   └──...
│   │   └──...
│   ├──dataset_2
│   │   ├──sub-01
│   │   │   ├──swa*_001.nii
│   │   │   ├──swa*_002.nii
│   │   │   ├──swa*_003.nii
│   │   │   └──...
│   │   ├──sub-02
│   │   │   ├──swa*_001.nii
│   │   │   ├──swa*_002.nii
│   │   │   ├──swa*_003.nii
│   │   │   └──...
│   │   └──...
│   ├──dataset_3
│   │   ├──sub-01
│   │   │   ├──swa*_001.nii
│   │   │   ├──swa*_002.nii
│   │   │   ├──swa*_003.nii
│   │   │   └──...
│   │   ├──sub-02
│   │   │   ├──swa*_001.nii
│   │   │   ├──swa*_002.nii
│   │   │   ├──swa*_003.nii
│   │   │   └──...
│   │   └──...
│   └──...
├──tsnr_output
└──tsnr_with_masking.m
```

You may rename `dataset_1`, `dataset_2`, etc. to the name of your datasets, but the names of corresponding datasets should match in both the `data` and `masks` folders. It is also okay for subject IDs to be named freely. They do not need to be named `sub-01`, `sub-02`, etc. The `main_directory` folder may also be named freely. As this script was designed to be run on fMRI-CPCA-compatible data, each subject's .nii volumes should be separate 3D .nii volumes, and not a 4D concatenated .nii volume. The `tsnr_output` folder is where the output will go. Specifically, .nii heat maps of whole-brain tSNRs for each subject will be produced, along with an overall average .nii heat map for each dataset. As well, a .xlsx file with each subject's whole-brain mean tSNRs will be produced. These values can be used for producing plots or performing statistics to identify and quantify potential significant differences.

## Modifying script parameters

After organizing your directory, and before running the `tsnr_with_masking.m` script, please modify the input and output parameters to match the naming of your directory.

`line 5`: Paste the path to your `data` folder. Eg. `input_folder = 'Z:\People\JohnS\Volunteering_Work\WM_VISION_tSNR\WM_VISION_Data_2';`
`line 6`: Paste the path to your `masks` folder. Eg. `input_masks = 'Z:\People\JohnS\Volunteering_Work\WM_VISION_tSNR\WM_VISION_Masks';`
`line 7`: Paste the path to your `tsnr_output` folder. Eg. `output_folder = 'C:\Users\John.Shahki\Documents\tSNR_Testing_for_GitHub\5\tSNRHeatmap';`
`line 7`: Paste the path to where you would like your .xlsx file outputted. This line is also where you can modify the name of the outputted .xlsx file. Eg. `output_excel = 'C:\Users\John.Shahki\Documents\tSNR_Testing_for_GitHub\5\tSNR_summary.xlsx';` will output an Excel file named `tSNR_summary.xlsx`

If your .nii volumes have a different prefix (ie. if they do not start with swa), then you may also modify `line 54`. For instance, if my .nii volumes had a sr file name prefix, then I would modify `line 54` as follows:

`line 54`: `nii_files = dir(fullfile(subject_path, 'swa*.nii'));` ---> `nii_files = dir(fullfile(subject_path, 'sr*.nii'));`




