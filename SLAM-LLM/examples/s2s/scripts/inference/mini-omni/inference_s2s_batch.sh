#!/bin/bash
export CUDA_VISIBLE_DEVICES=0
export TOKENIZERS_PARALLELISM=false
export OMP_NUM_THREADS=1
export LD_LIBRARY_PATH=/home/v-wenxichen/anaconda3/envs/slam/lib:$LD_LIBRARY_PATH
export PYDEVD_WARN_SLOW_RESOLVE_TIMEOUT=2
export CUDA_LAUNCH_BLOCKING=1


code_dir=examples/s2s

whisper_size=small  # tiny base small medium large-v3
speech_encoder_path="/valleblob/v-wenxichen/models/whisper/${whisper_size}.pt"   # different whisper size
llm_path="Qwen/Qwen2-0.5B"
codec_decoder_path="hubertsiuzdak/snac_24khz"

encoder_dim=768  # 384 512 768 896 1024 1280 
mel_size=80      # 80 128 (128 for whisper-large only)

tts_adapter=false
task_type=s2s
split_size=0.00001

ckpt_path=/valleblob/v-wenxichen/exp/s2s/s2s_train_v2_gpu4_btz4_lr5e-4_fp16_epochs10/s2s_train_v2_gpu4_btz4_lr5e-4_fp16_epochs10-s2s_epoch_4_step_22946
split=test

# jsonl dataset
# manifest_format=jsonl
# val_data_path=/home/v-wenxichen/SLAM-LLM/examples/s2s/demo/data/${split}.jsonl

# huggingface dataset
manifest_format=parquet
val_data_path="gpt-omni/VoiceAssistant-400K"
load_from_cache_file=true
dataset_sample_seed=777

# decode config
text_repetition_penalty=1.0
audio_repetition_penalty=1.0        # default 1.0, set to 1.2 for reduce silence
max_new_tokens=500
do_sample=false
top_p=0.9
top_k=50
temperature=1.0
decode_text_only=false
upsampling_factor=1

output_text_only=false

inference_online=false
mini_omni_modeling=true

decode_log=$ckpt_path/s2s_decode_${split}_rp${repetition_penalty}_seed${dataset_sample_seed}_greedy
if [ "$do_sample" = true ] ; then
    decode_log=$ckpt_path/s2s_decode_${split}_rp${repetition_penalty}_seed${dataset_sample_seed}_sampling_topk${top_k}_topp${top_p}_temp${temperature}
fi

if [ "$decode_text_only" = true ] ; then
    decode_log=$decode_log"_text_only"
fi

# -m debugpy --listen 5678 --wait-for-client
python $code_dir/inference_s2s.py \
        --config-path "conf" \
        --config-name "prompt.yaml" \
        hydra.run.dir=$ckpt_path \
        ++model_config.llm_name=qwen2-0.5b \
        ++model_config.llm_path=$llm_path \
        ++model_config.llm_dim=896 \
        ++model_config.encoder_name=whisper \
        ++model_config.encoder_projector_ds_rate=5 \
        ++model_config.encoder_path=$speech_encoder_path \
        ++model_config.encoder_dim=$encoder_dim \
        ++model_config.encoder_projector=linear \
        ++model_config.codec_decoder_path=$codec_decoder_path \
        ++model_config.codec_decode=true \
        ++model_config.tts_adapter=$tts_adapter \
        ++dataset_config.dataset=speech_dataset_s2s \
        ++dataset_config.val_data_path=$val_data_path \
        ++dataset_config.train_data_path=$val_data_path \
        ++dataset_config.input_type=mel \
        ++dataset_config.mel_size=$mel_size \
        ++dataset_config.inference_mode=true \
        ++dataset_config.manifest_format=$manifest_format \
        ++dataset_config.split_size=$split_size \
        ++dataset_config.load_from_cache_file=$load_from_cache_file \
        ++dataset_config.task_type=$task_type \
        ++dataset_config.seed=$dataset_sample_seed \
        ++train_config.model_name=s2s \
        ++train_config.freeze_encoder=true \
        ++train_config.freeze_llm=true \
        ++train_config.batching_strategy=custom \
        ++train_config.num_epochs=1 \
        ++train_config.val_batch_size=1 \
        ++train_config.num_workers_dataloader=2 \
        ++train_config.task_type=$task_type \
        ++decode_config.text_repetition_penalty=$text_repetition_penalty \
        ++decode_config.audio_repetition_penalty=$audio_repetition_penalty \
        ++decode_config.max_new_tokens=$max_new_tokens \
        ++decode_config.task_type=$task_type \
        ++decode_config.do_sample=$do_sample \
        ++decode_config.top_p=$top_p \
        ++decode_config.top_k=$top_k \
        ++decode_config.temperature=$temperature \
        ++decode_config.decode_text_only=$decode_text_only \
        ++decode_config.upsampling_factor=$upsampling_factor \
        ++decode_log=$decode_log \
        ++ckpt_path=$ckpt_path/model.pt \
        ++output_text_only=$output_text_only \
        ++inference_online=$inference_online \
        ++mini_omni_modeling=$mini_omni_modeling

# bash /home/v-wenxichen/SLAM-LLM/examples/s2s/scripts/SNAC/inference_s2s_snac.sh