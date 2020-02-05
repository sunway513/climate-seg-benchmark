#!/bin/bash
#SBATCH -J climseg-cgpu
#SBATCH -C gpu
#SBATCH --ntasks-per-node=8
#SBATCH --gres=gpu:8
#SBATCH --exclusive
#SBATCH -d singleton
#SBATCH -t 4:00:00
#SBATCH -o %x-%j.out

# Job parameters
do_stage=false
ntrain=-1
nvalid=-1
ntest=0
batch=1
#epochs=128
epochs=1
prec=16
grad_lag=1
scale_factor=0.1
loss_type=weighted #weighted_mean
num_gpus=$NUM_GPUS

# Parse command line options
while (( "$#" )); do
    case "$1" in
        --ntrain)
            ntrain=$2
            shift 2
            ;;
        --nvalid)
            nvalid=$2
            shift 2
            ;;
        --ntest)
            ntest=$2
            shift 2
            ;;
        --epochs)
            epochs=$2
            shift 2
            ;;
        --dummy)
            other_train_opts="--dummy_data"
            shift
            ;;
        -*|--*=)
            echo "Error: Unsupported flag $1" >&2
            exit 1
            ;;
    esac
done

# Software setup
#module load tensorflow/gpu-1.15.0-py37
export OMP_PLACES=threads
export OMP_PROC_BIND=spread
export HDF5_USE_FILE_LOCKING=FALSE

# Setup directories
datadir=/climate-seg/portal.nersc.gov/project/dasrepo/deepcam/climseg-data-small
scratchdir=${datadir} # no staging
run_dir=$SCRATCH/climate-seg-benchmark/run_cgpu/run_training
mkdir -p ${run_dir}

# Prepare the run directory
cp stage_in_parallel.sh ${run_dir}/
cp ../utils/parallel_stagein.py ${run_dir}/
cp ../utils/graph_flops.py ${run_dir}/
cp ../utils/tracehook.py ${run_dir}/
cp ../utils/common_helpers.py ${run_dir}/
cp ../utils/data_helpers.py ${run_dir}/
cp ../deeplab-tf/deeplab-tf-train.py ${run_dir}/
cp ../deeplab-tf/deeplab-tf-inference.py ${run_dir}/
cp ../deeplab-tf/deeplab_model.py ${run_dir}/
cd ${run_dir}

# Stage data if relevant
if [ "${scratchdir}" != "${datadir}" ]; then
    if $do_stage; then
        cmd="srun --mpi=pmi2 -N ${SLURM_NNODES} -n ${SLURM_NNODES} -c 80 ./stage_in_parallel.sh ${datadir} ${scratchdir} ${ntrain} ${nvalid} ${ntest}"
        echo ${cmd}
        ${cmd}
    fi
else
    echo "Scratchdir and datadir is the same, no staging needed!"
fi

# Run the training
if [ $ntrain -ne 0 ]; then
    echo "Starting Training"
    time mpirun -np $num_gpus python3 -u deeplab-tf-train.py \
        --datadir_train ${scratchdir}/train \
        --train_size ${ntrain} \
        --datadir_validation ${scratchdir}/validation \
        --validation_size ${nvalid} \
        --chkpt_dir checkpoint.fp${prec}.lag${grad_lag} \
        --disable_checkpoint \
        --epochs $epochs \
        --fs global \
        --loss $loss_type \
        --optimizer opt_type=LARC-Adam,learning_rate=0.0001,gradient_lag=${grad_lag} \
        --model "resnet_v2_50" \
        --scale_factor $scale_factor \
        --batch $batch \
        --decoder "deconv1x" \
        --device "/device:cpu:0" \
        --dtype "float${prec}" \
        --label_id 0 \
        --data_format "channels_first" \
        $other_train_opts |& tee out.fp${prec}.lag${grad_lag}.train
fi

if [ $ntest -ne 0 ]; then
    echo "Starting Testing"
    time mpirun -np $num_gpus  python3 -u deeplab-tf-inference.py \
        --datadir_test ${scratchdir}/test \
        --chkpt_dir checkpoint.fp${prec}.lag${grad_lag} \
        --test_size ${ntest} \
        --output_graph deepcam_inference.pb \
        --output output_test_5 \
        --fs "local" \
        --loss $loss_type \
        --model "resnet_v2_50" \
        --scale_factor $scale_factor \
        --batch $batch \
        --decoder "deconv1x" \
        --device "/device:cpu:0" \
        --dtype "float${prec}" \
        --label_id 0 \
        --data_format "channels_last" |& tee out.fp${prec}.lag${grad_lag}.test
fi
