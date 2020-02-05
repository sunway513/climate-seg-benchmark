
export TF_ROCM_FUSION_ENABLE=1
NUM_GPUS=1 bash run_rocm.sh |& tee 1gpu-perf-fusion
NUM_GPUS=2 bash run_rocm.sh |& tee 2gpu-perf-fusion
NUM_GPUS=4 bash run_rocm.sh |& tee 4gpu-perf-fusion
NUM_GPUS=6 bash run_rocm.sh |& tee 6gpu-perf-fusion
NUM_GPUS=8 bash run_rocm.sh |& tee 8gpu-perf-fusion

