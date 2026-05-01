@echo off
setlocal

cd /d "%~dp0"

set "PYTHON_EXE=%~dp0.venv39\Scripts\python.exe"
if not exist "%PYTHON_EXE%" set "PYTHON_EXE=%~dp0.venv\Scripts\python.exe"

if not exist "%PYTHON_EXE%" (
    echo [ERROR] Khong tim thay python trong .venv39 hoac .venv
    pause
    exit /b 1
)

set "PORT=50082"
set "EXPERIMENT=fedhm_lvl2_20c_p10_3s_b4_e1_r60_split3710"

echo Running %EXPERIMENT% on port %PORT%
echo Python: %PYTHON_EXE%

"%PYTHON_EXE%" -u -W ignore run_gloo.py ^
  --port %PORT% ^
  --arch resnet18_1 ^
  --complex_arch master=resnet18_1,worker=resnet18_1:resnet18_2:resnet18_4,num_clients_per_model=3:7:10 ^
  --partition_data non_iid_dirichlet ^
  --pin_memory False ^
  --batch_size 4 ^
  --img_size 32 ^
  --num_workers 0 ^
  --train_data_ratio 1 ^
  --val_data_ratio 0 ^
  --val_dataset 0 ^
  --n_clients 20 ^
  --n_comm_rounds 60 ^
  --local_n_epochs 1 ^
  --world_conf 0,0,1,1,100 ^
  --on_cuda True ^
  --optimizer sgd ^
  --lr 0.1 ^
  --lr_warmup False ^
  --lr_scheduler MultiStepLR ^
  --lr_decay 0.1 ^
  --lr_milestones 40,50 ^
  --weight_decay 1e-4 ^
  --use_nesterov False ^
  --momentum_factor 0.9 ^
  --low_rank True ^
  --pruning False ^
  --dynamic True ^
  --freeze_bn True ^
  --need_scaler False ^
  --warmup_rounds 0 ^
  --track_time True ^
  --display_tracked_time True ^
  --python_path "%PYTHON_EXE%" ^
  --hostfile hostfile ^
  --manual_seed 0 ^
  --pn_normalize True ^
  --same_seed_process True ^
  --experiment %EXPERIMENT% ^
  --data cifar10 ^
  --non_iid_alpha 0.1 ^
  --participation_ratio 0.1 ^
  --group_norm_num_groups 0 ^
  --unit False ^
  --split_mix False ^
  --fl_aggregate scheme=federated_average ^
  --self_distillation 0 ^
  --global_rate 1

set "EXIT_CODE=%ERRORLEVEL%"
echo.
echo Process finished with exit code %EXIT_CODE%.
pause
exit /b %EXIT_CODE%