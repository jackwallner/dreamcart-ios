#!/usr/bin/env python3
"""Set the "What's New" text on DreamCart's editable App Store version, in every
locale the listing supports.

An update version will not pass submission without whatsNew, and ASC does not
copy it forward from the previous version. Idempotent: re-running patches.

Usage: source ~/.baseball_credentials && python3 scripts/asc-set-release-notes.py [--dry-run]
"""
from __future__ import annotations

import sys
import time
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
import asc_lib

APP_ID = "6787820106"

# 1.0.1 is the DreamCart+ release. The two bugs fixed alongside it
# (StoreController.loadProducts trapping, RewardOverlay assuming coins) were
# both unreachable in the shipped 1.0, so they are not claimed here.
NOTES = {
    "ar-SA": "نقدّم DreamCart+: ضاعِف هدية العملات اليومية، ودوّر العجلة كما تشاء. جرّبه مجاناً لمدة 3 أيام.\n\nكل ما عدا ذلك في DreamCart يبقى مجانياً.",
    "bn-BD": "পরিচয় করিয়ে দিচ্ছি DreamCart+: প্রতিদিনের কয়েন দ্বিগুণ, আর যত খুশি হুইল ঘোরান। ৩ দিন বিনামূল্যে ব্যবহার করে দেখুন।\n\nDreamCart-এর বাকি সবকিছু আগের মতোই ফ্রি থাকছে।",
    "ca": "Et presentem DreamCart+: el doble de monedes diàries i gira la roda tantes vegades com vulguis. Prova'l 3 dies sense pagar.\n\nLa resta de DreamCart continua sense cost.",
    "cs": "Představujeme DreamCart+: dvojnásobek denních mincí a kolo štěstí, kolikrát chcete. Vyzkoušejte 3 dny zdarma.\n\nVšechno ostatní v DreamCartu zůstává zdarma.",
    "da": "Vi introducerer DreamCart+: dobbelt så mange daglige mønter, og drej hjulet så tit du vil. Prøv det gratis i 3 dage.\n\nAlt andet i DreamCart er stadig gratis.",
    "de-DE": "Neu: DreamCart+. Doppelte tägliche Münzen und so viele Drehungen am Rad, wie du willst. 3 Tage kostenlos testen.\n\nAlles andere in DreamCart bleibt kostenlos.",
    "el": "Σας παρουσιάζουμε το DreamCart+: διπλάσια καθημερινά νομίσματα και όσες περιστροφές του τροχού θέλετε. Δοκιμάστε το δωρεάν για 3 ημέρες.\n\nΌλα τα υπόλοιπα στο DreamCart παραμένουν δωρεάν.",
    "en-AU": "Introducing DreamCart+: double your daily coin drop, and spin the wheel as often as you like. Try it free for 3 days.\n\nEverything else in DreamCart stays free.",
    "en-CA": "Introducing DreamCart+: double your daily coin drop, and spin the wheel as often as you like. Try it free for 3 days.\n\nEverything else in DreamCart stays free.",
    "en-GB": "Introducing DreamCart+: double your daily coin drop, and spin the wheel as often as you like. Try it free for 3 days.\n\nEverything else in DreamCart stays free.",
    "en-US": "Introducing DreamCart+: double your daily coin drop, and spin the wheel as often as you like. Try it free for 3 days.\n\nEverything else in DreamCart stays free.",
    "es-ES": "Te presentamos DreamCart+: el doble de monedas diarias y la ruleta las veces que quieras. Pruébalo 3 días sin pagar.\n\nTodo lo demás en DreamCart sigue sin coste.",
    "es-MX": "Llega DreamCart+: el doble de monedas diarias y la ruleta las veces que quieras. Pruébalo 3 días sin pagar.\n\nTodo lo demás en DreamCart sigue sin costo.",
    "fi": "Esittelyssä DreamCart+: tuplasti päivittäisiä kolikoita ja onnenpyörä niin usein kuin haluat. Kokeile 3 päivää maksutta.\n\nKaikki muu DreamCartissa pysyy maksuttomana.",
    "fr-CA": "Voici DreamCart+ : deux fois plus de pièces quotidiennes et la roue autant de fois que vous voulez. Essayez-le gratuitement pendant 3 jours.\n\nTout le reste de DreamCart demeure gratuit.",
    "fr-FR": "Voici DreamCart+ : deux fois plus de pièces quotidiennes et la roue autant de fois que vous voulez. Essayez-le gratuitement pendant 3 jours.\n\nTout le reste de DreamCart reste gratuit.",
    "gu-IN": "રજૂ છે DreamCart+: રોજિંદા સિક્કા બમણા અને વ્હીલ જેટલી વાર ફેરવો તેટલી વાર. 3 દિવસ મફત અજમાવો.\n\nDreamCart માં બાકી બધું પહેલાની જેમ મફત જ રહે છે.",
    "he": "מציגים את DreamCart+: פי שניים מטבעות יומיים, וסיבוב גלגל כמה שתרצו. נסו בחינם ל‑3 ימים.\n\nכל השאר ב‑DreamCart נשאר בחינם.",
    "hi": "पेश है DreamCart+: रोज़ाना दोगुने सिक्के, और जितनी बार चाहें व्हील घुमाएँ। 3 दिन मुफ़्त आज़माएँ।\n\nDreamCart में बाकी सब कुछ पहले की तरह मुफ़्त है।",
    "hr": "Predstavljamo DreamCart+: dvostruko više dnevnih kovanica i kolo sreće koliko god puta želiš. Isprobaj besplatno 3 dana.\n\nSve ostalo u DreamCartu ostaje besplatno.",
    "hu": "Itt a DreamCart+: kétszer annyi napi érme, és annyi kerékpörgetés, amennyit csak akarsz. Próbáld ki 3 napig ingyen.\n\nA DreamCartban minden más ingyenes marad.",
    "id": "Memperkenalkan DreamCart+: koin harian dua kali lipat, dan putar roda sesering yang kamu mau. Coba gratis selama 3 hari.\n\nSemua hal lain di DreamCart tetap gratis.",
    "it": "Arriva DreamCart+: monete giornaliere raddoppiate e ruota della fortuna tutte le volte che vuoi. Provalo gratis per 3 giorni.\n\nTutto il resto di DreamCart resta gratuito.",
    "ja": "DreamCart+ が登場しました。毎日のコインが2倍になり、ホイールは何度でも回せます。3日間無料でお試しください。\n\nDreamCart のそれ以外の機能は、これまでどおり無料です。",
    "kn-IN": "DreamCart+ ಪರಿಚಯ: ದೈನಂದಿನ ನಾಣ್ಯಗಳು ದುಪ್ಪಟ್ಟು, ಮತ್ತು ಬೇಕಾದಷ್ಟು ಬಾರಿ ಚಕ್ರ ತಿರುಗಿಸಿ. 3 ದಿನ ಉಚಿತವಾಗಿ ಪ್ರಯತ್ನಿಸಿ.\n\nDreamCart ನಲ್ಲಿ ಉಳಿದೆಲ್ಲವೂ ಉಚಿತವಾಗಿಯೇ ಇರುತ್ತದೆ.",
    "ko": "DreamCart+를 소개합니다. 매일 받는 코인이 두 배가 되고, 룰렛은 원하는 만큼 돌릴 수 있습니다. 3일 동안 무료로 사용해 보세요.\n\nDreamCart의 나머지 기능은 계속 무료입니다.",
    "ml-IN": "DreamCart+ അവതരിപ്പിക്കുന്നു: ദിവസേനയുള്ള നാണയങ്ങൾ ഇരട്ടി, വീൽ എത്ര തവണ വേണമെങ്കിലും കറക്കാം. 3 ദിവസം സൗജന്യമായി പരീക്ഷിക്കൂ.\n\nDreamCart-ലെ ബാക്കിയെല്ലാം സൗജന്യമായി തുടരും.",
    "mr-IN": "सादर आहे DreamCart+: रोजची नाणी दुप्पट, आणि हवे तितके व्हील फिरवा. 3 दिवस मोफत वापरून पहा.\n\nDreamCart मधले बाकी सर्व काही मोफतच राहते.",
    "ms": "Memperkenalkan DreamCart+: syiling harian berganda, dan putar roda seberapa kerap anda mahu. Cuba percuma selama 3 hari.\n\nSegala yang lain dalam DreamCart kekal percuma.",
    "nl-NL": "Dit is DreamCart+: dubbele dagelijkse munten en zo vaak aan het rad draaien als je wilt. Probeer het 3 dagen gratis.\n\nAl het andere in DreamCart blijft gratis.",
    "no": "Vi presenterer DreamCart+: dobbelt så mange daglige mynter, og snurr hjulet så ofte du vil. Prøv det gratis i 3 dager.\n\nAlt annet i DreamCart er fortsatt gratis.",
    "or-IN": "ଉପସ୍ଥାପନା DreamCart+: ଦୈନିକ ମୁଦ୍ରା ଦୁଇଗୁଣ, ଏବଂ ଯେତେ ଥର ଇଚ୍ଛା ଚକ ଘୂରାନ୍ତୁ। 3 ଦିନ ମାଗଣାରେ ପରୀକ୍ଷା କରନ୍ତୁ।\n\nDreamCart ର ବାକି ସବୁକିଛି ମାଗଣାରେ ରହିବ।",
    "pa-IN": "ਪੇਸ਼ ਹੈ DreamCart+: ਰੋਜ਼ਾਨਾ ਦੁੱਗਣੇ ਸਿੱਕੇ, ਅਤੇ ਜਿੰਨੀ ਵਾਰ ਚਾਹੋ ਵ੍ਹੀਲ ਘੁਮਾਓ। 3 ਦਿਨ ਮੁਫ਼ਤ ਅਜ਼ਮਾਓ।\n\nDreamCart ਵਿੱਚ ਬਾਕੀ ਸਭ ਕੁਝ ਮੁਫ਼ਤ ਹੀ ਰਹਿੰਦਾ ਹੈ।",
    "pl": "Przedstawiamy DreamCart+: dwa razy więcej codziennych monet i koło fortuny tyle razy, ile chcesz. Wypróbuj bezpłatnie przez 3 dni.\n\nCała reszta DreamCart pozostaje bezpłatna.",
    "pt-BR": "Chegou o DreamCart+: o dobro de moedas diárias e a roleta quantas vezes você quiser. Experimente 3 dias sem pagar.\n\nTodo o resto do DreamCart continua sem custo.",
    "pt-PT": "Chegou o DreamCart+: o dobro de moedas diárias e a roda as vezes que quiser. Experimente 3 dias sem pagar.\n\nTudo o resto no DreamCart continua sem custo.",
    "ro": "Îți prezentăm DreamCart+: dublul monedelor zilnice și roata norocului de câte ori vrei. Încearcă 3 zile fără plată.\n\nTot restul din DreamCart rămâne fără costuri.",
    "ru": "Представляем DreamCart+: вдвое больше ежедневных монет и колесо фортуны сколько угодно раз. Попробуйте 3 дня без оплаты.\n\nВсё остальное в DreamCart остаётся без оплаты.",
    "sk": "Predstavujeme DreamCart+: dvojnásobok denných mincí a koleso šťastia, koľkokrát chcete. Vyskúšajte 3 dni zdarma.\n\nVšetko ostatné v DreamCarte zostáva zdarma.",
    "sl-SI": "Predstavljamo DreamCart+: dvakrat več dnevnih kovancev in kolo sreče, kolikorkrat želite. Preizkusite ga 3 dni brezplačno.\n\nVse ostalo v DreamCartu ostaja brezplačno.",
    "sv": "Vi presenterar DreamCart+: dubbelt så många dagliga mynt, och snurra hjulet hur ofta du vill. Testa gratis i 3 dagar.\n\nAllt annat i DreamCart är fortfarande gratis.",
    "ta-IN": "அறிமுகம் DreamCart+: தினசரி நாணயங்கள் இரட்டிப்பு, வீலை விரும்பிய அளவு சுழற்றலாம். 3 நாட்கள் இலவசமாக முயற்சியுங்கள்.\n\nDreamCart இல் மற்ற அனைத்தும் இலவசமாகவே தொடரும்.",
    "te-IN": "పరిచయం DreamCart+: రోజువారీ నాణేలు రెట్టింపు, వీల్‌ను ఎన్నిసార్లయినా తిప్పవచ్చు. 3 రోజులు ఉచితంగా ప్రయత్నించండి.\n\nDreamCartలో మిగిలినవన్నీ ఉచితంగానే ఉంటాయి.",
    "th": "ขอแนะนำ DreamCart+ รับเหรียญรายวันเป็นสองเท่า และหมุนวงล้อได้บ่อยเท่าที่ต้องการ ทดลองใช้ฟรี 3 วัน\n\nส่วนอื่น ๆ ของ DreamCart ยังคงใช้ฟรีเหมือนเดิม",
    "tr": "Karşınızda DreamCart+: günlük jetonların iki katı ve çarkı istediğin kadar çevirme. 3 gün ücretsiz dene.\n\nDreamCart'taki her şey ücretsiz kalmaya devam ediyor.",
    "uk": "Представляємо DreamCart+: удвічі більше щоденних монет і колесо фортуни скільки завгодно разів. Спробуйте 3 дні безкоштовно.\n\nУсе інше в DreamCart залишається безкоштовним.",
    "ur-PK": "پیشِ خدمت DreamCart+: روزانہ دوگنا سکے، اور جتنی بار چاہیں وہیل گھمائیں۔ 3 دن مفت آزمائیں۔\n\nDreamCart میں باقی سب کچھ مفت ہی رہے گا۔",
    "vi": "Giới thiệu DreamCart+: xu hằng ngày nhân đôi, và quay vòng quay bao nhiêu lần tùy thích. Dùng thử miễn phí 3 ngày.\n\nMọi thứ khác trong DreamCart vẫn miễn phí.",
    "zh-Hans": "DreamCart+ 来了：每日金币翻倍，转盘想转多少次就转多少次。免费试用 3 天。\n\nDreamCart 的其他内容依然免费。",
    "zh-Hant": "DreamCart+ 來了：每日金幣加倍，轉盤想轉幾次就轉幾次。免費試用 3 天。\n\nDreamCart 的其他內容依然免費。",
}

LIMIT = 4000


def main() -> None:
    dry = "--dry-run" in sys.argv

    too_long = {k: len(v) for k, v in NOTES.items() if len(v) > LIMIT}
    if too_long:
        raise SystemExit(f"whatsNew over {LIMIT} chars: {too_long}")

    c = asc_lib.ASCClient(asc_lib.bearer_token(*asc_lib.load_credentials()))
    version = asc_lib.find_editable_version(c, APP_ID)
    if not version:
        raise SystemExit("no editable App Store version")
    vstr = version["attributes"].get("versionString")
    print(f"version {vstr} ({version['attributes'].get('appStoreState')})")

    locs = asc_lib.list_all(
        c, f"/appStoreVersions/{version['id']}/appStoreVersionLocalizations?limit=200"
    )
    missing = sorted({l["attributes"]["locale"] for l in locs} - set(NOTES))
    if missing:
        raise SystemExit(f"no release note written for: {', '.join(missing)}")

    if dry:
        print(f"dry-run: would patch {len(locs)} locales")
        return

    failed = []
    for loc in locs:
        locale = loc["attributes"]["locale"]
        try:
            c.patch(
                f"/appStoreVersionLocalizations/{loc['id']}",
                {"data": {
                    "type": "appStoreVersionLocalizations",
                    "id": loc["id"],
                    "attributes": {"whatsNew": NOTES[locale]},
                }},
            )
        except RuntimeError as exc:
            failed.append(f"{locale}: {exc}")
        time.sleep(0.12)

    print(f"set whatsNew on {len(locs) - len(failed)}/{len(locs)} locales")
    if failed:
        print("\n".join(failed))
        raise SystemExit(f"{len(failed)} locale(s) failed")


if __name__ == "__main__":
    main()
