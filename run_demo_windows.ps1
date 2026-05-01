param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('fedhm', 'fedavg', 'heterofl', 'split_mix', 'all')]
    [string]$Mode,

    [string]$PythonPath = '.\.venv39\Scripts\python.exe',
    [int]$Clients = 10,
    [int]$CommRounds = 5,
    [int]$LocalEpochs = 1,
    [double]$ParticipationRatio = 0.5,
    [double]$Alpha = 0.0,
    [int]$Gpu = 0,
    [int]$BatchSize = 64,
    [int]$NumWorkers = 2,
    [int]$PortBase = 50030,
    [switch]$DryRun
)

$ErrorActionPreference = 'Stop'

function Get-ClientSplit {
    param(
        [int]$TotalClients,
        [int]$GroupCount
    )

    if ($GroupCount -le 1) {
        return "$TotalClients"
    }

    $baseCount = [math]::Floor($TotalClients / $GroupCount)
    $remainder = $TotalClients % $GroupCount
    $counts = @()
    for ($index = 0; $index -lt $GroupCount; $index++) {
        if ($index -lt $remainder) {
            $counts += ($baseCount + 1)
        }
        else {
            $counts += $baseCount
        }
    }

    return ($counts -join ':')
}

function Invoke-DemoRun {
    param(
        [string]$RunMode,
        [int]$RunPort
    )

    switch ($RunMode) {
        'fedhm' {
            $masterArch = 'resnet18_1'
            $workerArch = 'resnet18_1:resnet18_2:resnet18_4'
            $globalRate = '1'
            $lowRank = 'True'
            $pruning = 'False'
            $dynamic = 'True'
            $freezeBn = 'True'
            $needScaler = 'False'
            $splitMix = 'False'
        }
        'fedavg' {
            $masterArch = 'resnet18'
            $workerArch = 'resnet18'
            $globalRate = '1'
            $lowRank = 'False'
            $pruning = 'False'
            $dynamic = 'False'
            $freezeBn = 'False'
            $needScaler = 'False'
            $splitMix = 'False'
        }
        'heterofl' {
            $masterArch = 'resnet18_1'
            $workerArch = 'resnet18_1:resnet18_0.64:resnet18_0.5'
            $globalRate = '1'
            $lowRank = 'False'
            $pruning = 'True'
            $dynamic = 'True'
            $freezeBn = 'True'
            $needScaler = 'True'
            $splitMix = 'False'
        }
        'split_mix' {
            $masterArch = 'ensresnet18_3.15'
            $workerArch = 'ensresnet18_3.15:ensresnet18_1.05:ensresnet18_0.7'
            $globalRate = '1'
            $lowRank = 'False'
            $pruning = 'True'
            $dynamic = 'False'
            $freezeBn = 'True'
            $needScaler = 'True'
            $splitMix = 'True'
        }
        default {
            throw "Unsupported demo mode: $RunMode"
        }
    }

    $workerArchs = $workerArch.Split(':')
    $clientSplit = Get-ClientSplit -TotalClients $Clients -GroupCount $workerArchs.Count
    $partitionType = if ($Alpha -eq 0) { 'origin' } else { 'non_iid_dirichlet' }
    $experimentName = "demo_${RunMode}_cifar10_r${CommRounds}_n${Clients}"
    $logDir = Join-Path $PSScriptRoot 'demo_logs'
    New-Item -ItemType Directory -Path $logDir -Force | Out-Null
    $logPath = Join-Path $logDir "${experimentName}.log"

    $commandArgs = @(
        '-u',
        '-W', 'ignore',
        'run_gloo.py',
        '--arch', $masterArch,
        '--complex_arch', "master=$masterArch,worker=$workerArch,num_clients_per_model=$clientSplit",
        '--pin_memory', 'True',
        '--batch_size', "$BatchSize",
        '--img_size', '32',
        '--num_workers', "$NumWorkers",
        '--partition_data', $partitionType,
        '--train_data_ratio', '1',
        '--val_data_ratio', '0',
        '--val_dataset', '0',
        '--n_clients', "$Clients",
        '--n_comm_rounds', "$CommRounds",
        '--local_n_epochs', "$LocalEpochs",
        '--world_conf', '0,0,1,1,100',
        '--on_cuda', 'True',
        '--optimizer', 'sgd',
        '--lr', '0.1',
        '--lr_warmup', 'False',
        '--lr_scheduler', 'MultiStepLR',
        '--lr_decay', '0.1',
        '--lr_milestones', '3,4',
        '--weight_decay', '1e-4',
        '--use_nesterov', 'False',
        '--momentum_factor', '0.9',
        '--low_rank', $lowRank,
        '--pruning', $pruning,
        '--dynamic', $dynamic,
        '--freeze_bn', $freezeBn,
        '--need_scaler', $needScaler,
        '--warmup_rounds', '0',
        '--track_time', 'True',
        '--display_tracked_time', 'True',
        '--python_path', (Resolve-Path $PythonPath).Path,
        '--hostfile', 'hostfile',
        '--manual_seed', '0',
        '--pn_normalize', 'True',
        '--same_seed_process', 'True',
        '--experiment', $experimentName,
        '--data', 'cifar10',
        '--non_iid_alpha', "$Alpha",
        '--participation_ratio', "$ParticipationRatio",
        '--group_norm_num_groups', '0',
        '--unit', 'False',
        '--split_mix', $splitMix,
        '--fl_aggregate', 'scheme=federated_average',
        '--self_distillation', '0',
        '--global_rate', $globalRate,
        '--port', "$RunPort"
    )

    $commandText = @((Resolve-Path $PythonPath).Path) + $commandArgs
    Write-Host "=== $RunMode ==="
    Write-Host ($commandText -join ' ')
    Write-Host "log: $logPath"

    if ($DryRun) {
        return
    }

    $env:CUDA_VISIBLE_DEVICES = "$Gpu"
    $resolvedPythonPath = (Resolve-Path $PythonPath).Path
    $stderrPath = [System.IO.Path]::ChangeExtension($logPath, '.stderr.log')
    if (Test-Path $stderrPath) {
        Remove-Item $stderrPath -Force
    }

    $process = Start-Process `
        -FilePath $resolvedPythonPath `
        -ArgumentList $commandArgs `
        -NoNewWindow `
        -Wait `
        -PassThru `
        -RedirectStandardOutput $logPath `
        -RedirectStandardError $stderrPath

    if (Test-Path $logPath) {
        Get-Content $logPath
    }
    if (Test-Path $stderrPath) {
        Get-Content $stderrPath
    }

    if ($process.ExitCode -ne 0) {
        throw "Run failed for mode '$RunMode'. Check $logPath"
    }
}

if (-not (Test-Path $PythonPath)) {
    throw "Python interpreter not found at $PythonPath"
}

if ($Mode -ne 'all') {
    Invoke-DemoRun -RunMode $Mode -RunPort $PortBase
    return
}

$modesToRun = @('fedhm', 'fedavg', 'heterofl', 'split_mix')
for ($index = 0; $index -lt $modesToRun.Count; $index++) {
    Invoke-DemoRun -RunMode $modesToRun[$index] -RunPort ($PortBase + $index)
}