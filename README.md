# Activity-Specific Hip Motion-Path Workflow and Dataset

This repository contains the MATLAB workflow and processed data used to analyse 14 activity trials: four out-of-water simulated swimming strokes and ten dance activities. 

## Workflow

1. `Run marker_names.m and select the C3D file to inspect its available marker names. This step is optional but helps confirm that the required pelvis and lower-limb markers are present.
2. `Run c3d_excel_hip_extraction.m for a single participant, or c3d_excel_two_subjects.m for Salsa Cubana. Select the C3D file when prompted. The script generates separate left- and right-hip Excel workbooks containing flexion/extension, abduction/adduction and internal/external rotation.
3. `c3d_excel_two_subjects.m` performs the same extraction for the two-participant (Salsa Cubana trial).
4. `Run resampler.m and select one extracted hip-angle workbook. Enter the original frame rate or time step, choose continuous or repetitive processing, select the analyzed interval and specify the number of output points. The script generates a resampled workbook containing the three hip rotations and timing metadata. Repeat this step for each hip.
5. `Run motion_path_complete_sample.m and select a resampled hip-angle workbook. The script generates the 20-point femoral-head motion paths and exports FrameData and PointMetrics sheets containing the calculated motion-path and dynamic metrics. Repeat this step for each hip.
6. `Optionally, run plot_velocity_acceleration_from_motion_output.m and select the resulting motion-path workbook to generate hip-angle, angular-velocity and angular-acceleration plots.

`motion_path_complete_sample.m` requires `RotateXYV.m`, Dr Robert Layton's original rotation helper function. Before running the workflow, place RotateXYV.m in the same folder as the scripts or on the MATLAB path. C3D extraction also requires `ezc3dRead` to be available on the MATLAB path.

## Files in Each Activity Folder

- `*.c3d`: source CMU motion-capture trial.
- `hip_angles_left.xlsx` and `hip_angles_right.xlsx`: extracted three-direction hip-angle data.
- `sampled_hip_angles_left.xlsx` and `sampled_hip_angles_right.xlsx`: selected and resampled hip-angle data, including the timing metadata used by the motion-path program.
- `motion_path_results_left.xlsx` and `motion_path_results_right.xlsx`: final frame-based dynamic results and point-specific motion-path metrics.

Salsa Cubana contains corresponding female and male workbooks because the C3D file contains two partnered participants. 
## Activity Folders

| Folder | Activity | CMU subject_trial |
|---|---|---|
| `01_Swimming_Breaststroke` | Breaststroke | 125_01 |
| `02_Swimming_Backstroke` | Backstroke | 126_02 |
| `03_Swimming_Butterfly` | Butterfly | 126_06 |
| `04_Swimming_Freestyle` | Freestyle | 126_12 |
| `05_Social_Dance_Lambada` | Lambada | 55_02 |
| `06_Social_Dance_Salsa_Cubana` | Salsa Cubana | 60_01, 61_01 |
| `07_Social_Dance_Whirl` | Whirl | 55_01 |
| `08_Ballet_Combination_1` | Rond de jambe en l'air, jete and turn | 05_08 |
| `09_Ballet_Combination_2` | Coupe dessous | 05_16 |
| `10_Ballet_Combination_3` | Retire derriere and attitude arabesque | 05_14 |
| `11_Ballet_Combination_4` | Attitude arabesque and jete en tournant | 05_18 |
| `12_Ballet_Combination_5` | Cartwheel-like movement, turns and jete | 05_06 |
| `13_Traditional_Dance_Russian_Dance` | Russian Dance | 90_31 |
| `14_Traditional_Dance_Indian_Dance` | Indian Dance | 94_01 |

## Data Source

The C3D files were obtained from the [Carnegie Mellon University Graphics Lab Motion Capture Database](https://mocap.cs.cmu.edu/). Its FAQ states that the motion-capture data may be copied, modified or redistributed without permission.

The data used in this project was obtained from mocap.cs.cmu.edu. The database was created with funding from NSF EIA-0196217.

