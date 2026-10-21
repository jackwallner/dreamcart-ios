package com.jackwallner.shop.ui.screens

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.GridItemSpan
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.foundation.lazy.grid.items
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.AddShoppingCart
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.CreditCard
import androidx.compose.material.icons.filled.Favorite
import androidx.compose.material.icons.filled.FavoriteBorder
import androidx.compose.material.icons.filled.LocalFireDepartment
import androidx.compose.material.icons.filled.Redeem
import androidx.compose.material.icons.filled.Search
import androidx.compose.material.icons.filled.Verified
import androidx.compose.material.icons.filled.Casino
import androidx.compose.material.icons.filled.WifiOff
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.material3.pulltorefresh.PullToRefreshBox
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
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.layout.layout
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import com.jackwallner.shop.data.AuthState
import com.jackwallner.shop.model.Categories
import com.jackwallner.shop.model.Product
import com.jackwallner.shop.model.greeting
import com.jackwallner.shop.ui.LocalGraph
import com.jackwallner.shop.ui.LocalNav
import com.jackwallner.shop.ui.PageHeader
import com.jackwallner.shop.ui.Screen
import com.jackwallner.shop.ui.Sheet
import com.jackwallner.shop.ui.components.CandyButton
import com.jackwallner.shop.ui.components.CoinLabel
import com.jackwallner.shop.ui.components.EmptyState
import com.jackwallner.shop.ui.components.FilterChip
import com.jackwallner.shop.ui.components.ProductCard
import com.jackwallner.shop.ui.components.RarityChip
import com.jackwallner.shop.ui.components.RemoteImage
import com.jackwallner.shop.ui.components.RewardOverlay
import com.jackwallner.shop.ui.components.SectionHeader
import com.jackwallner.shop.ui.components.Shimmer
import com.jackwallner.shop.ui.components.TextLink
import com.jackwallner.shop.ui.components.dcCard
import com.jackwallner.shop.ui.theme.LocalDC
import com.jackwallner.shop.ui.theme.Palette
import com.jackwallner.shop.ui.theme.Radii
import com.jackwallner.shop.ui.theme.Type
import java.util.Calendar
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch

/** Bottom inset that keeps content clear of the floating tab bar. */
val TabBarClearance = 96.dp

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun TodayScreen() {
    val graph = LocalGraph.current
    val shop = graph.shop
    val nav = LocalNav.current
    val scope = rememberCoroutineScope()
    var hour by remember { mutableStateOf(Calendar.getInstance().get(Calendar.HOUR_OF_DAY)) }
    var reward by remember { mutableStateOf<Triple<String, Int, String>?>(null) }
    var claiming by remember { mutableStateOf(false) }
    var refreshing by remember { mutableStateOf(false) }
    var primer by remember { mutableStateOf(false) }
    LaunchedEffect(Unit) {
        while (true) {
            delay(60_000)
            hour = Calendar.getInstance().get(Calendar.HOUR_OF_DAY)
        }
    }
    val logic = shop.logic()
    PullToRefreshBox(refreshing, onRefresh = { scope.launch { refreshing = true; shop.refresh(); refreshing = false } }, Modifier.fillMaxSize()) {
        LazyColumn(Modifier.fillMaxSize().testTag("todayList"), contentPadding = PaddingValues(bottom = TabBarClearance)) {
            item { PageHeader(greeting(hour)) }
            if (shop.loadError != null) item { LoadErrorBanner(shop.loadError!!) { scope.launch { shop.refresh() } } }
            if (shop.isLoading && shop.products.isEmpty()) {
                item { TodayLoading() }
            } else {
                if (!graph.screenshotMode) {
                    item {
                        Box(Modifier.padding(horizontal = 16.dp, vertical = 6.dp)) {
                            DailyCard(claiming) {
                                scope.launch {
                                    claiming = true
                                    val r = shop.claimDaily()
                                    claiming = false
                                    if (r != null && r.ok && r.granted != null) {
                                        val sub = if (r.weeklyBonus) "Weekly bonus! Streak ${r.streak ?: 0}. See you tomorrow."
                                        else "Streak ${r.streak ?: 0} days. Come back tomorrow for more."
                                        reward = Triple("Daily Drop claimed", r.granted, sub)
                                    }
                                }
                            }
                        }
                    }
                    if (shop.authState == AuthState.SIGNED_IN) item { Box(Modifier.padding(horizontal = 16.dp, vertical = 6.dp)) { SpinCard() } }
                }
                val drops = logic.newDrops
                if (drops.isNotEmpty()) {
                    item {
                        Column(Modifier.padding(top = 14.dp)) {
                            Box(Modifier.padding(horizontal = 16.dp)) {
                                SectionHeader("Just dropped", "Fresh today", if (graph.screenshotMode) null else "Shop all") { nav.push(Screen.Shop) }
                            }
                            ProductRow(drops, isNew = true)
                        }
                    }
                }
                shop.brands.take(4).forEach { brand ->
                    val items = logic.byBrand(brand.id).take(6)
                    if (items.isNotEmpty()) item(key = brand.id) {
                        Column(Modifier.padding(top = 22.dp)) {
                            Row(Modifier.padding(horizontal = 16.dp), verticalAlignment = Alignment.CenterVertically) {
                                Column(Modifier.weight(1f)) {
                                    Text(brand.name, style = Type.section, color = LocalDC.current.ink)
                                    Text(brand.tagline, style = Type.sub, color = Palette.hex(brand.accentHex))
                                }
                                TextLink("See all") { nav.push(Screen.Brand(brand.id)) }
                            }
                            ProductRow(items, isNew = false)
                        }
                    }
                }
                if (shop.brands.size > 4) item {
                    Box(Modifier.padding(16.dp).fillMaxWidth().dcCard().clickable { nav.push(Screen.Shop) }.padding(vertical = 14.dp), contentAlignment = Alignment.Center) {
                        Text("See all brands", style = Type.button, color = Palette.violet)
                    }
                }
            }
        }
    }
    reward?.let { (title, amount, sub) ->
        RewardOverlay(title, amount, sub) {
            reward = null
            if (graph.reminders.shouldPresentPrimer) primer = true
        }
    }
    if (primer) NotificationPrimer { primer = false }
}

@Composable
private fun ProductRow(items: List<Product>, isNew: Boolean) {
    val graph = LocalGraph.current
    val nav = LocalNav.current
    val owned = graph.shop.ownedIds
    LazyRow(contentPadding = PaddingValues(horizontal = 16.dp, vertical = 12.dp), horizontalArrangement = Arrangement.spacedBy(12.dp)) {
        items(items, key = { it.id }) { p ->
            ProductCard(p, p.id in owned, Modifier.width(150.dp), isNew = isNew) { nav.push(Screen.Detail(p.id)) }
        }
    }
}

@Composable
private fun DailyCard(claiming: Boolean, onClaim: () -> Unit) {
    val shop = LocalGraph.current.shop
    val me = shop.me
    if (shop.isGuest) {
        CandyCard {
            DailyLabel()
            Text("Coins, cart and closet", style = Type.title, color = Color.White)
            Text("Browse as long as you like. Sign in when you want to claim daily coins, spin the wheel and keep what you buy.", style = Type.bodyText, color = Color.White.copy(alpha = 0.85f))
            WhitePill("Sign in", tag = "guestDailySignIn") { shop.requireAccount("daily_drop") }
        }
    } else if (me?.canClaimDaily == true) {
        CandyCard {
            Row(verticalAlignment = Alignment.CenterVertically) {
                DailyLabel()
                Spacer(Modifier.weight(1f))
                if (me.streak > 0) StreakChip("${me.streak} day${if (me.streak == 1) "" else "s"}")
            }
            Text("Your coins are waiting", style = Type.title, color = Color.White)
            Text("Claim today's coins and keep your streak alive.", style = Type.bodyText, color = Color.White.copy(alpha = 0.85f))
            WhitePill(if (claiming) "Claiming…" else "Claim now", enabled = !claiming, tag = "claimDaily", onClick = onClaim)
        }
    } else {
        Row(
            Modifier.fillMaxWidth().clip(RoundedCornerShape(Radii.card)).background(Palette.candy).padding(horizontal = 16.dp, vertical = 12.dp).testTag("dailyClaimed"),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Icon(Icons.Filled.Verified, contentDescription = null, tint = Color.White)
            Spacer(Modifier.width(10.dp))
            Text("Daily claimed", style = Type.label, color = Color.White, maxLines = 1)
            if ((me?.streak ?: 0) > 0) {
                Spacer(Modifier.width(10.dp))
                StreakChip("${me!!.streak}")
            }
            Spacer(Modifier.weight(1f))
            Text("More tomorrow", style = Type.sub, color = Color.White.copy(alpha = 0.85f), maxLines = 1)
        }
    }
}

@Composable
private fun CandyCard(content: @Composable () -> Unit) {
    Column(
        Modifier.fillMaxWidth().clip(RoundedCornerShape(Radii.corner)).background(Palette.candy).padding(18.dp).testTag("dailyCard"),
        verticalArrangement = Arrangement.spacedBy(14.dp),
    ) { content() }
}

@Composable
private fun DailyLabel() {
    Row(verticalAlignment = Alignment.CenterVertically) {
        Icon(Icons.Filled.Redeem, contentDescription = null, tint = Color.White, modifier = Modifier.size(20.dp))
        Spacer(Modifier.width(8.dp))
        Text("Daily Drop", style = Type.body, color = Color.White)
    }
}

@Composable
private fun StreakChip(text: String) {
    Row(Modifier.clip(CircleShape).background(Color.White.copy(alpha = 0.22f)).padding(horizontal = 10.dp, vertical = 5.dp), verticalAlignment = Alignment.CenterVertically) {
        Icon(Icons.Filled.LocalFireDepartment, contentDescription = null, tint = Color.White, modifier = Modifier.size(16.dp))
        Spacer(Modifier.width(4.dp))
        Text(text, style = Type.label, color = Color.White)
    }
}

@Composable
fun WhitePill(title: String, enabled: Boolean = true, tag: String? = null, onClick: () -> Unit) {
    Box(
        Modifier.fillMaxWidth().heightIn(min = 52.dp).clip(CircleShape).background(Color.White)
            .clickable(enabled = enabled, role = Role.Button, onClick = onClick)
            .then(if (tag != null) Modifier.testTag(tag) else Modifier)
            .padding(vertical = 14.dp),
        contentAlignment = Alignment.Center,
    ) { Text(title, style = Type.button, color = Palette.violet) }
}

@Composable
private fun SpinCard() {
    val graph = LocalGraph.current
    val nav = LocalNav.current
    val c = LocalDC.current
    if (graph.shop.me?.canSpin == true || graph.shop.me?.isPlus == true) {
        Row(
            Modifier.fillMaxWidth().dcCard().clickable(role = Role.Button) { nav.present(Sheet.SPIN) }.testTag("spinCard").padding(16.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Box(Modifier.size(54.dp).clip(CircleShape).background(Palette.goldGradient), contentAlignment = Alignment.Center) {
                Icon(Icons.Filled.Casino, contentDescription = null, tint = Color.White, modifier = Modifier.size(28.dp))
            }
            Spacer(Modifier.width(14.dp))
            Column(Modifier.weight(1f)) {
                Text("Spin the wheel", style = Type.card, color = c.ink)
                Text("Your free spin is ready", style = Type.sub, color = c.subtle)
            }
            Text("SPIN", style = Type.label, color = Color.White, modifier = Modifier.clip(CircleShape).background(Palette.candy).padding(horizontal = 14.dp, vertical = 8.dp))
        }
    } else {
        Row(Modifier.fillMaxWidth().dcCard().padding(horizontal = 16.dp, vertical = 12.dp).testTag("spinUsed"), verticalAlignment = Alignment.CenterVertically) {
            Icon(Icons.Filled.Casino, contentDescription = null, tint = Palette.gold)
            Spacer(Modifier.width(10.dp))
            Text("Spin used", style = Type.label, color = c.ink)
            Spacer(Modifier.weight(1f))
            Text("Resets tomorrow", style = Type.sub, color = c.subtle)
        }
    }
}

@Composable
private fun TodayLoading() {
    Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(22.dp)) {
        Row(Modifier.fillMaxWidth().padding(vertical = 30.dp), horizontalArrangement = Arrangement.Center, verticalAlignment = Alignment.CenterVertically) {
            CircularProgressIndicator(Modifier.size(22.dp), color = Palette.violet, strokeWidth = 2.dp)
            Spacer(Modifier.width(10.dp))
            Text("Loading today's drops…", style = Type.body, color = LocalDC.current.subtle)
        }
        repeat(2) {
            Shimmer(Modifier.size(150.dp, 24.dp).clip(CircleShape))
            Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                repeat(2) { Shimmer(Modifier.weight(1f).aspectRatio(0.72f).clip(RoundedCornerShape(Radii.card))) }
            }
        }
    }
}

@Composable
fun LoadErrorBanner(message: String, onRetry: () -> Unit) {
    val c = LocalDC.current
    Row(Modifier.padding(horizontal = 16.dp, vertical = 6.dp).fillMaxWidth().dcCard().padding(14.dp).testTag("loadError"), verticalAlignment = Alignment.CenterVertically) {
        Icon(Icons.Filled.WifiOff, contentDescription = null, tint = Palette.coral)
        Spacer(Modifier.width(10.dp))
        Column(Modifier.weight(1f)) {
            Text("Couldn't reach DreamCart", style = Type.body, color = c.ink)
            Text("Check your connection and try again.", style = Type.caption, color = c.subtle)
        }
        TextLink("Retry", onClick = onRetry)
    }
}

/** `NotificationPrimerView`: one soft ask before the system prompt. */
@Composable
fun NotificationPrimer(onDone: () -> Unit) {
    val graph = LocalGraph.current
    val c = LocalDC.current
    val launcher = androidx.activity.compose.rememberLauncherForActivityResult(androidx.activity.result.contract.ActivityResultContracts.RequestPermission()) { granted ->
        if (granted) graph.reminders.enable()
        onDone()
    }
    LaunchedEffect(Unit) { graph.reminders.markPrimerShown() }
    Box(Modifier.fillMaxSize().background(Color.Black.copy(alpha = 0.55f)).clickable(onClick = onDone), contentAlignment = Alignment.Center) {
        Column(Modifier.padding(28.dp).dcCard(Radii.corner).clickable(enabled = false) {}.padding(24.dp), horizontalAlignment = Alignment.CenterHorizontally) {
            Text("Never miss a drop", style = Type.card, color = c.ink, textAlign = TextAlign.Center)
            Spacer(Modifier.height(8.dp))
            Text("Get one reminder a day when fresh styles land. You can turn it off anytime in You.", style = Type.bodyText, color = c.subtle, textAlign = TextAlign.Center)
            Spacer(Modifier.height(18.dp))
            CandyButton("Turn on reminders", tag = "primerAllow") {
                if (android.os.Build.VERSION.SDK_INT >= 33 && !graph.reminders.hasPermission) {
                    launcher.launch(android.Manifest.permission.POST_NOTIFICATIONS)
                } else {
                    graph.reminders.enable()
                    onDone()
                }
            }
            TextLink("Not now", onClick = onDone)
        }
    }
}

/** `ShopView`: search, category chips and the full catalog grid. */
@Composable
fun ShopScreen() {
    val shop = LocalGraph.current.shop
    val nav = LocalNav.current
    var query by remember { mutableStateOf("") }
    var category by remember { mutableStateOf<String?>(null) }
    val logic = shop.logic()
    val base = if (query.isBlank()) shop.products else logic.search(query)
    val filtered = category?.let { c -> base.filter { it.category == c } } ?: base
    ProductGrid(
        filtered,
        header = {
            PageHeader("Shop", onBack = { nav.back() })
            SearchField(query, "Search brands, colors, styles") { query = it }
            LazyRow(contentPadding = PaddingValues(horizontal = 16.dp, vertical = 10.dp), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                item { FilterChip("All", category == null) { category = null } }
                items(Categories.shop, key = { it.key }) { c -> FilterChip(c.label, category == c.key) { category = if (category == c.key) null else c.key } }
            }
        },
        empty = {
            EmptyState(Icons.Filled.Search, "Nothing here", if (shop.products.isNotEmpty()) "Try another search or category." else "The catalog could not be loaded. Retry above.", Modifier.padding(top = 40.dp))
        },
    )
}

@Composable
fun BrandScreen(brandId: String) {
    val shop = LocalGraph.current.shop
    val nav = LocalNav.current
    val brand = shop.brands.firstOrNull { it.id == brandId }
    val items = shop.logic().byBrand(brandId)
    ProductGrid(items, header = {
        PageHeader(brand?.name ?: "", onBack = { nav.back() })
        brand?.let { Text(it.tagline, style = Type.sub, color = Palette.hex(it.accentHex), modifier = Modifier.padding(horizontal = 16.dp, vertical = 4.dp)) }
    }, empty = {})
}

@Composable
fun ProductGrid(products: List<Product>, header: @Composable () -> Unit, empty: @Composable () -> Unit) {
    val shop = LocalGraph.current.shop
    val nav = LocalNav.current
    val owned = shop.ownedIds
    LazyVerticalGrid(
        GridCells.Adaptive(160.dp),
        Modifier.fillMaxSize().testTag("productGrid"),
        contentPadding = PaddingValues(start = 16.dp, end = 16.dp, bottom = 40.dp),
        horizontalArrangement = Arrangement.spacedBy(12.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        item(span = { GridItemSpan(maxLineSpan) }) { Column(Modifier.bleed(16.dp)) { header() } }
        if (products.isEmpty()) item(span = { GridItemSpan(maxLineSpan) }) { empty() }
        items(products, key = { it.id }) { p -> ProductCard(p, p.id in owned) { nav.push(Screen.Detail(p.id)) } }
    }
}

@Composable
fun SearchField(value: String, placeholder: String, tag: String = "searchField", onChange: (String) -> Unit) {
    val c = LocalDC.current
    Row(
        Modifier.padding(horizontal = 16.dp, vertical = 4.dp).fillMaxWidth().clip(RoundedCornerShape(14.dp)).background(c.surface).padding(horizontal = 12.dp, vertical = 12.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Icon(Icons.Filled.Search, contentDescription = null, tint = c.subtle)
        Spacer(Modifier.width(8.dp))
        Box(Modifier.weight(1f)) {
            if (value.isEmpty()) Text(placeholder, style = Type.bodyText, color = c.subtle)
            BasicTextField(value, onChange, Modifier.fillMaxWidth().testTag(tag), textStyle = Type.bodyText.copy(color = c.ink), singleLine = true, cursorBrush = SolidColor(Palette.violet))
        }
    }
}

/** `ProductDetailView`: hero art, favorite, specs, Complete the look, and the cart action. */
@Composable
fun ProductDetailScreen(productId: String) {
    val graph = LocalGraph.current
    val shop = graph.shop
    val nav = LocalNav.current
    val c = LocalDC.current
    val scope = rememberCoroutineScope()
    val product = shop.products.firstOrNull { it.id == productId } ?: shop.closet.firstOrNull { it.id == productId }
    if (product == null) {
        Column { PageHeader("", onBack = { nav.back() }); EmptyState(Icons.Filled.Search, "Not found", "This piece is no longer in the catalog.") }
        return
    }
    val owned = product.id in shop.ownedIds
    val inCart = shop.inCart(product.id)
    var favError by remember { mutableStateOf<String?>(null) }
    LaunchedEffect(product.id) { graph.analytics.track("product_viewed", mapOf("product_id" to product.id)) }
    Box(Modifier.fillMaxSize()) {
        Column(Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(bottom = 120.dp)) {
            PageHeader("", onBack = { nav.back() }) {
                Box(
                    Modifier.size(48.dp).clip(CircleShape).clickable(role = Role.Button) {
                        if (!shop.requireAccount("favorite")) return@clickable
                        scope.launch { runCatching { shop.toggleFavorite(product.id) }.onFailure { favError = it.message } }
                    }.testTag("favorite").semantics { contentDescription = if (product.id in shop.favoriteIds) "Remove favorite" else "Favorite" },
                    contentAlignment = Alignment.Center,
                ) {
                    Icon(if (product.id in shop.favoriteIds) Icons.Filled.Favorite else Icons.Filled.FavoriteBorder, contentDescription = null, tint = Palette.pink)
                }
            }
            RemoteImage(product.imageUrl, product.rarityKind, Modifier.padding(horizontal = 16.dp).fillMaxWidth().aspectRatio(1f).clip(RoundedCornerShape(Radii.corner)), maxPx = 1400)
            Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Text((product.brand?.name ?: "DreamCart").uppercase(), style = Type.overline, color = product.brand?.let { Palette.hex(it.accentHex) } ?: Palette.violet)
                    Spacer(Modifier.width(8.dp))
                    RarityChip(product.rarityKind)
                }
                Text(product.name, style = Type.title, color = c.ink, modifier = Modifier.testTag("productName"))
                Text(product.description, style = Type.bodyText, color = c.subtle)
                if (product.styleTags.isNotEmpty()) Text(product.styleTags.joinToString("  ") { "#$it" }, style = Type.sub, color = Palette.violet)
                Column(Modifier.fillMaxWidth().dcCard().padding(14.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    Spec("Color", product.colorName)
                    Spec("Category", product.category.replaceFirstChar { it.uppercase() })
                    Spec("Rarity", product.rarityKind.label)
                }
            }
            val looks = shop.logic().complementary(product)
            if (looks.isNotEmpty()) {
                Box(Modifier.padding(horizontal = 16.dp)) { SectionHeader("Complete the look", "Picked to style with this") }
                LazyRow(contentPadding = PaddingValues(16.dp), horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                    items(looks, key = { it.id }) { p -> ProductCard(p, p.id in shop.ownedIds, Modifier.width(150.dp)) { nav.push(Screen.Detail(p.id)) } }
                }
            }
        }
        Row(
            Modifier.align(Alignment.BottomCenter).fillMaxWidth().background(c.bg).navigationBarsPadding().padding(horizontal = 16.dp, vertical = 12.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Column {
                Text("Price", style = Type.caption, color = c.subtle)
                CoinLabel(product.price, size = 20)
            }
            Spacer(Modifier.width(16.dp))
            if (owned) {
                Row(Modifier.weight(1f), horizontalArrangement = Arrangement.End, verticalAlignment = Alignment.CenterVertically) {
                    Icon(Icons.Filled.CheckCircle, contentDescription = null, tint = Palette.green)
                    Spacer(Modifier.width(6.dp))
                    Text("In your closet", style = Type.body, color = Palette.green)
                }
            } else {
                CandyButton(if (inCart) "Go to checkout" else "Add to cart", if (inCart) Icons.Filled.CreditCard else Icons.Filled.AddShoppingCart, Modifier.weight(1f), tag = "addToCart") {
                    if (!shop.requireAccount("add_to_cart")) return@CandyButton
                    if (inCart) nav.present(Sheet.CHECKOUT) else shop.addToCart(product.id)
                }
            }
        }
    }
    favError?.let { msg ->
        androidx.compose.material3.AlertDialog(
            onDismissRequest = { favError = null },
            confirmButton = { TextLink("OK") { favError = null } },
            title = { Text("Favorite not updated") },
            text = { Text(msg) },
        )
    }
}

@Composable
private fun Spec(label: String, value: String) {
    val c = LocalDC.current
    Row(Modifier.fillMaxWidth()) {
        Text(label, style = Type.sub, color = c.subtle, modifier = Modifier.weight(1f))
        Text(value, style = Type.body, color = c.ink)
    }
}

/** Lets a full-width header inside a padded grid reach the screen edges. */
fun Modifier.bleed(h: androidx.compose.ui.unit.Dp): Modifier = layout { m, cons ->
    val extra = h.roundToPx() * 2
    val p = m.measure(cons.copy(minWidth = cons.minWidth + extra, maxWidth = cons.maxWidth + extra))
    layout(p.width - extra, p.height) { p.place(-h.roundToPx(), 0) }
}
