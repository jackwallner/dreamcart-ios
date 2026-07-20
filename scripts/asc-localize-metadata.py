#!/usr/bin/env python3
"""Populate DreamCart App Store metadata for every supported ASC locale.

The script is idempotent. It creates missing app-info/version localizations and
patches existing editable localizations. It never changes screenshots.

Usage: source ~/.baseball_credentials && python3 scripts/asc-localize-metadata.py
"""
from __future__ import annotations

import json
import sys
import time
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
import asc_lib

APP_ID = "6787820106"
BUNDLE = "com.jackwallner.shop"
BASE_URL = "https://jackwallner.github.io/dreamcart"
SUPPORT_URL = f"{BASE_URL}/support.html"
MARKETING_URL = f"{BASE_URL}/"
PRIVACY_URL = f"{BASE_URL}/privacy-policy.html"
COPY_PATH = Path(__file__).with_name("asc-localized-copy.json")
LOCALIZED_COPY = json.loads(COPY_PATH.read_text(encoding="utf-8"))

LOCALES = [
    "ar-SA", "bn-BD", "ca", "cs", "da", "de-DE", "el", "en-AU", "en-CA",
    "en-GB", "en-US", "es-ES", "es-MX", "fi", "fr-CA", "fr-FR", "gu-IN",
    "he", "hi", "hr", "hu", "id", "it", "ja", "kn-IN", "ko", "ml-IN",
    "mr-IN", "ms", "nl-NL", "no", "or-IN", "pa-IN", "pl", "pt-BR", "pt-PT",
    "ro", "ru", "sk", "sl-SI", "sv", "ta-IN", "te-IN", "th", "tr", "uk",
    "ur-PK", "vi", "zh-Hans", "zh-Hant",
]

PACKS = {
    "ar-SA": ("DreamCart: تسوق الموضة", "نسّق إطلالاتك وتسوّق مجاناً", ["أزياء", "تسوق", "ملابس", "إطلالات", "خزانة", "ألعاب", "ستايل", "عملات", "عجلة", "مجوهرات", "حقائب"]),
    "bn-BD": ("DreamCart: ফ্যাশন শপিং গেম", "লুক বানান, ভার্চুয়াল শপিং", ["ফ্যাশন", "শপিং", "পোশাক", "স্টাইল", "আউটফিট", "ক্লোজেট", "গেম", "কয়েন", "ড্রেসআপ"]),
    "ca": ("DreamCart: Joc de moda", "Crea looks i compra gratis", ["moda", "compres", "roba", "estil", "conjunts", "armari", "joc", "monedes", "vestir", "accessoris"]),
    "cs": ("DreamCart: Módní nakupování", "Tvoř outfity a nakupuj zdarma", ["móda", "nakupování", "oblečení", "styl", "outfit", "šatník", "hra", "mince", "oblékání", "doplňky"]),
    "da": ("DreamCart: Virtuel mode", "Skab outfits og shop gratis", ["mode", "shopping", "tøj", "stil", "outfit", "garderobe", "spil", "mønter", "påklædning", "tilbehør"]),
    "de-DE": ("DreamCart: Fashion Shopping", "Looks stylen, gratis shoppen", ["mode", "shopping", "kleidung", "outfit", "styling", "garderobe", "spiel", "münzen", "dressup", "accessoires"]),
    "el": ("DreamCart: Παιχνίδι μόδας", "Φτιάξε looks και κάνε shopping", ["μόδα", "αγορές", "ρούχα", "στυλ", "outfit", "ντουλάπα", "παιχνίδι", "νομίσματα", "ντύσιμο"]),
    "en-AU": ("DreamCart: Fashion Shopping", "Style outfits, shop for free", ["fashion", "shopping", "outfit", "stylist", "wardrobe", "closet", "dressup", "coins", "virtualmall", "clothes", "accessories"]),
    "en-CA": ("DreamCart: Fashion Shopping", "Style outfits, shop for free", ["fashion", "shopping", "outfit", "stylist", "wardrobe", "closet", "dressup", "coins", "virtualmall", "clothes", "accessories"]),
    "en-GB": ("DreamCart: Fashion Shopping", "Style outfits, shop for free", ["fashion", "shopping", "outfit", "stylist", "wardrobe", "closet", "dressup", "coins", "virtualmall", "clothes", "accessories"]),
    "en-US": ("DreamCart: Dopamine Shopping", "Style outfits, shop for free", ["fashion", "stylist", "outfit", "wardrobe", "virtualmall", "retailtherapy", "glam", "dressup", "clothes", "accessories", "shopping", "coins"]),
    "es-ES": ("DreamCart: Moda y compras", "Crea looks y compra sin gastar", ["moda", "compras", "ropa", "estilo", "looks", "armario", "juego", "monedas", "vestir", "accesorios"]),
    "es-MX": ("DreamCart: Moda y shopping", "Arma looks y compra virtual", ["moda", "compras", "ropa", "estilo", "outfit", "clóset", "juego", "monedas", "vestir", "accesorios"]),
    "fi": ("DreamCart: Muotishoppailu", "Luo asuja ja shoppaile ilmais", ["muoti", "shoppailu", "vaatteet", "tyyli", "asu", "vaatekaappi", "peli", "kolikot", "pukeutuminen", "asusteet"]),
    "fr-CA": ("DreamCart : Mode virtuelle", "Créez des looks et magasinez", ["mode", "magasinage", "vêtements", "style", "tenue", "garde robe", "jeu", "pièces", "habillage", "accessoires"]),
    "fr-FR": ("DreamCart : Shopping mode", "Créez vos looks, shop gratis", ["mode", "shopping", "vêtements", "style", "tenue", "dressing", "jeu", "pièces", "habillage", "accessoires"]),
    "gu-IN": ("DreamCart: ફેશન શોપિંગ ગેમ", "લુક બનાવો, મફત શોપિંગ કરો", ["ફેશન", "શોપિંગ", "કપડાં", "સ્ટાઇલ", "લુક", "ક્લોઝેટ", "ગેમ", "કોઇન્સ", "ડ્રેસઅપ"]),
    "he": ("DreamCart: משחק אופנה", "יוצרים לוקים ועושים שופינג", ["אופנה", "שופינג", "בגדים", "סטייל", "לוקים", "ארון", "משחק", "מטבעות", "הלבשה", "אקססוריז"]),
    "hi": ("DreamCart: फैशन शॉपिंग गेम", "लुक बनाएं, वर्चुअल शॉपिंग करें", ["फैशन", "शॉपिंग", "कपड़े", "स्टाइल", "आउटफिट", "क्लोसेट", "गेम", "कॉइन", "ड्रेसअप"]),
    "hr": ("DreamCart: Modna kupnja", "Složi outfite, kupuj virtualno", ["moda", "kupnja", "odjeća", "stil", "outfit", "ormar", "igra", "novčići", "odijevanje", "dodaci"]),
    "hu": ("DreamCart: Divat és vásárlás", "Állíts össze szetteket ingyen", ["divat", "vásárlás", "ruha", "stílus", "szett", "gardrób", "játék", "érmék", "öltöztetés", "kiegészítők"]),
    "id": ("DreamCart: Game Belanja Mode", "Buat outfit, belanja virtual", ["fashion", "belanja", "baju", "gaya", "outfit", "lemari", "game", "koin", "dandan", "aksesori"]),
    "it": ("DreamCart: Shopping di moda", "Crea look e fai shopping free", ["moda", "shopping", "vestiti", "stile", "outfit", "guardaroba", "gioco", "monete", "dressup", "accessori"]),
    "ja": ("DreamCart：ファッションゲーム", "コーデを作って無料ショッピング", ["ファッション", "ショッピング", "服", "コーデ", "スタイリスト", "クローゼット", "ゲーム", "コイン", "着せ替え", "アクセサリー"]),
    "kn-IN": ("DreamCart: ಫ್ಯಾಷನ್ ಶಾಪಿಂಗ್", "ಲುಕ್ ಮಾಡಿ ಉಚಿತ ಶಾಪಿಂಗ್", ["ಫ್ಯಾಷನ್", "ಶಾಪಿಂಗ್", "ಬಟ್ಟೆ", "ಸ್ಟೈಲ್", "ಔಟ್‌ಫಿಟ್", "ಕ್ಲೋಸೆಟ್", "ಗೇಮ್", "ಕಾಯಿನ್", "ಡ್ರೆಸ್‌ಅಪ್"]),
    "ko": ("DreamCart: 패션 쇼핑 게임", "코디를 만들고 무료로 쇼핑해요", ["패션", "쇼핑", "옷", "스타일", "코디", "옷장", "게임", "코인", "드레스업", "액세서리"]),
    "ml-IN": ("DreamCart: ഫാഷൻ ഷോപ്പിംഗ്", "ലുക്ക് സൃഷ്ടിച്ച് ഫ്രീ", ["ഫാഷൻ", "ഷോപ്പിംഗ്", "വസ്ത്രം", "സ്റ്റൈൽ", "ഔട്ട്ഫിറ്റ്", "ക്ലോസറ്റ്", "ഗെയിം", "കോയിൻ", "ഡ്രസപ്പ്"]),
    "mr-IN": ("DreamCart: फॅशन शॉपिंग गेम", "लूक तयार करा, मोफत शॉपिंग", ["फॅशन", "शॉपिंग", "कपडे", "स्टाइल", "आउटफिट", "क्लोसेट", "गेम", "कॉइन", "ड्रेसअप"]),
    "ms": ("DreamCart: Permainan Fesyen", "Cipta gaya, beli-belah percuma", ["fesyen", "beli belah", "pakaian", "gaya", "outfit", "almari", "permainan", "syiling", "dandan", "aksesori"]),
    "nl-NL": ("DreamCart: Mode shoppen", "Style outfits en shop virtueel", ["mode", "shoppen", "kleding", "stijl", "outfit", "garderobe", "spel", "munten", "aankleden", "accessoires"]),
    "no": ("DreamCart: Virtuell mote", "Lag antrekk og shopp gratis", ["mote", "shopping", "klær", "stil", "antrekk", "garderobe", "spill", "mynter", "klesoppsett", "tilbehør"]),
    "or-IN": ("DreamCart: ଫ୍ୟାଶନ୍ ଶପିଂ", "ଲୁକ୍ ତିଆରି, ମାଗଣା କିଣନ୍ତୁ", ["ଫ୍ୟାଶନ୍", "ଶପିଂ", "ପୋଷାକ", "ଷ୍ଟାଇଲ୍", "ଆଉଟଫିଟ୍", "କ୍ଲୋଜେଟ୍", "ଗେମ୍", "କଏନ୍", "ଡ୍ରେସଅପ୍"]),
    "pa-IN": ("DreamCart: ਫੈਸ਼ਨ ਸ਼ਾਪਿੰਗ ਗੇਮ", "ਲੁੱਕ ਬਣਾਓ, ਮੁਫ਼ਤ ਖਰੀਦਦਾਰੀ", ["ਫੈਸ਼ਨ", "ਸ਼ਾਪਿੰਗ", "ਕੱਪੜੇ", "ਸਟਾਈਲ", "ਆਊਟਫਿਟ", "ਕਲੋਜ਼ੈਟ", "ਗੇਮ", "ਕੋਇਨ", "ਡ੍ਰੈੱਸਅਪ"]),
    "pl": ("DreamCart: Modowe zakupy", "Twórz stylizacje, kupuj gratis", ["moda", "zakupy", "ubrania", "styl", "stylizacja", "szafa", "gra", "monety", "przebieranki", "akcesoria"]),
    "pt-BR": ("DreamCart: Jogo de moda", "Crie looks, compras grátis", ["moda", "compras", "roupas", "estilo", "look", "closet", "jogo", "moedas", "vestir", "acessórios"]),
    "pt-PT": ("DreamCart: Compras de moda", "Cria looks, compras grátis", ["moda", "compras", "roupa", "estilo", "visual", "guarda roupa", "jogo", "moedas", "vestir", "acessórios"]),
    "ro": ("DreamCart: Joc de modă", "Creează ținute, cumpără online", ["modă", "cumpărături", "haine", "stil", "ținută", "garderobă", "joc", "monede", "îmbrăcare", "accesorii"]),
    "ru": ("DreamCart: Игра про моду", "Создавай образы без трат", ["мода", "шопинг", "одежда", "стиль", "образ", "гардероб", "игра", "монеты", "наряды", "аксессуары"]),
    "sk": ("DreamCart: Módne nakupovanie", "Tvor outfity a nakupuj zadarmo", ["móda", "nakupovanie", "oblečenie", "štýl", "outfit", "šatník", "hra", "mince", "obliekanie", "doplnky"]),
    "sl-SI": ("DreamCart: Modno nakupovanje", "Ustvari videze, nakupuj gratis", ["moda", "nakupovanje", "oblačila", "slog", "outfit", "omara", "igra", "kovanci", "oblačenje", "dodatki"]),
    "sv": ("DreamCart: Virtuellt mode", "Skapa outfits, shoppa gratis", ["mode", "shopping", "kläder", "stil", "outfit", "garderob", "spel", "mynt", "klä upp", "accessoarer"]),
    "ta-IN": ("DreamCart: ஃபேஷன் ஷாப்பிங்", "லுக் உருவாக்கி இலவச ஷாப்பிங்", ["ஃபேஷன்", "ஷாப்பிங்", "ஆடைகள்", "ஸ்டைல்", "அவுட்ஃபிட்", "க்ளோசெட்", "கேம்", "காயின்", "டிரஸ்அப்"]),
    "te-IN": ("DreamCart: ఫ్యాషన్ షాపింగ్", "లుక్ తయారు చేసి ఉచిత షాపింగ్", ["ఫ్యాషన్", "షాపింగ్", "బట్టలు", "స్టైల్", "అవుట్‌ఫిట్", "క్లోసెట్", "గేమ్", "కాయిన్", "డ్రెస్‌అప్"]),
    "th": ("DreamCart: เกมช้อปแฟชั่น", "แต่งลุคและช้อปเสมือนจริงฟรี", ["แฟชั่น", "ช้อปปิ้ง", "เสื้อผ้า", "สไตล์", "ชุด", "ตู้เสื้อผ้า", "เกม", "เหรียญ", "แต่งตัว", "เครื่องประดับ"]),
    "tr": ("DreamCart: Moda Oyunu", "Kombin yap, sanal alışveriş", ["moda", "alışveriş", "kıyafet", "stil", "kombin", "gardırop", "oyun", "coin", "giydirme", "aksesuar"]),
    "uk": ("DreamCart: Гра про моду", "Створюй образи, шопся без трат", ["мода", "шопінг", "одяг", "стиль", "образ", "гардероб", "гра", "монети", "вбрання", "аксесуари"]),
    "ur-PK": ("DreamCart: فیشن شاپنگ گیم", "لُک بنائیں، مفت ورچوئل شاپنگ", ["فیشن", "شاپنگ", "کپڑے", "اسٹائل", "آؤٹفٹ", "الماری", "گیم", "سکے", "ڈریس اپ", "لوازمات"]),
    "vi": ("DreamCart: Game thời trang", "Phối đồ, mua sắm ảo miễn phí", ["thời trang", "mua sắm", "quần áo", "phong cách", "outfit", "tủ đồ", "game", "xu", "thay đồ", "phụ kiện"]),
    "zh-Hans": ("DreamCart：时尚购物游戏", "打造造型，免费虚拟购物", ["时尚", "购物", "服装", "穿搭", "造型", "衣橱", "游戏", "金币", "换装", "配饰"]),
    "zh-Hant": ("DreamCart：時尚購物遊戲", "打造造型，免費虛擬購物", ["時尚", "購物", "服裝", "穿搭", "造型", "衣櫥", "遊戲", "金幣", "換裝", "配飾"]),
}

FIELD_OVERRIDES = {
    "ar-SA": ("DreamCart: لعبة تسوق أزياء", "نسّق إطلالاتك وتسوق افتراضياً"),
    "ca": ("DreamCart: Joc de moda virtual", "Crea looks, compra moda gratis"),
    "da": ("DreamCart: Virtuelt modespil", "Skab outfits, shop mode gratis"),
    "en-AU": ("DreamCart: Dopamine Shopping", "Outfit Maker & Dress Up Game"),
    "en-CA": ("DreamCart: Dopamine Shopping", "Outfit Maker & Dress Up Game"),
    "en-GB": ("DreamCart: Dopamine Shopping", "Outfit Maker & Dress Up Game"),
    "en-US": ("DreamCart: Dopamine Shopping", "Outfit Maker & Dress Up Game"),
    "he": ("DreamCart: משחק קניות אופנה", "יוצרים לוקים וקונים בחינם"),
    "hr": ("DreamCart: Igra modne kupnje", "Složi outfite, kupuj virtualno"),
    "ja": ("DreamCart：ファッションショッピングゲーム", "コーデを作って無料で着せ替えショッピングを楽しもう"),
    "kn-IN": ("DreamCart: ಫ್ಯಾಷನ್ ಶಾಪಿಂಗ್", "ಲುಕ್ ಮಾಡಿ ಉಚಿತ ಶಾಪಿಂಗ್ ಗೇಮ್"),
    "ko": ("DreamCart: 패션 쇼핑 스타일 게임 앱", "나만의 코디를 만들고 무료 패션 쇼핑 게임 즐기기"),
    "ml-IN": ("DreamCart: ഫാഷൻ ഷോപ്പിംഗ്", "ലുക്ക് സൃഷ്ടിച്ച് ഫ്രീ ഗെയിം"),
    "nl-NL": ("DreamCart: Virtueel modespel", "Style outfits, shop virtueel"),
    "or-IN": ("DreamCart: ଫ୍ୟାଶନ୍ ଶପିଂ ଗେମ୍", "ଲୁକ୍ ତିଆରି, ମାଗଣା ଶପିଂ ଗେମ୍"),
    "pt-BR": ("DreamCart: Moda e compras", "Crie looks, compras de moda"),
    "ro": ("DreamCart: Joc de modă virtual", "Creează ținute, cumpără online"),
    "tr": ("DreamCart: Moda ve Stil Oyunu", "Kombin yap, sanal alışveriş"),
    "uk": ("DreamCart: Гра моди онлайн", "Створюй образи, шопся без трат"),
    "zh-Hans": ("DreamCart：时尚购物穿搭与衣橱收集模拟游戏", "制作造型并体验免费的虚拟时尚购物与穿搭收集游戏乐趣"),
    "zh-Hant": ("DreamCart：時尚購物穿搭與衣櫥收藏模擬遊戲", "製作造型並體驗免費的虛擬時尚購物與穿搭收藏遊戲樂趣"),
}

KEYWORD_OVERRIDES = {
    "en-AU": "fashion,retail,therapy,stylist,planner,creator,clothes,closet,app,wardrobe,shopaholic,simulator,glam",
    "en-CA": "fashion,retail,therapy,stylist,planner,creator,clothes,closet,app,wardrobe,shopaholic,simulator,glam",
    "en-GB": "fashion,retail,therapy,stylist,planner,creator,clothes,closet,app,wardrobe,shopaholic,simulator,glam",
    "en-US": "fashion,retail,therapy,stylist,planner,creator,clothes,closet,app,wardrobe,shopaholic,simulator,glam",
    "ja": "ファッション,ショッピング,着せ替え,コーデ,服,スタイリスト,クローゼット,ゲーム,コイン,アクセサリー,アウトフィット,洋服,コーディネート,おしゃれ,メイク,アバター,衣装,買い物,服集め",
    "ko": "패션,쇼핑,옷,스타일,코디,옷장,게임,코인,드레스업,액세서리,아웃핏,스타일리스트,의상,꾸미기,가상쇼핑,패션게임,코디게임,의상게임,캐주얼,수집,쇼핑게임,옷게임,코디추천,패션수집",
    "zh-Hans": "时尚,购物,服装,穿搭,造型,衣橱,游戏,金币,换装,配饰,服饰,搭配,虚拟购物,时尚游戏,穿搭游戏,购物游戏,造型师,装扮,收集,每日金币,转盘,裙子,鞋子,包包,首饰,街头风,休闲游戏,模拟购物",
    "zh-Hant": "時尚,購物,服裝,穿搭,造型,衣櫥,遊戲,金幣,換裝,配飾,服飾,搭配,虛擬購物,時尚遊戲,穿搭遊戲,購物遊戲,造型師,裝扮,收藏,每日金幣,轉盤,裙子,鞋子,包包,首飾,街頭風,休閒遊戲,模擬購物",
}


def family(locale: str) -> str:
    if locale.startswith("es"): return "es"
    if locale.startswith("fr"): return "fr"
    if locale.startswith("de"): return "de"
    if locale.startswith("it"): return "it"
    if locale.startswith("pt"): return "pt"
    if locale.startswith("nl"): return "nl"
    if locale == "ja": return "ja"
    if locale == "ko": return "ko"
    if locale == "zh-Hans": return "zh-Hans"
    if locale == "zh-Hant": return "zh-Hant"
    if locale.startswith("en"): return "en"
    return "en"


def keyword_string(terms: list[str], locale: str) -> str:
    extras = {
        "en": ["trend", "brand", "haul", "fashion", "game", "virtual", "style"],
        "es": ["tendencias", "marcas", "haul", "moda", "virtual", "outfits"],
        "fr": ["tendances", "marques", "haul", "mode", "virtuelle", "essayage"],
        "de": ["trends", "marken", "haul", "mode", "game", "anprobe"],
        "it": ["tendenze", "brand", "haul", "moda", "virtuale", "prova"],
        "pt": ["tendências", "marcas", "haul", "moda", "virtual", "provador"],
        "ja": ["トレンド", "ブランド", "コーデ", "試着", "仮想モール"],
        "ko": ["트렌드", "브랜드", "하울", "가상몰", "스타일게임"],
        "zh-Hans": ["潮流", "品牌", "开箱", "虚拟商城", "搭配游戏"],
        "zh-Hant": ["潮流", "品牌", "開箱", "虛擬商城", "穿搭遊戲"],
    }.get(family(locale), ["trend", "brand", "style", "fashion", "game"])
    out: list[str] = []
    seen: set[str] = set()
    for term in terms + extras:
        term = term.strip()
        if not term or term.lower() in seen:
            continue
        seen.add(term.lower())
        candidate = ",".join(out + [term])
        if len(candidate) > 100:
            continue
        out.append(term)
    # App Store search fields perform best when filled, but never cut a term.
    fillers = {"en": ["fun", "daily", "closet", "style"], "es": ["diario", "divertido", "armario"], "fr": ["quotidien", "fun", "dressing"], "de": ["täglich", "spaß", "schrank"]}.get(family(locale), ["daily", "style", "fun"])
    for term in fillers:
        candidate = ",".join(out + [term])
        if len(candidate) <= 100 and term.lower() not in seen:
            out.append(term)
            seen.add(term.lower())
    return ",".join(out)



def payload(locale: str) -> dict:
    name, subtitle, terms = PACKS[locale]
    if locale in FIELD_OVERRIDES:
        name, subtitle = FIELD_OVERRIDES[locale]
    copy = LOCALIZED_COPY[locale]
    return {
        "name": name,
        "subtitle": subtitle,
        "keywords": KEYWORD_OVERRIDES.get(locale, keyword_string(terms, locale)),
        "promotionalText": copy["promotionalText"],
        "description": copy["description"],
    }


def validate(data: dict[str, dict]) -> None:
    errors: list[str] = []
    for locale, fields in data.items():
        for field, limit in (("name", 30), ("subtitle", 30), ("keywords", 100), ("promotionalText", 170), ("description", 4000)):
            length = len(fields[field])
            if length > limit:
                errors.append(f"{locale}/{field}={length}>{limit}")
        for field, minimum in (("name", 24), ("subtitle", 24), ("keywords", 94)):
            length = len(fields[field])
            if length < minimum:
                errors.append(f"{locale}/{field}={length}<{minimum}")
    if errors:
        raise SystemExit("metadata length errors: " + ", ".join(errors))
    print(f"validated {len(data)} locales at 24/24/94+ within Apple limits")


def main() -> None:
    data = {locale: payload(locale) for locale in LOCALES}
    validate(data)
    if "--validate-only" in sys.argv:
        return
    c = asc_lib.ASCClient(asc_lib.bearer_token(*asc_lib.load_credentials()))
    app = asc_lib.find_app(c, BUNDLE)
    app_id = app["id"]
    if app_id != APP_ID:
        raise SystemExit(f"unexpected app id {app_id}")

    info = asc_lib.find_editable_app_info(c, app_id)
    if not info:
        raise SystemExit("no editable app info")
    version = asc_lib.find_editable_version(c, app_id)
    if not version:
        raise SystemExit("no editable app store version")
    print(f"app {app_id}; version {version['attributes'].get('versionString')} ({version['attributes'].get('appStoreState')})")

    info_locs = {x["attributes"]["locale"]: x for x in asc_lib.list_all(c, f"/appInfos/{info['id']}/appInfoLocalizations")}
    version_locs = {x["attributes"]["locale"]: x for x in asc_lib.list_all(c, f"/appStoreVersions/{version['id']}/appStoreVersionLocalizations")}

    results: list[str] = []
    for locale in LOCALES:
        fields = data[locale]
        try:
            if locale in info_locs:
                lid = info_locs[locale]["id"]
                c.patch(f"/appInfoLocalizations/{lid}", {"data": {"type": "appInfoLocalizations", "id": lid, "attributes": {"name": fields["name"], "subtitle": fields["subtitle"], "privacyPolicyUrl": PRIVACY_URL}}})
                info_action = "patched"
            else:
                c.post("/appInfoLocalizations", {"data": {"type": "appInfoLocalizations", "attributes": {"locale": locale, "name": fields["name"], "subtitle": fields["subtitle"], "privacyPolicyUrl": PRIVACY_URL}, "relationships": {"appInfo": {"data": {"type": "appInfos", "id": info["id"]}}}}})
                info_action = "created"
            attrs = {"description": fields["description"], "keywords": fields["keywords"], "promotionalText": fields["promotionalText"], "supportUrl": SUPPORT_URL, "marketingUrl": MARKETING_URL}
            if locale in version_locs:
                lid = version_locs[locale]["id"]
                c.patch(f"/appStoreVersionLocalizations/{lid}", {"data": {"type": "appStoreVersionLocalizations", "id": lid, "attributes": attrs}})
                version_action = "patched"
            else:
                c.post("/appStoreVersionLocalizations", {"data": {"type": "appStoreVersionLocalizations", "attributes": {"locale": locale, **attrs}, "relationships": {"appStoreVersion": {"data": {"type": "appStoreVersions", "id": version["id"]}}}}})
                version_action = "created"
            results.append(f"{locale}: {info_action} appInfo, {version_action} version")
        except RuntimeError as exc:
            results.append(f"{locale}: FAILED {exc}")
        time.sleep(0.15)

    print("\n".join(results))
    failed = [r for r in results if "FAILED" in r]
    print(f"localized {len(results) - len(failed)}/{len(results)} locales")
    if failed:
        raise SystemExit(f"{len(failed)} locale(s) failed")


if __name__ == "__main__":
    main()
