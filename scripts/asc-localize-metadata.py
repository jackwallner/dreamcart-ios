#!/usr/bin/env python3
"""Populate DreamCart App Store metadata for every supported ASC locale.

The script is idempotent. It creates missing app-info/version localizations and
patches existing editable localizations. It never changes screenshots.

Usage: source ~/.baseball_credentials && python3 scripts/asc-localize-metadata.py
"""
from __future__ import annotations

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

LOCALES = [
    "ar-SA", "bn-BD", "ca", "cs", "da", "de-DE", "el", "en-AU", "en-CA",
    "en-GB", "en-US", "es-ES", "es-MX", "fi", "fr-CA", "fr-FR", "gu-IN",
    "he", "hi", "hr", "hu", "id", "it", "ja", "kn-IN", "ko", "ml-IN",
    "mr-IN", "ms", "nl-NL", "no", "or-IN", "pa-IN", "pl", "pt-BR", "pt-PT",
    "ro", "ru", "sk", "sl-SI", "sv", "ta-IN", "te-IN", "th", "tr", "uk",
    "ur-PK", "vi", "zh-Hans", "zh-Hant",
]

EN_DESCRIPTION = """Shopping, but make it free.

DreamCart is a virtual fashion shopping game for anyone who loves the thrill of a full cart and none of the buyer's remorse. Browse a rotating lineup of fashion, pile up the pieces you'd never actually buy, and check out with coins instead of cash.

WINDOW SHOP WITHOUT THE GUILT
Add to cart, check out, unbox, repeat. Every purchase lands in your closet with a little celebration and zero regret.

FREE COINS, EVERY DAY
Claim your daily drop, keep your streak alive, and spin the wheel for a shot at the jackpot. Show up, play, and keep building your balance.

A STORE THAT NEVER REPEATS
Fresh pieces drop every day across ten distinct brands, from quiet-luxury basics to Y2K streetwear and eveningwear. Hunt for rare and legendary drops.

STYLE YOUR DREAM LOOKS
Mix and match tops, bottoms, shoes, jackets, jewelry, sunglasses, hats, and bags. Save favorite looks and build a wardrobe that is all yours.

DreamCart is a virtual shopping game. Coins, items, and delivery are imaginary and have no cash value. Optional consumable coin packs are available, but you never have to spend money to play.

Privacy Policy: https://jackwallner.github.io/dreamcart/privacy-policy.html
Terms: Apple Standard EULA applies to optional purchases.
"""

# Compact native descriptions retain the complete product promise and the
# fictional-items / no-cash-value disclosure without making the API payload huge.
DESCRIPTIONS = {
    "es": """Compra moda sin gastar dinero. DreamCart es un juego de compras virtuales: recibe monedas cada día, gira la ruleta, descubre prendas, llena el carrito y consigue cada artículo para tu armario. Después mezcla tops, pantalones, zapatos, chaquetas, joyas, gafas, sombreros y bolsos para crear looks y guardar tus conjuntos favoritos. Hay novedades diarias y diez estilos de marca, desde básicos de lujo discreto hasta streetwear Y2K y looks de fiesta. Las monedas, los artículos y la entrega son completamente imaginarios y no tienen valor en efectivo. Los paquetes de monedas consumibles son opcionales; puedes jugar sin gastar dinero. Política de privacidad: https://jackwallner.github.io/dreamcart/privacy-policy.html. Se aplica el Apple Standard EULA a las compras opcionales.""",
    "fr": """Faites du shopping mode sans dépenser. DreamCart est un jeu de shopping virtuel : recevez des pièces chaque jour, tournez la roue, découvrez des vêtements, remplissez votre panier et ajoutez chaque article à votre dressing. Mélangez hauts, bas, chaussures, vestes, bijoux, lunettes, chapeaux et sacs pour créer vos looks et enregistrer vos tenues préférées. De nouvelles pièces arrivent chaque jour dans dix univers, du luxe discret au streetwear Y2K et aux tenues de soirée. Les pièces, les articles et la livraison sont imaginaires et n'ont aucune valeur monétaire. Les packs de pièces consommables sont facultatifs : vous pouvez jouer sans dépenser. Politique de confidentialité : https://jackwallner.github.io/dreamcart/privacy-policy.html. L'Apple Standard EULA s'applique aux achats facultatifs.""",
    "de": """Shoppe Mode ohne echtes Geld. DreamCart ist ein virtuelles Shopping-Spiel: Hol dir täglich Münzen, drehe das Glücksrad, entdecke Kleidung, fülle deinen Warenkorb und stelle jedes Teil in deinen Kleiderschrank. Kombiniere Oberteile, Hosen, Schuhe, Jacken, Schmuck, Sonnenbrillen, Hüte und Taschen zu deinen Lieblingslooks. Jeden Tag erscheinen neue Teile in zehn Markenwelten, von leisen Luxus-Basics bis Y2K-Streetwear und Abendmode. Münzen, Artikel und Lieferung sind rein virtuell und haben keinen Geldwert. Optionale Verbrauchspakete mit Münzen sind erhältlich, aber du kannst ohne Ausgaben spielen. Datenschutz: https://jackwallner.github.io/dreamcart/privacy-policy.html. Für optionale Käufe gilt die Apple Standard EULA.""",
    "it": """Fai shopping di moda senza spendere. DreamCart è un gioco di shopping virtuale: ricevi monete ogni giorno, gira la ruota, scopri nuovi capi, riempi il carrello e aggiungi tutto al tuo guardaroba. Abbina top, pantaloni, scarpe, giacche, gioielli, occhiali, cappelli e borse per creare e salvare i tuoi look preferiti. Ogni giorno arrivano nuovi articoli in dieci mondi di stile, dai basic quiet luxury allo streetwear Y2K e agli abiti da sera. Monete, articoli e consegne sono immaginari e non hanno valore in denaro. I pacchetti di monete consumabili sono opzionali: puoi giocare senza spendere. Privacy: https://jackwallner.github.io/dreamcart/privacy-policy.html. Per gli acquisti opzionali si applica l'Apple Standard EULA.""",
    "pt": """Faça compras de moda sem gastar dinheiro. DreamCart é um jogo de compras virtual: receba moedas todos os dias, gire a roda, descubra peças, encha o carrinho e coloque tudo no seu closet. Combine blusas, calças, sapatos, jaquetas, joias, óculos, chapéus e bolsas para criar e salvar seus looks favoritos. Novidades chegam diariamente em dez universos de estilo, do quiet luxury ao streetwear Y2K e aos looks de festa. Moedas, itens e entrega são imaginários e não têm valor em dinheiro. Pacotes consumíveis de moedas são opcionais: você pode jogar sem gastar. Privacidade: https://jackwallner.github.io/dreamcart/privacy-policy.html. A Apple Standard EULA se aplica às compras opcionais.""",
    "nl": """Shop virtuele mode zonder echt geld. DreamCart is een virtueel winkelspel: ontvang elke dag munten, draai aan het rad, ontdek kleding, vul je winkelmand en zet elk item in je garderobe. Combineer tops, broeken, schoenen, jassen, sieraden, zonnebrillen, hoeden en tassen voor je favoriete outfits. Elke dag verschijnen nieuwe items in tien stijlwerelden, van quiet-luxury basics tot Y2K streetwear en avondmode. Munten, items en bezorging zijn verzonnen en hebben geen geldwaarde. Optionele verbruikbare muntenpakketten zijn beschikbaar, maar spelen kan volledig gratis. Privacy: https://jackwallner.github.io/dreamcart/privacy-policy.html. De Apple Standard EULA geldt voor optionele aankopen.""",
    "ja": """お金を使わずにファッションショッピングを楽しもう。DreamCartは仮想ショッピングゲームです。毎日コインを受け取り、ルーレットを回し、服を探してカートに入れ、手に入れたアイテムをクローゼットに集めましょう。トップス、ボトムス、靴、ジャケット、ジュエリー、サングラス、帽子、バッグを組み合わせて、お気に入りのコーデを保存できます。毎日新作が登場し、静かなラグジュアリーからY2Kストリート、イブニングウェアまで10のブランドスタイルを楽しめます。コイン、アイテム、配送はすべて架空で、現金価値はありません。任意のコインパックを購入できますが、無料で遊べます。プライバシー: https://jackwallner.github.io/dreamcart/privacy-policy.html。任意の購入にはApple標準EULAが適用されます。""",
    "ko": """진짜 돈 없이 패션 쇼핑을 즐겨 보세요. DreamCart는 가상 쇼핑 게임입니다. 매일 코인을 받고 룰렛을 돌려 새 옷을 발견한 뒤 카트에 담아 나만의 옷장에 모아 보세요. 상의, 하의, 신발, 재킷, 주얼리, 선글라스, 모자, 가방을 조합해 멋진 코디를 만들고 저장할 수 있습니다. 조용한 럭셔리부터 Y2K 스트리트와 이브닝웨어까지 10가지 브랜드 스타일에서 매일 새 아이템을 만나세요. 코인, 아이템, 배송은 모두 가상이므로 현금 가치가 없습니다. 선택형 소모성 코인 팩이 있지만 돈을 쓰지 않고도 플레이할 수 있습니다. 개인정보 처리방침: https://jackwallner.github.io/dreamcart/privacy-policy.html. 선택적 구매에는 Apple 표준 EULA가 적용됩니다.""",
    "zh-Hans": """不花真钱，也能享受时尚购物。DreamCart 是一款虚拟购物游戏：每天领取金币，转动转盘，发现新款，把心仪单品放进购物车，再将它们收入专属衣橱。搭配上衣、下装、鞋子、外套、首饰、太阳镜、帽子和包包，打造并保存你的造型。每天都有新单品，涵盖低调奢华、Y2K 街头和晚装等十种品牌风格。金币、商品和配送均为虚拟内容，不具有现金价值。可选购消耗型金币包，但无需花钱也能畅玩。隐私政策：https://jackwallner.github.io/dreamcart/privacy-policy.html。可选购买适用 Apple 标准 EULA。""",
    "zh-Hant": """不花真錢，也能享受時尚購物。DreamCart 是一款虛擬購物遊戲：每天領取金幣、轉動轉盤、發現新款，把喜歡的單品放進購物車，再收藏到專屬衣櫥。搭配上衣、下身、鞋子、外套、首飾、太陽眼鏡、帽子和包包，打造並保存你的造型。每天都有新單品，涵蓋低調奢華、Y2K 街頭和晚裝等十種品牌風格。金幣、商品和配送都是虛擬內容，不具現金價值。可選購消耗型金幣包，但不用花錢也能遊玩。私隱政策：https://jackwallner.github.io/dreamcart/privacy-policy.html。可選購買適用 Apple 標準 EULA。""",
}

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

PROMOS = {
    "en": "Free coins every day. Spin, shop, unbox, and build your dream closet without a real-world bill.",
    "es": "Monedas gratis cada día. Gira, compra, abre tus paquetes y crea tu armario soñado sin pagar de verdad.",
    "fr": "Des pièces gratuites chaque jour. Tournez, shoppez, déballez et créez votre dressing sans facture réelle.",
    "de": "Jeden Tag kostenlose Münzen. Drehe, shoppe, packe aus und baue deinen Traumschrank ohne echte Rechnung.",
    "it": "Monete gratis ogni giorno. Gira, fai shopping, scarta e crea il guardaroba dei tuoi sogni senza pagare davvero.",
    "pt": "Moedas grátis todos os dias. Gire, compre, abra e crie seu closet dos sonhos sem uma conta de verdade.",
    "ja": "毎日無料コイン。回して、買って、開けて、リアルなお金を使わず夢のクローゼットを作ろう。",
    "ko": "매일 무료 코인. 돌리고, 쇼핑하고, 언박싱하며 진짜 결제 없이 꿈의 옷장을 만들어 보세요.",
    "zh-Hans": "每天领取免费金币。转盘、购物、开箱，打造梦想衣橱，不用支付真钱。",
    "zh-Hant": "每天領取免費金幣。轉盤、購物、開箱，打造夢想衣櫥，不用支付真錢。",
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
        "en": ["trend", "brand", "haul", "tryon", "fashiongame", "virtualstyle"],
        "es": ["tendencias", "marcas", "haul", "armadordeoutfits", "modavirtual"],
        "fr": ["tendances", "marques", "haul", "essayage", "modevirtuelle"],
        "de": ["trends", "marken", "haul", "anprobe", "modegame"],
        "it": ["tendenze", "brand", "haul", "prova", "modavirtuale"],
        "pt": ["tendências", "marcas", "haul", "provador", "modavirtual"],
        "ja": ["トレンド", "ブランド", "コーデ", "試着", "仮想モール"],
        "ko": ["트렌드", "브랜드", "하울", "가상몰", "스타일게임"],
        "zh-Hans": ["潮流", "品牌", "开箱", "虚拟商城", "搭配游戏"],
        "zh-Hant": ["潮流", "品牌", "開箱", "虛擬商城", "穿搭遊戲"],
    }.get(family(locale), ["trend", "brand", "style", "fashiongame"])
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


def description(locale: str) -> str:
    f = family(locale)
    if f in DESCRIPTIONS:
        return DESCRIPTIONS[f]
    return EN_DESCRIPTION


def payload(locale: str) -> dict:
    name, subtitle, terms = PACKS[locale]
    f = family(locale)
    return {
        "name": name,
        "subtitle": subtitle,
        "keywords": keyword_string(terms, locale),
        "promotionalText": PROMOS.get(f, PROMOS["en"]),
        "description": description(locale),
    }


def validate(data: dict[str, dict]) -> None:
    errors: list[str] = []
    warnings: list[str] = []
    for locale, fields in data.items():
        for field, limit in (("name", 30), ("subtitle", 30), ("keywords", 100), ("promotionalText", 170), ("description", 4000)):
            length = len(fields[field])
            if length > limit:
                errors.append(f"{locale}/{field}={length}>{limit}")
        if len(fields["name"]) < 24:
            warnings.append(f"{locale}/name={len(fields['name'])}")
        if len(fields["subtitle"]) < 24:
            warnings.append(f"{locale}/subtitle={len(fields['subtitle'])}")
        if len(fields["keywords"]) < 94:
            warnings.append(f"{locale}/keywords={len(fields['keywords'])}")
    if errors:
        raise SystemExit("metadata limit errors: " + ", ".join(errors))
    print(f"validated {len(data)} locales; under-limit fields: OK")
    if warnings:
        print("below target lengths (native scripts can be shorter): " + ", ".join(warnings))


def main() -> None:
    data = {locale: payload(locale) for locale in LOCALES}
    validate(data)
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
