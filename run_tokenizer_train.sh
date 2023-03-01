#!/usr/bin/env sh

python -m stanza.utils.training.run_tokenizer UD_Russian-Tok1 \
    --max_seqlen 512  --batch_size 256 --steps 55_000 --eval_steps 3_000 \
    --max_steps_before_stop 9_000 --report_steps 100 \
    --dropout 0.2 --unit_dropout 0.1 --feat_unit_dropout 0.1 \
    --save_name ru_tok1_tokenizer_4-3.pt

python -m stanza.utils.training.run_tokenizer UD_Russian-Tok1 \
    --max_seqlen 512  --batch_size 256 --steps 55_000 --eval_steps 3_000 \
    --max_steps_before_stop 9_000 --report_steps 100 \
    --dropout 0.2 --unit_dropout 0.15 --feat_unit_dropout 0.15 \
    --save_name ru_tok1_tokenizer_4-4.pt
