package com.jackwallner.shop.ui.screens

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.AddCircle
import androidx.compose.material.icons.filled.AutoAwesome
import androidx.compose.material.icons.filled.Autorenew
import androidx.compose.material.icons.filled.Bolt
import androidx.compose.material.icons.filled.Cancel
import androidx.compose.material.icons.filled.Checkroom
import androidx.compose.material.icons.filled.LocalShipping
import androidx.compose.material.icons.filled.ShoppingBag
import androidx.compose.material.icons.filled.ShoppingCart
import androidx.compose.material.icons.filled.Verified
import androidx.compose.material.icons.filled.WorkspacePremium
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.OutlinedTextFieldDefaults
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import com.jackwallner.shop.data.PurchaseOutcome
import com.jackwallner.shop.model.CoinPack
import com.jackwallner.shop.model.Format
import com.jackwallner.shop.model.PlusPlan
import com.jackwallner.shop.model.Product
import com.jackwallner.shop.model.ShippingAddress
import com.jackwallner.shop.model.checkoutFailureMessage
import com.jackwallner.shop.ui.LocalGraph
import com.jackwallner.shop.ui.LocalNav
import com.jackwallner.shop.ui.PageHeader
import com.jackwallner.shop.ui.Screen
import com.jackwallner.shop.ui.Sheet
import com.jackwallner.shop.ui.SheetHeader
import com.jackwallner.shop.ui.Tab
import com.jackwallner.shop.ui.activity
import com.jackwallner.shop.ui.components.CandyButton
import com.jackwallner.shop.ui.components.CoinIcon
import com.jackwallner.shop.ui.components.CoinLabel
import com.jackwallner.shop.ui.components.EmptyState
import com.jackwallner.shop.ui.components.RemoteImage
import com.jackwallner.shop.ui.components.RewardOverlay
import com.jackwallner.shop.ui.components.TextLink
import com.jackwallner.shop.ui.components.dcCard
import com.jackwallner.shop.ui.openUrl
import com.jackwallner.shop.data.Config
import com.jackwallner.shop.ui.theme.LocalDC
import com.jackwallner.shop.ui.theme.Palette
import com.jackwallner.shop.ui.theme.Radii
import com.jackwallner.shop.ui.theme.Type
import kotlinx.coroutines.launch

/** `GuestGateState`: the account ask on an account-only tab. */
@Composable
fun GuestGate(icon: androidx.compose.ui.graphics.vector.ImageVector, title: String, message: String, feature: String) {
    val shop = LocalGraph.current.shop
    val nav = LocalNav.current
    Column(Modifier.fillMaxWidth().padding(top = 60.dp), horizontalAlignment = Alignment.CenterHorizontally) {
        EmptyState(icon, title, message)
        Spacer(Modifier.height(20.dp))
        Column(Modifier.padding(horizontal = 32.dp), horizontalAlignment = Alignment.CenterHorizontally) {
            CandyButton("Sign in", tag = "gateSignIn") { shop.requireAccount(feature) }
            TextLink("Keep browsing") { nav.tab = Tab.TODAY; nav.push(Screen.Shop) }
        }
    }
}

@Composable
fun CartScreen() {
    val graph = LocalGraph.current
    val shop = graph.shop
    val nav = LocalNav.current
    val c = LocalDC.current
    val logic = shop.logic()
    val items = logic.cartProducts
    Column(Modifier.fillMaxSize()) {
        PageHeader(if (graph.screenshotMode) "Saved pieces" else "Cart")
        when {
            shop.isGuest -> GuestGate(Icons.Filled.ShoppingCart, "The cart needs an account", "Sign in to fill a cart, check out with coins and keep what you buy.", "cart_tab")
            items.isEmpty() -> Column(Modifier.padding(top = 50.dp).padding(horizontal = 32.dp), horizontalAlignment = Alignment.CenterHorizontally) {
                EmptyState(Icons.Filled.ShoppingCart, "Your cart is empty", "Add pieces you love. Checkout is free with coins.")
                Spacer(Modifier.height(20.dp))
                CandyButton("Browse shop", Icons.Filled.ShoppingBag, tag = "browseShop") { nav.tab = Tab.TODAY; nav.push(Screen.Shop) }
            }
            else -> {
                LazyColumn(Modifier.weight(1f).testTag("cartList"), contentPadding = PaddingValues(16.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
                    items(items, key = { it.id }) { p -> CartRow(p) { shop.removeFromCart(p.id) } }
                }
                Column(Modifier.fillMaxWidth().padding(start = 16.dp, end = 16.dp, bottom = TabBarClearance), verticalArrangement = Arrangement.spacedBy(10.dp)) {
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Text("${items.size} item${if (items.size == 1) "" else "s"}", style = Type.body, color = c.subtle, modifier = Modifier.weight(1f))
                        CoinLabel(logic.cartTotal, size = 20)
                    }
                    if (logic.canAfford(shop.coins)) {
                        CandyButton("Check out", Icons.Filled.AutoAwesome, tag = "cartCheckoutButton") { nav.present(Sheet.CHECKOUT) }
                    } else {
                        Text("You need ${Format.coins(logic.cartTotal - shop.coins)} more coins", style = Type.sub, color = Palette.pink, modifier = Modifier.fillMaxWidth(), textAlign = TextAlign.Center)
                        CandyButton("Get more coins", Icons.Filled.AddCircle, tag = "cartGetCoins") { nav.present(Sheet.COIN_SHOP) }
                    }
                }
            }
        }
    }
}

@Composable
private fun CartRow(p: Product, onRemove: () -> Unit) {
    val c = LocalDC.current
    val nav = LocalNav.current
    Row(Modifier.fillMaxWidth().dcCard().clickable { nav.push(Screen.Detail(p.id)) }.padding(10.dp), verticalAlignment = Alignment.CenterVertically) {
        RemoteImage(p.imageUrl, p.rarityKind, Modifier.size(64.dp).clip(RoundedCornerShape(12.dp)), maxPx = 300)
        Spacer(Modifier.width(12.dp))
        Column(Modifier.weight(1f)) {
            Text((p.brand?.name ?: "").uppercase(), style = Type.badge, color = c.subtle)
            Text(p.name, style = Type.item, color = c.ink, maxLines = 2)
            CoinLabel(p.price, size = 13)
        }
        Box(
            Modifier.size(48.dp).clip(CircleShape).clickable(role = Role.Button, onClick = onRemove).semantics { contentDescription = "Remove ${p.name} from cart" },
            contentAlignment = Alignment.Center,
        ) { Icon(Icons.Filled.Cancel, contentDescription = null, tint = c.subtle.copy(alpha = 0.6f)) }
    }
}

/** `CheckoutView`: pretend address, summary, receipt, and Place order for coins. */
@Composable
fun CheckoutScreen() {
    val graph = LocalGraph.current
    val shop = graph.shop
    val nav = LocalNav.current
    val c = LocalDC.current
    val scope = rememberCoroutineScope()
    var placing by remember { mutableStateOf(false) }
    var skipped by remember { mutableStateOf(false) }
    var error by remember { mutableStateOf<String?>(null) }
    var placed by remember { mutableStateOf<List<Product>?>(null) }
    val logic = shop.logic()
    val address = shop.shipping
    val resolved = address.isValid || skipped
    val canPlace = logic.canAfford(shop.coins) && resolved && !placing && logic.cartProducts.isNotEmpty()
    Column(Modifier.fillMaxSize().testTag("checkout")) {
        SheetHeader("Checkout", leading = "Cancel", onLeading = { nav.dismiss(Sheet.CHECKOUT) }, trailing = null)
        Column(Modifier.weight(1f).verticalScroll(rememberScrollState()).padding(16.dp), verticalArrangement = Arrangement.spacedBy(16.dp)) {
            Column(Modifier.fillMaxWidth().dcCard().padding(16.dp), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(10.dp)) {
                CardHeader(Icons.Filled.LocalShipping, "Shipping address")
                when {
                    address.isValid -> {
                        Text("Ships to", style = Type.caption, color = c.subtle)
                        Text(address.multilineSummary, style = Type.body, color = c.ink, textAlign = TextAlign.Center)
                    }
                    skipped -> Text("No address. Your haul lands straight in your closet.", style = Type.sub, color = c.subtle, textAlign = TextAlign.Center)
                    else -> Text("Add a pretend address so your order has somewhere to \"go,\" or skip it.", style = Type.sub, color = c.subtle, textAlign = TextAlign.Center)
                }
                Row {
                    TextLink(if (address.isValid) "Edit address" else "Add address", tag = "editAddress") { nav.present(Sheet.SHIPPING) }
                    if (!address.isValid && !skipped) TextLink("Skip for now", tag = "skipAddress") {
                        skipped = true
                        graph.analytics.track("shipping_address_skipped")
                    }
                }
            }
            Column(Modifier.fillMaxWidth().dcCard().padding(16.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
                val n = logic.cartProducts.size
                CardHeader(Icons.Filled.ShoppingBag, "$n item${if (n == 1) "" else "s"}")
                logic.cartProducts.forEach { p ->
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        RemoteImage(p.imageUrl, p.rarityKind, Modifier.size(44.dp).clip(RoundedCornerShape(10.dp)), maxPx = 200)
                        Spacer(Modifier.width(10.dp))
                        Text(p.name, style = Type.sub, color = c.ink, modifier = Modifier.weight(1f), maxLines = 1)
                        CoinLabel(p.price, size = 13)
                    }
                }
            }
            Column(Modifier.fillMaxWidth().dcCard().padding(16.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
                Row(verticalAlignment = Alignment.CenterVertically) { Text("Subtotal", style = Type.bodyText, color = c.subtle, modifier = Modifier.weight(1f)); CoinLabel(logic.cartTotal, size = 13) }
                Row { Text("Shipping", style = Type.bodyText, color = c.subtle, modifier = Modifier.weight(1f)); Text("FREE", style = Type.sub, color = Palette.green) }
                HorizontalDivider(color = c.hairline)
                Row(verticalAlignment = Alignment.CenterVertically) { Text("Order total", style = Type.body, color = c.ink, modifier = Modifier.weight(1f)); CoinLabel(logic.cartTotal, size = 17) }
            }
            Text("Virtual delivery: no real address is needed and nothing ships. You pay only in coins.", style = Type.caption, color = c.subtle, textAlign = TextAlign.Center, modifier = Modifier.fillMaxWidth())
        }
        Column(Modifier.fillMaxWidth().background(c.bg).navigationBarsPadding().padding(16.dp), verticalArrangement = Arrangement.spacedBy(8.dp), horizontalAlignment = Alignment.CenterHorizontally) {
            if (!logic.canAfford(shop.coins)) {
                Text("You need ${Format.coins(logic.cartTotal - shop.coins)} more coins", style = Type.sub, color = Palette.pink)
                TextLink("Get more coins") { nav.present(Sheet.COIN_SHOP) }
            } else if (!resolved) {
                Text("Add a shipping address or tap “Skip for now” to continue", style = Type.caption, color = c.subtle, textAlign = TextAlign.Center)
            }
            CandyButton(if (placing) "Placing order…" else "Place order", Icons.Filled.Verified, enabled = canPlace, tag = "placeOrder") {
                scope.launch {
                    placing = true
                    val bought = logic.cartProducts
                    val r = shop.checkout()
                    placing = false
                    when {
                        r == null -> error = "Couldn't place your order. Try again."
                        r.ok -> placed = bought
                        else -> error = checkoutFailureMessage(r.reason)
                    }
                }
            }
        }
    }
    placed?.let { bought ->
        RewardOverlay("Order placed", null, "${bought.size} piece${if (bought.size == 1) "" else "s"} just landed in your closet.") {
            nav.closetHighlight = bought.map { it.id }
            nav.dismiss(Sheet.CHECKOUT)
            nav.stacks.values.forEach { it.clear() }
            nav.tab = Tab.CLOSET
        }
    }
    error?.let { msg ->
        AlertDialog(onDismissRequest = { error = null }, confirmButton = { TextLink("OK") { error = null } }, title = { Text("Order didn't go through") }, text = { Text(msg) })
    }
}

@Composable
private fun CardHeader(icon: androidx.compose.ui.graphics.vector.ImageVector, title: String) {
    Row(verticalAlignment = Alignment.CenterVertically) {
        Icon(icon, contentDescription = null, tint = Palette.violet, modifier = Modifier.size(18.dp))
        Spacer(Modifier.width(8.dp))
        Text(title, style = Type.card, color = LocalDC.current.ink)
    }
}

/** `ShippingAddressView`: a fictional address saved on this device for checkout flavor. */
@Composable
fun ShippingScreen() {
    val shop = LocalGraph.current.shop
    val nav = LocalNav.current
    val c = LocalDC.current
    var a by remember { mutableStateOf(shop.shipping) }
    var confirmClear by remember { mutableStateOf(false) }
    Column(Modifier.fillMaxSize().imePadding()) {
        SheetHeader("Shipping address", leading = "Cancel", onLeading = { nav.dismiss(Sheet.SHIPPING) }, trailing = "Save", onTrailing = {
            shop.saveAddress(a)
            nav.dismiss(Sheet.SHIPPING)
        })
        Column(Modifier.weight(1f).verticalScroll(rememberScrollState()).padding(16.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
            Text("Give your dream orders a place to land. This fictional address is saved on this device for checkout flavor only.", style = Type.sub, color = c.subtle)
            Field("Full name", a.name, "addrName") { a = a.copy(name = it) }
            Field("Street address", a.line1, "addrLine1") { a = a.copy(line1 = it) }
            Field("Apt, suite (optional)", a.line2, "addrLine2") { a = a.copy(line2 = it) }
            Field("City", a.city, "addrCity") { a = a.copy(city = it) }
            Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                Box(Modifier.weight(1f)) { Field("State", a.state, "addrState") { a = a.copy(state = it) } }
                Box(Modifier.weight(1f)) { Field("ZIP", a.zip, "addrZip") { a = a.copy(zip = it) } }
            }
            Field("Country", a.country, "addrCountry") { a = a.copy(country = it) }
            Text("Playful flourish only. DreamCart is a virtual shopping game, so nothing is ever actually shipped here.", style = Type.caption, color = c.subtle)
            if (!shop.shipping.isEmpty) TextLink("Clear saved address", color = Palette.red) { confirmClear = true }
        }
    }
    if (confirmClear) AlertDialog(
        onDismissRequest = { confirmClear = false },
        confirmButton = { TextLink("Clear address", color = Palette.red) { shop.clearAddress(); a = ShippingAddress(); confirmClear = false } },
        dismissButton = { TextLink("Cancel") { confirmClear = false } },
        title = { Text("Clear saved address?") },
    )
}

@Composable
private fun Field(label: String, value: String, tag: String, onChange: (String) -> Unit) {
    OutlinedTextField(
        value, onChange, Modifier.fillMaxWidth().testTag(tag), label = { Text(label) }, singleLine = true,
        keyboardOptions = KeyboardOptions(imeAction = ImeAction.Next),
        colors = OutlinedTextFieldDefaults.colors(focusedBorderColor = Palette.violet, focusedLabelColor = Palette.violet),
    )
}

/** `CoinShopView`: the five coin packs at their Play prices. */
@Composable
fun CoinShopScreen() {
    val graph = LocalGraph.current
    val shop = graph.shop
    val store = graph.store
    val nav = LocalNav.current
    val c = LocalDC.current
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    var buying by remember { mutableStateOf<String?>(null) }
    var reward by remember { mutableStateOf<Int?>(null) }
    LaunchedEffect(Unit) {
        graph.analytics.track("coin_shop_viewed")
        store.trackPaywallImpression("dreamcart_coin_shop")
        store.loadProducts()
    }
    Column(Modifier.fillMaxSize().testTag("coinShop")) {
        SheetHeader("Get Coins", onTrailing = { nav.dismiss(Sheet.COIN_SHOP) })
        Column(Modifier.weight(1f).verticalScroll(rememberScrollState()).navigationBarsPadding().padding(16.dp), verticalArrangement = Arrangement.spacedBy(16.dp)) {
            Column(Modifier.fillMaxWidth().padding(vertical = 10.dp), horizontalAlignment = Alignment.CenterHorizontally) {
                Text("Your balance", style = Type.sub, color = c.subtle)
                CoinLabel(shop.coins, size = 30)
            }
            store.lastError?.let { Text(it, style = Type.caption, color = Palette.red, textAlign = TextAlign.Center, modifier = Modifier.fillMaxWidth()) }
            CoinPack.all.forEach { pack ->
                Row(
                    Modifier.fillMaxWidth().dcCard()
                        .then(if (pack.badge != null) Modifier.border(2.dp, Palette.gold, RoundedCornerShape(Radii.card)) else Modifier)
                        .clickable(enabled = buying == null, role = Role.Button) {
                            val activity = context.activity() ?: return@clickable
                            scope.launch {
                                buying = pack.productId
                                graph.analytics.track("coin_pack_purchase_started", mapOf("product_id" to pack.productId, "coins" to pack.coins))
                                val before = shop.coins
                                val outcome = store.purchase(activity, pack)
                                if (outcome == PurchaseOutcome.PURCHASED) {
                                    shop.reconcilePurchases()
                                    val gained = shop.coins - before
                                    if (gained > 0) reward = gained
                                } else if (outcome == PurchaseOutcome.PENDING) {
                                    store.lastError = "Your purchase is pending. Coins arrive as soon as Google Play confirms it."
                                }
                                buying = null
                            }
                        }
                        .testTag("pack-${pack.title}")
                        .padding(14.dp),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Box(Modifier.size(58.dp).clip(CircleShape).background(Palette.goldGradient), contentAlignment = Alignment.Center) {
                        Icon(packIcon(pack), contentDescription = null, tint = Color.White, modifier = Modifier.size(26.dp))
                    }
                    Spacer(Modifier.width(14.dp))
                    Column(Modifier.weight(1f)) {
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            Text(pack.title, style = Type.card, color = c.ink)
                            pack.badge?.let {
                                Spacer(Modifier.width(6.dp))
                                Text(it, style = Type.badge, color = Color.White, modifier = Modifier.clip(CircleShape).background(Palette.pink).padding(horizontal = 7.dp, vertical = 3.dp))
                            }
                        }
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            CoinIcon(14.dp)
                            Spacer(Modifier.width(4.dp))
                            Text("${Format.coins(pack.coins)} coins", style = Type.body, color = c.ink)
                        }
                        Text(pack.blurb, style = Type.caption, color = c.subtle)
                    }
                    if (buying == pack.productId) CircularProgressIndicator(Modifier.size(24.dp), color = Palette.violet, strokeWidth = 2.dp)
                    else Text(store.price(pack), style = Type.button, color = Color.White, modifier = Modifier.clip(CircleShape).background(Palette.candy).padding(horizontal = 14.dp, vertical = 9.dp))
                }
            }
            Text("Coins are for use inside DreamCart only and have no cash value. All items and delivery are virtual.", style = Type.caption, color = c.subtle, textAlign = TextAlign.Center, modifier = Modifier.fillMaxWidth())
        }
    }
    reward?.let { RewardOverlay("Coins added", it, "Go build something you love.") { reward = null } }
}

private fun packIcon(pack: CoinPack) = when (pack.title) {
    "Pocket" -> Icons.Filled.ShoppingBag
    "Bag" -> Icons.Filled.Checkroom
    "Haul" -> Icons.Filled.ShoppingCart
    "Spree" -> Icons.Filled.AutoAwesome
    else -> Icons.Filled.WorkspacePremium
}

/** `PlusOfferView`: the DreamCart+ weekly membership, after onboarding or from You. */
@Composable
fun PlusOfferScreen(onboarding: Boolean, onDone: () -> Unit) {
    val graph = LocalGraph.current
    val store = graph.store
    val shop = graph.shop
    val c = LocalDC.current
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    var buying by remember { mutableStateOf(false) }
    var restoring by remember { mutableStateOf(false) }
    var subscribed by remember { mutableStateOf(false) }
    val source = if (onboarding) "onboarding" else "profile"
    LaunchedEffect(Unit) {
        graph.analytics.track("plus_offer_shown", mapOf("product_id" to PlusPlan.PRODUCT_ID, "source" to source))
        store.trackPaywallImpression(if (onboarding) "dreamcart_onboarding_plus" else "dreamcart_profile_plus", oncePerSession = true)
        store.loadProducts()
    }
    androidx.activity.compose.BackHandler(onBack = onDone)
    val eligible = store.plusTrialEligible
    Column(Modifier.fillMaxSize().background(c.bg).testTag("plusOffer")) {
        Column(Modifier.weight(1f).verticalScroll(rememberScrollState()).padding(horizontal = 24.dp), horizontalAlignment = Alignment.CenterHorizontally) {
            Spacer(Modifier.height(64.dp))
            Box(Modifier.size(150.dp).clip(CircleShape).background(Palette.gold.copy(alpha = 0.15f)), contentAlignment = Alignment.Center) {
                Icon(Icons.Filled.WorkspacePremium, contentDescription = null, tint = Palette.gold, modifier = Modifier.size(70.dp))
            }
            Spacer(Modifier.height(22.dp))
            Text(PlusPlan.headline(eligible), style = Type.hero, color = c.ink, textAlign = TextAlign.Center)
            Spacer(Modifier.height(10.dp))
            Text("Every day counts double, and the wheel never stops.", style = Type.bodyText, color = c.subtle, textAlign = TextAlign.Center)
            Spacer(Modifier.height(22.dp))
            Column(
                Modifier.fillMaxWidth().dcCard().border(2.dp, Palette.gold, RoundedCornerShape(Radii.card)).padding(18.dp),
                verticalArrangement = Arrangement.spacedBy(14.dp),
            ) {
                Perk(Icons.Filled.Bolt, "Double coins every single day")
                Perk(Icons.Filled.Autorenew, "Spin the wheel as often as you like")
                Perk(Icons.Filled.ShoppingBag, "Fill your closet twice as fast")
            }
            store.lastError?.let { Text(it, style = Type.caption, color = Palette.red, textAlign = TextAlign.Center, modifier = Modifier.padding(top = 12.dp)) }
            Spacer(Modifier.height(20.dp))
        }
        Column(Modifier.fillMaxWidth().navigationBarsPadding().padding(horizontal = 24.dp, vertical = 12.dp), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(10.dp)) {
            CandyButton(if (buying) "Starting…" else PlusPlan.cta(eligible), Icons.Filled.AutoAwesome, enabled = !buying, tag = "plusSubscribe") {
                val activity = context.activity() ?: return@CandyButton
                scope.launch {
                    buying = true
                    graph.analytics.track("plus_purchase_started", mapOf("product_id" to PlusPlan.PRODUCT_ID, "source" to source))
                    val outcome = store.purchasePlus(activity)
                    buying = false
                    if (outcome == PurchaseOutcome.PURCHASED) {
                        shop.refreshMe()
                        graph.analytics.track("plus_purchased", mapOf("product_id" to PlusPlan.PRODUCT_ID, "source" to source))
                        subscribed = true
                    } else if (outcome == PurchaseOutcome.PENDING) {
                        store.lastError = "Your purchase is pending. ${PlusPlan.NAME} starts as soon as Google Play confirms it."
                    }
                }
            }
            Text(PlusPlan.disclosure(store.plusPrice, eligible), style = Type.caption, color = c.subtle, textAlign = TextAlign.Center, modifier = Modifier.testTag("plusDisclosure"))
            Row(horizontalArrangement = Arrangement.Center) {
                TextLink(if (onboarding) "Not now" else "Maybe later", color = c.subtle, tag = "plusSkip") {
                    graph.analytics.track("plus_offer_skipped", mapOf("source" to source))
                    onDone()
                }
                TextLink(if (restoring) "Restoring…" else "Restore", color = c.subtle, tag = "plusRestore") {
                    scope.launch {
                        restoring = true
                        val ok = store.restorePlus()
                        shop.refreshMe()
                        restoring = false
                        if (ok) subscribed = true else if (store.lastError == null) store.lastError = "No previous ${PlusPlan.NAME} membership on this Google account."
                    }
                }
                TextLink("Terms", color = c.subtle) { context.openUrl(Config.TERMS_URL) }
                TextLink("Privacy", color = c.subtle) { context.openUrl(Config.PRIVACY_URL) }
            }
        }
    }
    if (subscribed) RewardOverlay("${PlusPlan.NAME} unlocked", null, "Your daily coins just doubled.", onDone)
}

@Composable
private fun Perk(icon: androidx.compose.ui.graphics.vector.ImageVector, text: String) {
    Row(verticalAlignment = Alignment.CenterVertically) {
        Icon(icon, contentDescription = null, tint = Palette.gold, modifier = Modifier.size(22.dp))
        Spacer(Modifier.width(12.dp))
        Text(text, style = Type.body, color = LocalDC.current.ink)
    }
}
