@echo off
cd /d D:\FedHM
call .\.venv39\Scripts\activate.bat

set CUDA_VISIBLE_DEVICES=0
set MASTER_ADDR=127.0.0.1
set MASTER_PORT=50051

python -u -W ignore run_gloo.py ^
  --port 50051 ^
  --arch resnet18_1 ^
  --complex_arch master=resnet18_1,worker=resnet18_1:resnet18_2:resnet18_4:resnet18_8,num_clients_per_model=2:2:2:2 ^
  --pin_memory False ^
  --batch_size 8 ^
  --img_size 32 ^
  --num_workers 0 ^
  --partition_data non_iid_dirichlet ^
  --train_data_ratio 1 ^
  --val_data_ratio 0 ^
  --val_dataset 0 ^
  --n_clients 8 ^
  --n_comm_rounds 1 ^
  --local_n_epochs 1 ^
  --world_conf 0,0,1,1,100 ^
  --on_cuda True ^
  --optimizer sgd ^
  --lr 0.1 ^
  --lr_warmup False ^
  --lr_scheduler MultiStepLR ^
  --lr_decay 0.1 ^
  --lr_milestones 1 ^
  --weight_decay 5e-4 ^
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
  --python_path .\.venv39\Scripts\python.exe ^
  --hostfile hostfile ^
  --manual_seed 0 ^
  --pn_normalize True ^
  --same_seed_process True ^
  --experiment fedhm_smoke_1round ^
  --data cifar10 ^
  --non_iid_alpha 0.1 ^
  --participation_ratio 0.25 ^
  --group_norm_num_groups 0 ^
  --unit False ^
  --split_mix False ^
  --fl_aggregate scheme=federated_average ^
  --self_distillation 0 ^
  --global_rate 1

pause