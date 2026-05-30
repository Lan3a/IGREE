- IGREE -- IG Reels Emotion EEG study
- Named it just thought it sounds cool enough
<br/>


Project structure: <br/>
```bash
IG_Reels_Emotion_EEG/
├── data/
│   ├── case_by_case/
│   │   ├── G2P_1/
│   │   │   └── *1
│   │   ├── P2G_1/
│   │   └── ...
│   ├── incorrect_raw_eeg/           # all .set files
│   ├── correct_raw_eeg/             # all .set files
│   └── preprocess_eeg/              # contain subfolders with all .set files
├── MATLAB/                          # this repo
│   ├── eeg_shared_functions/        # submodule
│   └── (the rest of the scripts)
└── (other repos)

*1 
├── G2P_1.ceo              # curry raw EEG file
├── G2P_1.dap              # curry raw EEG file
├── G2P_1.dat              # curry raw EEG file
├── G2P_1.rs3              # curry raw EEG file
├── G2P_1_face.mp4
├── G2P_1_SAM2.csv  
├── G2P_1_SAM2.csv
└── g2p_1_vid_duration.csv
```
<br/>


Submodules are included in this repo, do:<br/>
```
git clone --recurse-submodules https://github.com/Lan3a/IGREE.git
```

You can always update submodules (or download them with --init flag if forgot before): <br/>
```
git submodule update --recursive
```
<br/>


tip:
```
git config --global submodule.recurse true
git config --global push.recurseSubmodules on-demand
```

This will make push/pull to also affect submodules automatically <br/>


