"""
Runs a pipeline end-to-end, reports conll scores.

For example, you can do
  python3 stanza/utils/training/run_ete.py it_isdt --score_test
You can run on all models at once:
  python3 stanza/utils/training/run_ete.py ud_all --score_test

You can also run one model on a different model's data:
  python3 stanza/utils/training/run_ete.py it_isdt --score_dev --test_data it_vit
  python3 stanza/utils/training/run_ete.py it_isdt --score_test --test_data it_vit

Running multiple models with a --test_data flag will run them all on the same data:
  python3 stanza/utils/training/run_ete.py it_combined it_isdt it_vit --score_test --test_data it_vit

If run with no dataset arguments, then the dataset used is the train
data, which may or may not be useful.
"""

import logging
import os
import shutil
import tempfile
import time
from typing import List, Tuple

from stanza.models import identity_lemmatizer
from stanza.models import lemmatizer
from stanza.models import mwt_expander
from stanza.models import parser
from stanza.models import tagger
from stanza.models import tokenizer
import stanza.models.common.doc as common_doc
from stanza.models.common.constant import treebank_to_short_name


from stanza.resources.prepare_resources import default_charlms, pos_charlms

from stanza.utils.training import common
from stanza.utils.training.common import Mode, build_charlm_args, choose_charlm
from stanza.utils.training.run_lemma import check_lemmas
from stanza.utils.training.run_mwt import check_mwt
from stanza.utils.training.run_pos import wordvec_args
from stanza.utils.conll import CoNLL

from udpipe_ext.tokenization import Tokenizer
from udpipe_ext.segmentator import Segmentator

logger = logging.getLogger('stanza')


# a constant so that the script which looks for these results knows what to look for
RESULTS_STRING = "End to end results for"

def add_args(parser):
    parser.add_argument('--test_data', default=None, type=str, help='Which data to test on, if not using the default data for this model')
    common.add_charlm_args(parser)

ReturnType = Tuple[List[str], List[Tuple[int, int]]]

def _rule_based_tokenization(input_file, output_conllu):
    with open(input_file, encoding='utf8') as inpf:
        text = inpf.read()
    rb_tokenizer = Tokenizer()
    segmentator = Segmentator()
    bt = time.time()
    result: ReturnType = segmentator.segment(text)
    print('segment time', time.time() - bt)
    sents, sent_offsets = result
    doc_dict = []
    for sent in sents:
        tokens = [ss.text for ss in rb_tokenizer(sent)]
        if tokens and tokens[-1].endswith('.') and tokens[-1][0].isalpha():
            last = tokens[-1]
            tokens[-1] = last[:-1]
            tokens.append('.')

        conllu_sent = []
        for num, tok in enumerate(tokens):
            conllu_sent.append(
                {
                    common_doc.ID: num+1,
                    common_doc.TEXT: tok
                }
            )
        doc_dict.append(conllu_sent)
    CoNLL.dict2conll(doc_dict, output_conllu)
    # CoNLL.dict2conll(doc_dict, '/tmp/temp1.conllu')




def run_ete(paths, dataset, short_name, command_args, extra_args):
    short_language, package = short_name.split("_")

    tokenize_dir = paths["TOKENIZE_DATA_DIR"]
    mwt_dir      = paths["MWT_DATA_DIR"]
    lemma_dir    = paths["LEMMA_DATA_DIR"]
    ete_dir      = paths["ETE_DATA_DIR"]
    wordvec_dir  = paths["WORDVEC_DIR"]

    timings = {}
    # run models in the following order:
    #   tokenize
    #   mwt, if exists
    #   pos
    #   lemma, if exists
    #   depparse
    # the output of each step is either kept or discarded based on the
    # value of command_args.save_output

    if command_args and command_args.test_data:
        test_short_name = treebank_to_short_name(command_args.test_data)
    else:
        test_short_name = short_name

    # TOKENIZE step
    # the raw data to process starts in tokenize_dir
    # retokenize it using the saved model
    tokenizer_type = "--txt_file"
    tokenizer_file = f"{tokenize_dir}/{test_short_name}.{dataset}.txt"

    tokenizer_output = f"{ete_dir}/{short_name}.{dataset}.tokenizer.conllu"

    tokenizer_args = ["--mode", "predict", tokenizer_type, tokenizer_file, "--lang", short_language,
                      "--conll_file", tokenizer_output, "--shorthand", short_name]
    # tokenizer_args = tokenizer_args + extra_args
    tokenizer_args += ['--batch_size', '3000']
    logger.info("-----  TOKENIZER  ----------")
    logger.info("Running tokenizer step with args: {}".format(tokenizer_args))
    bt = time.time()
    # tokenizer.main(tokenizer_args)
    _rule_based_tokenization(tokenizer_file, tokenizer_output)
    timings['tokenizer'] = time.time() - bt

    # If the data has any MWT in it, there should be an MWT model
    # trained, so run that.  Otherwise, we skip MWT
    mwt_train_file = f"{mwt_dir}/{short_name}.train.in.conllu"
    logger.info("-----  MWT        ----------")
    if check_mwt(mwt_train_file):
        mwt_output = f"{ete_dir}/{short_name}.{dataset}.mwt.conllu"
        mwt_args = ['--eval_file', tokenizer_output,
                    '--output_file', mwt_output,
                    '--lang', short_language,
                    '--shorthand', short_name,
                    '--mode', 'predict']
        # mwt_args = mwt_args + extra_args
        logger.info("Running mwt step with args: {}".format(mwt_args))
        bt = time.time()
        mwt_expander.main(mwt_args)
        timings['mwt'] = time.time() - bt
    else:
        logger.info("No MWT in training data.  Skipping")
        mwt_output = tokenizer_output

    # Run the POS step
    # TODO: add batch args
    logger.info("-----  POS        ----------")
    pos_output = f"{ete_dir}/{short_name}.{dataset}.pos.conllu"
    pos_args = ['--wordvec_dir', wordvec_dir,
                '--eval_file', mwt_output,
                '--output_file', pos_output,
                '--lang', short_name,
                '--shorthand', short_name,
                '--mode', 'predict']

    # TODO: refactor these args.  Possibly just put this in common as a single function call,
    # build_charlm_args_pos or something like that
    charlm = choose_charlm(short_language, package, command_args.charlm, default_charlms, pos_charlms)
    charlm_args = build_charlm_args(short_language, charlm)

    pos_args = pos_args + wordvec_args(short_language, package, extra_args) + charlm_args + extra_args
    logger.info("Running pos step with args: {}".format(pos_args))
    bt = time.time()
    tagger.main(pos_args)
    timings['pos'] = time.time() - bt


    # Run the LEMMA step.  If there are no lemmas in the training
    # data, use the identity lemmatizer.
    logger.info("-----  LEMMA      ----------")
    lemma_train_file = f"{lemma_dir}/{short_name}.train.in.conllu"
    lemma_output = f"{ete_dir}/{short_name}.{dataset}.lemma.conllu"
    lemma_args = ['--eval_file', pos_output,
                  '--output_file', lemma_output,
                  '--lang', short_name,
                  '--mode', 'predict']
    # lemma_args = lemma_args + extra_args
    lemma_args = lemma_args + ['--batch_size', '5000']
    if check_lemmas(lemma_train_file):
        logger.info("Running lemmatizer step with args: {}".format(lemma_args))
        bt = time.time()
        lemmatizer.main(lemma_args)
        timings['lemma'] = time.time() - bt
    else:
        logger.info("No lemmas in training data")
        logger.info("Running identity lemmatizer step with args: {}".format(lemma_args))
        bt = time.time()
        identity_lemmatizer.main(lemma_args)
        timings['lemma'] = time.time() - bt

    # Run the DEPPARSE step.  This is the last step
    # Note that we do NOT use the depparse directory's data.  That is
    # because it has either gold tags, or predicted tags based on
    # retagging using gold tokenization, and we aren't sure which at
    # this point in the process.
    # TODO: add batch args
    logger.info("-----  DEPPARSE   ----------")
    depparse_output = f"{ete_dir}/{short_name}.{dataset}.depparse.conllu"
    depparse_args = ['--wordvec_dir', wordvec_dir,
                     '--eval_file', lemma_output,
                     '--output_file', depparse_output,
                     '--lang', short_name,
                     '--shorthand', short_name,
                     '--mode', 'predict']
    depparse_args = depparse_args + wordvec_args(short_language, package, extra_args) + extra_args
    logger.info("Running depparse step with args: {}".format(depparse_args))

    bt = time.time()
    parser.main(depparse_args)
    timings['depparse'] = time.time() - bt

    logger.info("-----  EVALUATION ----------")
    gold_file = f"{tokenize_dir}/{test_short_name}.{dataset}.gold.conllu"
    ete_file = depparse_output
    results = common.run_eval_script(gold_file, ete_file, return_raw_eval=True)
    # logger.info("{} {} models on {} {} data:\n{}".format(RESULTS_STRING, short_name, test_short_name, dataset, results))

    run_id =os.environ.get("ETE_RUN_ID", "UNK_ID")
    dataset =os.environ.get("ETE_DATASET", "UNK_DATASET")
    fmt_fn = lambda fl : '%.2f' % fl
    metr_fn = lambda fl : '%.2f' % (100.0 * fl) if fl is not None else '-'
    common_prefix=f'{run_id},{dataset},'

    FIELDS = {'Tokens', 'Sentences', 'Words', 'UPOS', 'UFeats', 'Lemmas', 'LAS', 'CLAS', 'MLAS', 'BLEX'}

    headers = ['run_id', 'dataset', 'metric'] + list(k for k in results.keys() if k in FIELDS)
    print(','.join(headers))
    f1_vals = ','.join(metr_fn(val.f1) for k,val in results.items() if k in FIELDS)
    print(common_prefix + 'f1,' + f1_vals)
    aa_vals = ','.join(metr_fn(val.aligned_accuracy) for k,val in results.items() if k in FIELDS)
    print(common_prefix + 'aln_acc,' + aa_vals)

    headers = ['run_id', 'dataset', 'tok', 'mwt', 'pos', 'lemma', 'dep', 'total']
    total = sum(timings.values())
    timing_str = ','.join((fmt_fn(timings["tokenizer"]), fmt_fn(timings.get("mwt", 0)),
                    fmt_fn(timings["pos"]), fmt_fn(timings["lemma"]),
                    fmt_fn(timings["depparse"]), fmt_fn(total)))
    print(','.join(headers))
    print(common_prefix + timing_str)



def run_treebank(mode, paths, treebank, short_name,
                 temp_output_file, command_args, extra_args):
    if mode == Mode.TRAIN:
        dataset = 'train'
    elif mode == Mode.SCORE_DEV:
        dataset = 'dev'
    elif mode == Mode.SCORE_TEST:
        dataset = 'test'

    if command_args.temp_output:
        with tempfile.TemporaryDirectory() as ete_dir:
            paths = dict(paths)
            paths["ETE_DATA_DIR"] = ete_dir
            run_ete(paths, dataset, short_name, command_args, extra_args)
    else:
        os.makedirs(paths["ETE_DATA_DIR"], exist_ok=True)
        run_ete(paths, dataset, short_name, command_args, extra_args)

def main():
    common.main(run_treebank, "ete", "ete", add_args)

if __name__ == "__main__":
    main()

