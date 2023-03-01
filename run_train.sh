#!/usr/bin/env bash

SRD="$HOME"/data/stanza_resources/ru/
SED="$HOME"/data/stanza_resources/en/
run_ru_train() {
    python -m stanza.utils.datasets.prepare_pos_treebank UD_Russian-Tag4f2

    python -m stanza.utils.training.run_pos UD_Russian-Tag4f2 \
        --save_name ru_tag4f2_tagger_f2-1-e.pt \
        --max_steps_before_stop 6000 \
        --batch_size 10000 \
        --dropout 0.25 --word_dropout 0.2 \
        --lr 0.001 \
        --wordvec_pretrain_file $SRD/pretrain/emb2-5.pt \
        --pretrain_max_vocab 350004 \
        --charlm_forward_file $SRD/forward_charlm/newswiki.pt \
        --charlm_backward_file $SRD/backward_charlm/newswiki.pt

    python -m stanza.utils.datasets.prepare_depparse_treebank UD_Russian-Tag4f2 \
        --wordvec_pretrain_file  $SRD/pretrain/emb2-5.pt \
        --tagger_model saved_models/pos/ru_tag4f2_tagger_f2-1-e.pt --charlm default

    python -m stanza.utils.training.run_depparse UD_Russian-Tag4f2 \
        --wordvec_pretrain_file $SRD/pretrain/emb2-5.pt \
        --max_steps_before_stop 6000 \
        --batch_size 8000 \
        --dropout 0.25 --word_dropout 0.2 \
        --lr 0.001 \
        --eval_interval 800 \
        --pretrain_max_vocab 350004 \
        --save_name ru_tag4f2_parser_f1-2-2-e.pt
}

run_en_train(){

    python -m stanza.utils.datasets.prepare_pos_treebank UD_English-Tag4f2

    python -m stanza.utils.training.run_pos UD_English-Tag4f2 \
        --save_name en_tag4f2_tagger_f1-3-e.pt \
        --batch_size 8000 \
        --max_steps_before_stop 6000 \
        --dropout 0.25 --word_dropout 0.2 \
        --wordvec_pretrain_file $SED/pretrain/emb2-5.pt \
        --pretrain_max_vocab 350004 \
        --charlm_forward_file $SED/forward_charlm/1billion.pt \
        --charlm_backward_file $SED/backward_charlm/1billion.pt

    python -m stanza.utils.datasets.prepare_depparse_treebank UD_English-Tag2f2 \
        --wordvec_pretrain_file  $SED/pretrain/emb2-5.pt \
        --tagger_model saved_models/pos/en_tag4f2_tagger_f1-3-e.pt --charlm default

    python -m stanza.utils.training.run_depparse UD_English-Tag2f2 \
        --wordvec_pretrain_file $SED/pretrain/emb2-5.pt \
        --batch_size 8000 \
        --max_steps_before_stop 6000 \
        --dropout 0.25 --word_dropout 0.2 \
        --lr 0.001 \
        --eval_interval 800 \
        --pretrain_max_vocab 350004 \
        --save_name en_tag2f2_parser_f1-3-e.pt
}

run_ruen_train() {
    python -m stanza.utils.datasets.prepare_pos_treebank UD_Russian-Ruen1

    python -m stanza.utils.training.run_pos UD_Russian-ruen1 \
    --save_name ru_ruen1_tagger_f1-2-e.pt \
    --max_steps_before_stop 6000 \
    --no_charlm \
    --batch_size 10000 \
    --dropout 0.25 --word_dropout 0.2 \
    --wordvec_pretrain_file $SRD/pretrain/embC-1.pt \
    --pretrain_max_vocab 650004

    python -m stanza.utils.datasets.prepare_depparse_treebank UD_Russian-ruen2 \
        --wordvec_pretrain_file  $SRD/pretrain/embC-1.pt \
        --tagger_model saved_models/pos/ru_ruen1_tagger_f1-2-e.pt --no_charlm

    python -m stanza.utils.training.run_depparse UD_Russian-ruen2 \
        --wordvec_pretrain_file $SRD/pretrain/embC-1.pt \
        --batch_size 8000 \
        --max_steps_before_stop 6000 \
        --max_steps 80_000 \
        --dropout 0.25 --word_dropout 0.2 \
        --lr 0.001 \
        --eval_interval 800 \
        --pretrain_max_vocab 650004 \
        --save_name ru_ruen2_parser_f1-3-e.pt
}

run_ru_train
run_en_train
run_ruen_train
