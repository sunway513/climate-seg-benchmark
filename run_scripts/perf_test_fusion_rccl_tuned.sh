export NCCL_P2P_LEVEL=4
export HSA_FORCE_FINE_GRAIN_PCIE=1
export NCCL_MIN_NRINGS=4
export NCCL_DEBUG=INFO
export TF_ROCM_FUSION_ENABLE=1

NUM_GPUS=1 bash run_rocm.sh |& tee 1gpu-perf-fusion-rccl-tuned
NUM_GPUS=2 bash run_rocm.sh |& tee 2gpu-perf-fusion-rccl-tuned
NUM_GPUS=4 bash run_rocm.sh |& tee 4gpu-perf-fusion-rccl-tuned
NUM_GPUS=6 bash run_rocm.sh |& tee 6gpu-perf-fusion-rccl-tuned
NUM_GPUS=8 bash run_rocm.sh |& tee 8gpu-perf-fusion-rccl-tuned

