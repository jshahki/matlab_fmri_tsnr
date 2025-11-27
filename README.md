# matlab_fmri_tsnr

These MATLAB scripts can be used for performing either masked or unmasked temporal signal to noise ratio calculations on fMRI data.

Briefly, the temporal signal to noise ratio for a given fMRI run can be caluclated voxel-wise by dividing the mean of the signal time series by the standard deviation of the signal time series:

$$
tSNR = \frac{\mathrm{mean}_{\text{signal time series}}}{\mathrm{stdev}_{\text{signal time series}}}
$$

If a brain masked is used, these calculations are performed at each voxel of the brain, and the whole-brain mean tSNR for a given fMRI scanning run can be calculated like so:

$$
\overline{tSNR} = \frac{1}{V} \sum_{v=1}^{V} tSNR(v)
$$

This can give a quick and easy image quality metric for signal intensity and stability. Extreme outliers for a given fMRI run (eg. whole-brain mean tSNRs of nearly 0) can indicate problems with the quality of the data.

# Instructions for Use:

## tSNR_HeatMap_3Dnii_without_Masking

This script performs tSNR calculations without requiring a brain mask, so it can be ideal if you do not have one on hand. Here are the steps to run this script:



## tSNR_HeatMap_3Dnii_with_Masking

