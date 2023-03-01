#!/usr/bin/env sh


SRD=/home/dvzubarev/stanza_resources/ru/
SED=/home/dvzubarev/stanza_resources/en/

# * functions

make_ru_custom(){
    local tok_model="$1"
    local tag_model="$2"
    local lemma_model="$3"
    local parse_model="$4"

    ln -sf "$(pwd)"/saved_models/tokenize/"$tok_model".pt saved_models/tokenize/ru_custom_tokenizer.pt
    ln -sf "$(pwd)"/saved_models/pos/"$tag_model".pt saved_models/pos/ru_custom_tagger.pt
    ln -sf "$LEMMA_DATA_DIR/ru_pudfixed.train.in.conllu" "$LEMMA_DATA_DIR/ru_custom.train.in.conllu"
    ln -sf "$(pwd)"/saved_models/lemma/"$lemma_model".pt saved_models/lemma/ru_custom_lemmatizer.pt
    ln -sf "$(pwd)"/saved_models/depparse/"$parse_model".pt saved_models/depparse/ru_custom_parser.pt



}

make_en_custom(){
    local tok_model="$1"
    local tag_model="$2"
    local lemma_model="$3"
    local parse_model="$4"

    ln -sf "$(pwd)"/saved_models/tokenize/"$tok_model".pt saved_models/tokenize/en_custom_tokenizer.pt
    ln -sf "$(pwd)"/saved_models/pos/"$tag_model".pt saved_models/pos/en_custom_tagger.pt
    ln -sf "$LEMMA_DATA_DIR/en_pudfixed.train.in.conllu" "$LEMMA_DATA_DIR/en_custom.train.in.conllu"
    ln -sf "$(pwd)"/saved_models/lemma/"$lemma_model".pt saved_models/lemma/en_custom_lemmatizer.pt
    ln -sf "$(pwd)"/saved_models/depparse/"$parse_model".pt saved_models/depparse/en_custom_parser.pt



}

run_ete() {
    local run_id=$1
    local test_treebank=$2
    local emb=$3
    export ETE_RUN_ID="$run_id"
    export ETE_DATASET=${test_treebank#*-}
    python -m stanza.utils.training.run_ete UD_Russian-Custom \
        --test_data "$test_treebank" \
        --score_test \
        --wordvec_pretrain_file $SRD/pretrain/$emb.pt 2> log



}

run_en_ete() {
    local run_id=$1
    local test_treebank=$2
    local emb=$3
    export ETE_RUN_ID="$run_id"
    export ETE_DATASET=${test_treebank#*-}
    python -m stanza.utils.training.run_ete UD_English-Custom \
        --test_data "$test_treebank" \
        --score_test \
        --wordvec_pretrain_file $SED/pretrain/$emb.pt 2> log



}


# * ru
make_ru_custom ru_tok1_tokenizer_4-3 ru_tag4f2_tagger_f2-1-e ru_tag4f_lemma_dict ru_tag4f2_parser_f1-2-2-e

run_ete test UD_Russian-Tag4f2 emb2-5
run_ete test UD_Russian-SynTagFixed emb2-5
run_ete test UD_Russian-TaigaFixed emb2-5
run_ete test UD_Russian-PUDFixed emb2-5

# * en
make_en_custom ru_tok1_tokenizer_4-3 en_tag4f2_tagger_f1-3-e ru_tag4f_lemma_dict en_tag2f2_parser_f1-3-e

run_en_ete test UD_English-Tag2f2 emb2-5
run_en_ete test UD_English-GUMFixed emb2-5
run_en_ete test UD_English-EWTFixed emb2-5
run_en_ete test UD_English-PUDFixed emb2-5


# * ru-en
make_ru_custom ru_tok1_tokenizer_4-3 ru_ruen1_tagger_f1-2-e ru_tag4f_lemma_dict ru_ruen2_parser_f1-3-e

run_ete test UD_Russian-SynTagFixed embC-1
run_ete test UD_Russian-TaigaFixed embC-1
run_ete test UD_Russian-PUDFixed embC-1

run_ete test UD_English-PUDFixed embC-1
run_ete test UD_English-GUMFixed embC-1
run_ete test UD_English-EWTFixed embC-1
