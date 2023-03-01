#!/usr/bin/env bash


SRD="$HOME"/data/stanza_resources/ru
SED="$HOME"/data/stanza_resources/en

# * functions

test_ru_tagger() {
    local train_data=$1
    local test_treebank=$2
    local conf=$3
    local emb=$4
    echo $test_treebank, $conf
    python -m stanza.utils.training.run_pos "$test_treebank" \
        --score_test \
        --pretrain_max_vocab 650004 \
        --wordvec_pretrain_file $SRD/pretrain/$emb.pt \
        --charlm_forward_file $SRD/forward_charlm/newswiki.pt \
        --charlm_backward_file $SRD/backward_charlm/newswiki.pt \
        --save_name ru_${train_data}_tagger_$conf.pt 2>&1 | grep -A1 'UFeats'

}
test_ru_parser(){
    local train_data=$1
    local test_treebank=$2
    local conf=$3
    local emb=$4
    echo $test_treebank, $conf
    python -m stanza.utils.training.run_depparse "$test_treebank" \
        --score_test \
        --pretrain_max_vocab 650004 \
        --wordvec_pretrain_file $SRD/pretrain/$emb.pt \
        --save_name ru_${train_data}_parser_$conf.pt 2>&1 | grep -A1 'LAS'
}


test_en_tagger() {
    local train_data=$1
    local test_treebank=$2
    local conf=$3
    local emb=$4
    echo $test_treebank, $conf
    python -m stanza.utils.training.run_pos "$test_treebank" \
        --score_test \
        --pretrain_max_vocab 650004 \
        --wordvec_pretrain_file $SED/pretrain/$emb.pt \
        --charlm_forward_file $SED/forward_charlm/1billion.pt \
        --charlm_backward_file $SED/backward_charlm/1billion.pt \
        --save_name en_${train_data}_tagger_$conf.pt 2>&1 | grep -A1 'UFeats'

}

test_en_parser(){
    local train_data=$1
    local test_treebank=$2
    local conf=$3
    local emb=$4
    echo $test_treebank, $conf
    python -m stanza.utils.training.run_depparse "$test_treebank" \
        --score_test \
        --pretrain_max_vocab 650004 \
        --wordvec_pretrain_file $SED/pretrain/$emb.pt \
        --save_name en_${train_data}_parser_$conf.pt 2>&1 | grep -A1 'LAS'
}
# * ru eval

for data in Tag4f2 SynTagFixed TaigaFixed PUDFixed ; do
    test_ru_tagger tag4f2 UD_Russian-"$data" f2-1-e emb2-5

    python -m stanza.utils.datasets.prepare_depparse_treebank UD_Russian-"$data" \
        --wordvec_pretrain_file $SRD/pretrain/emb2-5.pt \
        --tagger_model saved_models/pos/ru_tag4f2_tagger_f2-1-e.pt --charlm default

done

for data in Tag4f2 SynTagFixed TaigaFixed PUDFixed ; do
    test_ru_parser tag4f2 UD_Russian-"$data" f1-2-2-e emb2-5
done

# * en eval

for data in Tag4f2 GUMFixed EWTFixed PUDFixed ; do
    test_en_tagger tag4f2 UD_English-"$data" f1-3-e emb2-5

    python -m stanza.utils.datasets.prepare_depparse_treebank UD_English-"$data" \
        --wordvec_pretrain_file $SED/pretrain/emb2-5.pt \
        --tagger_model saved_models/pos/en_tag4f2_tagger_f1-3-e.pt --charlm default

done

for data in Tag2f2 GUMFixed EWTFixed PUDFixed ; do
    test_en_parser tag2f2 UD_English-"$data" f1-3-e emb2-5
done
