import collections
import zipfile
import json

lang_crowdin = {
    "ar": "ar_ar",
    "bg": "bul_bg",
    "ast": "ast_es",
    "de": "de_de",
    "el": "el_gr",
    "es-ES": "es_es",
    "fa": "fa_ir",
    "fil": "fil_ph",
    "fr": "fr_fr",
    "he": "he_il",
    "hr": "hr_hr",
    "id": "id_id",
    "it": "it_it",
    "ko": "ko_ko",
    "pt-BR": "pt_br",
    "ro": "ro_ro",
    "ru": "ru_ru",
    "tr": "tr_tr",
    "pl": "pl_pl",
    "uk": "uk_ua",
    "hu": "hu_hu",
    "ur-PK": "ur_pk",
    "hi": "hi_in",
    "sk": "sk_sk",
    "cs": "cs_cz",
    "vi": "vi_vi",
    "uwu": "uwu_uwu",
    "nl": "nl_NL",
    "sl": "sl_SL",
    "zh-CN": "zh-CN",
}


def generate_dart():
    out = {}
    with zipfile.ZipFile("ReFreezer (translations).zip") as zip:
        for file in zip.namelist():
            if "refreezer.json" in file:
                data = zip.open(file).read().decode("utf-8")
                lang = file.split("/")[0]
                out[lang_crowdin[lang]] = json.loads(
                    data, object_pairs_hook=collections.OrderedDict
                )

    with open("../lib/languages/crowdin_new.dart", "w", encoding="utf-8") as f:
        data = json.dumps(out, ensure_ascii=False, indent=2).replace("$", "\\$")
        out = f"const crowdin = {data};"
        f.write(out)


if __name__ == "__main__":
    generate_dart()
