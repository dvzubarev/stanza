"""
Tests specifically for the MultilingualPipeline
"""

import pytest

from stanza.pipeline.multilingual import MultilingualPipeline

from stanza.tests import TEST_MODELS_DIR

pytestmark = [pytest.mark.pipeline, pytest.mark.travis]

def run_multilingual_pipeline(en_has_dependencies=True, fr_has_dependencies=True, **kwargs):
    english_text = "This is an English sentence."
    english_words = ["This", "is", "an", "English", "sentence", "."]
    english_deps_gold = "\n".join((
        "('This', 5, 'nsubj')",
        "('is', 5, 'cop')",
        "('an', 5, 'det')",
        "('English', 5, 'amod')",
        "('sentence', 0, 'root')",
        "('.', 5, 'punct')"
    ))

    french_text = "C'est une phrase française."
    french_words = ["C'", "est", "une", "phrase", "française", "."]
    french_deps_gold = "\n".join((
        "(\"C'\", 4, 'nsubj')",
        "('est', 4, 'cop')",
        "('une', 4, 'det')",
        "('phrase', 0, 'root')",
        "('française', 4, 'amod')",
        "('.', 4, 'punct')"
    ))

    if 'lang_configs' in kwargs:
        nlp = MultilingualPipeline(model_dir=TEST_MODELS_DIR, **kwargs)
    else:
        lang_configs = {"en": {"processors": "tokenize,pos,lemma,depparse"},
                        "fr": {"processors": "tokenize,pos,lemma,depparse"}}
        nlp = MultilingualPipeline(model_dir=TEST_MODELS_DIR, lang_configs=lang_configs, **kwargs)
    docs = [english_text, french_text]
    docs = nlp(docs)

    assert docs[0].lang == "en"
    assert len(docs[0].sentences) == 1
    assert [x.text for x in docs[0].sentences[0].words] == english_words
    if en_has_dependencies:
        assert docs[0].sentences[0].dependencies_string() == english_deps_gold

    assert len(docs[1].sentences) == 1
    assert docs[1].lang == "fr"
    assert [x.text for x in docs[1].sentences[0].words] == french_words
    if fr_has_dependencies:
        assert docs[1].sentences[0].dependencies_string() == french_deps_gold


def test_multilingual_pipeline():
    """
    Basic test of multilingual pipeline
    """
    run_multilingual_pipeline()

def test_multilingual_pipeline_small_cache():
    """
    Test with the cache size 1
    """
    run_multilingual_pipeline(max_cache_size=1)


def test_multilingual_config():
    """
    Test with only tokenize for the EN pipeline
    """
    lang_configs = {
        "en": {"processors": "tokenize"}
    }

    run_multilingual_pipeline(en_has_dependencies=False, lang_configs=lang_configs)
