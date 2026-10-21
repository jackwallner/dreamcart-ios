package com.jackwallner.shop.ui

import android.app.Activity
import android.content.Context
import android.content.ContextWrapper
import android.content.Intent
import android.net.Uri
import androidx.activity.compose.BackHandler
import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.core.MutableTransitionState
import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.tween
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.slideInHorizontally
import androidx.compose.animation.slideInVertically
import androidx.compose.animation.slideOutHorizontally
import androidx.compose.animation.slideOutVertically
import androidx.compose.animation.togetherWith
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.systemBars
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.layout.windowInsetsPadding
import androidx.compose.foundation.pager.HorizontalPager
import androidx.compose.foundation.pager.rememberPagerState
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.automirrored.filled.ArrowForward
import androidx.compose.material.icons.filled.AddShoppingCart
import androidx.compose.material.icons.filled.AutoAwesome
import androidx.compose.material.icons.filled.Checkroom
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.Person
import androidx.compose.material.icons.filled.Redeem
import androidx.compose.material.icons.filled.ShoppingCart
import androidx.compose.material.icons.filled.ThumbUp
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateListOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.runtime.snapshots.SnapshotStateList
import androidx.compose.runtime.staticCompositionLocalOf
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.drawBehind
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.selected
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.jackwallner.shop.AppGraph
import com.jackwallner.shop.DebugLaunchOptions
import com.jackwallner.shop.data.AuthState
import com.jackwallner.shop.data.Config
import com.jackwallner.shop.data.GoogleSignIn
import com.jackwallner.shop.model.AppRoute
import com.jackwallner.shop.ui.components.CandyButton
import com.jackwallner.shop.ui.components.SoftButton
import com.jackwallner.shop.ui.components.TextLink
import com.jackwallner.shop.ui.components.WalletPill
import com.jackwallner.shop.ui.screens.BrandScreen
import com.jackwallner.shop.ui.screens.CartScreen
import com.jackwallner.shop.ui.screens.CheckoutScreen
import com.jackwallner.shop.ui.screens.ClosetScreen
import com.jackwallner.shop.ui.screens.CoinShopScreen
import com.jackwallner.shop.ui.screens.ForYouScreen
import com.jackwallner.shop.ui.screens.LedgerScreen
import com.jackwallner.shop.ui.screens.PlusOfferScreen
import com.jackwallner.shop.ui.screens.ProductDetailScreen
import com.jackwallner.shop.ui.screens.ProfileScreen
import com.jackwallner.shop.ui.screens.ShippingScreen
import com.jackwallner.shop.ui.screens.ShopScreen
import com.jackwallner.shop.ui.screens.SpinScreen
import com.jackwallner.shop.ui.screens.TodayScreen
import com.jackwallner.shop.ui.theme.LocalDC
import com.jackwallner.shop.ui.theme.Palette
import com.jackwallner.shop.ui.theme.Type
import kotlinx.coroutines.launch

val LocalGraph = staticCompositionLocalOf<AppGraph> { error("No AppGraph") }
val LocalNav = staticCompositionLocalOf<Nav> { error("No Nav") }

enum class Tab(val title: String, val icon: ImageVector) {
    TODAY("Today", Icons.Filled.AutoAwesome),
    FOR_YOU("For You", Icons.Filled.ThumbUp),
    CART("Cart", Icons.Filled.ShoppingCart),
    CLOSET("Closet", Icons.Filled.Checkroom),
    PROFILE("You", Icons.Filled.Person),
}

sealed interface Screen {
    data class Detail(val productId: String) : Screen
    data class Brand(val brandId: String) : Screen
    data object Shop : Screen
}

enum class Sheet { COIN_SHOP, SPIN, CHECKOUT, PLUS, SHIPPING, LEDGER }

/** Per-tab push stacks plus one modal sheet stack, like the iOS NavigationStacks and sheets. */
class Nav {
    var tab by mutableStateOf(Tab.TODAY)
    val stacks: Map<Tab, SnapshotStateList<Screen>> = Tab.entries.associateWith { mutableStateListOf() }
    val sheets = mutableStateListOf<Sheet>()
    /** Ids of pieces just bought, shown as "New haul" in the closet. */
    var closetHighlight by mutableStateOf<List<String>>(emptyList())

    fun push(s: Screen) { stacks.getValue(tab) += s }
    fun present(s: Sheet) { if (sheets.lastOrNull() != s) sheets += s }
    fun dismiss() { sheets.removeLastOrNull() }
    fun dismiss(s: Sheet) { sheets.remove(s) }

    fun back(): Boolean {
        if (sheets.isNotEmpty()) { sheets.removeAt(sheets.lastIndex); return true }
        val stack = stacks.getValue(tab)
        if (stack.isNotEmpty()) { stack.removeAt(stack.lastIndex); return true }
        if (tab != Tab.TODAY) { tab = Tab.TODAY; return true }
        return false
    }

    fun select(t: Tab) {
        if (tab == t) stacks.getValue(t).clear() else tab = t
    }

    fun route(r: AppRoute) {
        sheets.clear()
        tab = Tab.TODAY
        stacks.getValue(Tab.TODAY).clear()
        if (r == AppRoute.SHOP) push(Screen.Shop)
    }
}

fun Context.activity(): Activity? = when (this) {
    is Activity -> this
    is ContextWrapper -> baseContext.activity()
    else -> null
}

fun Context.openUrl(url: String) = runCatching { startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(url))) }

@Composable
fun RootScreen(graph: AppGraph, pendingRoute: AppRoute?, consumeRoute: () -> Unit) {
    val shop = graph.shop
    val nav = remember { Nav() }
    val c = LocalDC.current
    androidx.compose.runtime.CompositionLocalProvider(LocalNav provides nav) {
        Box(Modifier.fillMaxSize().background(c.bg)) {
            val stage = when (shop.authState) {
                AuthState.UNKNOWN -> "splash"
                AuthState.SIGNED_OUT -> "welcome"
                else -> when {
                    !shop.hasLoadedOnce -> "splash"
                    shop.authState == AuthState.SIGNED_IN && shop.justCompletedOnboarding -> "onboardingPlus"
                    else -> "tabs"
                }
            }
            AnimatedContent(stage, transitionSpec = { fadeIn(tween(280)) togetherWith fadeOut(tween(280)) }, label = "root") { s ->
                when (s) {
                    "splash" -> Splash()
                    "welcome" -> WelcomeScreen()
                    "onboardingPlus" -> PlusOfferScreen(onboarding = true) { shop.justCompletedOnboarding = false }
                    else -> MainTabs()
                }
            }
            if (shop.promptSignIn) SignInPrompt { shop.promptSignIn = false }
        }
        LaunchedEffect(pendingRoute, stage(shop.authState, shop.hasLoadedOnce)) {
            val r = pendingRoute ?: return@LaunchedEffect
            if (shop.authState == AuthState.SIGNED_IN || shop.authState == AuthState.GUEST) {
                if (shop.hasLoadedOnce) {
                    nav.route(r)
                    consumeRoute()
                }
            }
        }
    }
}

private fun stage(a: AuthState, loaded: Boolean) = "$a-$loaded"

@Composable
fun Splash() {
    val pulse = if (com.jackwallner.shop.ui.components.reduceMotion()) 1f else com.jackwallner.shop.ui.components.pulse(0.94f, 1.06f)
    Box(Modifier.fillMaxSize().background(Palette.candy), contentAlignment = Alignment.Center) {
        Column(horizontalAlignment = Alignment.CenterHorizontally) {
            BagMark(92f * pulse)
            Spacer(Modifier.height(18.dp))
            Text("DreamCart", style = Type.hero, color = Color.White)
        }
    }
}

/** `BagMark`: the white bag with a pink sparkle. */
@Composable
fun BagMark(size: Float, tint: Color = Color.White) {
    Box(
        Modifier.size(size.dp, (size * 1.2f).dp).drawBehind {
            val s = size.dp.toPx()
            val top = this.size.height - s
            drawRoundRect(tint, topLeft = Offset(0f, top), size = androidx.compose.ui.geometry.Size(s, s), cornerRadius = CornerRadius(s * 0.16f))
            drawArc(
                tint, 180f, 180f, false,
                topLeft = Offset(s * 0.29f, top - s * 0.21f),
                size = androidx.compose.ui.geometry.Size(s * 0.42f, s * 0.42f),
                style = androidx.compose.ui.graphics.drawscope.Stroke(width = s * 0.09f),
            )
        },
        contentAlignment = Alignment.BottomCenter,
    ) {
        Icon(Icons.Filled.AutoAwesome, contentDescription = null, tint = Palette.pink, modifier = Modifier.padding(bottom = (size * 0.3f).dp).size((size * 0.38f).dp))
    }
}

private data class Slide(val icon: ImageVector, val title: String, val body: String, val tint: Color)

private val slides = listOf(
    Slide(Icons.Filled.AddShoppingCart, "Shop without the guilt", "Original fashion, dream looks, zero dollars. Fill your cart with everything you'd never actually buy.", Palette.violet),
    Slide(Icons.Filled.Redeem, "Free coins every day", "Claim a daily drop, spin the wheel, and keep your streak alive. The more you show up, the more you get.", Palette.pink),
    Slide(Icons.Filled.AutoAwesome, "Build your dream closet", "Own the pieces, mix brands, and style full outfits with jewelry, shades and hats. All yours.", Palette.coral),
)

@Composable
fun WelcomeScreen() {
    val shop = LocalGraph.current.shop
    val c = LocalDC.current
    if (shop.hasCompletedOnboarding) {
        Box(Modifier.fillMaxSize().windowInsetsPadding(WindowInsets.systemBars).verticalScroll(rememberScrollState())) {
            val s = slides[2]
            SignInPanel(s.title, s.body, s.icon, s.tint, guestAction = { shop.continueAsGuest() })
        }
        return
    }
    val pager = rememberPagerState { slides.size }
    val scope = rememberCoroutineScope()
    Column(Modifier.fillMaxSize().windowInsetsPadding(WindowInsets.systemBars)) {
        HorizontalPager(pager, Modifier.weight(1f).testTag("onboardingPager")) { i ->
            val s = slides[i]
            Column(
                Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(horizontal = 34.dp),
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.Center,
            ) {
                Box(Modifier.size(190.dp).clip(CircleShape).background(s.tint.copy(alpha = 0.15f)), contentAlignment = Alignment.Center) {
                    Icon(s.icon, contentDescription = null, tint = s.tint, modifier = Modifier.size(72.dp))
                }
                Spacer(Modifier.height(26.dp))
                Text(s.title, style = Type.hero, color = c.ink, textAlign = TextAlign.Center)
                Spacer(Modifier.height(12.dp))
                Text(s.body, style = Type.bodyText, color = c.subtle, textAlign = TextAlign.Center)
            }
        }
        Row(Modifier.fillMaxWidth().padding(bottom = 16.dp), horizontalArrangement = Arrangement.Center) {
            slides.indices.forEach { i ->
                val on = pager.currentPage == i
                Box(
                    Modifier
                        .padding(horizontal = 3.5.dp)
                        .size(width = if (on) 22.dp else 12.dp, height = 12.dp)
                        .clip(CircleShape)
                        .background(if (on) Palette.violet else c.subtle.copy(alpha = 0.3f))
                        .clickable { scope.launch { pager.animateScrollToPage(i) } }
                        .semantics { contentDescription = "Page ${i + 1} of ${slides.size}"; selected = on },
                )
            }
        }
        val last = pager.currentPage == slides.lastIndex
        CandyButton(if (last) "Get started" else "Next", Icons.AutoMirrored.Filled.ArrowForward, Modifier.padding(start = 28.dp, end = 28.dp, bottom = 28.dp), tag = "onboardingNext") {
            if (last) shop.completeOnboarding() else scope.launch { pager.animateScrollToPage(pager.currentPage + 1) }
        }
    }
}

/** `SignInPanel`: Google in place of Apple, then guest browsing and the legal links. */
@Composable
fun SignInPanel(headline: String, message: String, icon: ImageVector, tint: Color, guestAction: (() -> Unit)?) {
    val graph = LocalGraph.current
    val shop = graph.shop
    val c = LocalDC.current
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    Column(Modifier.fillMaxWidth().padding(top = 36.dp, bottom = 28.dp, start = 28.dp, end = 28.dp), horizontalAlignment = Alignment.CenterHorizontally) {
        Box(Modifier.size(150.dp).clip(CircleShape).background(tint.copy(alpha = 0.15f)), contentAlignment = Alignment.Center) {
            Icon(icon, contentDescription = null, tint = tint, modifier = Modifier.size(64.dp))
        }
        Spacer(Modifier.height(18.dp))
        Text(headline, style = Type.hero, color = c.ink, textAlign = TextAlign.Center)
        Spacer(Modifier.height(10.dp))
        Text(message, style = Type.bodyText, color = c.subtle, textAlign = TextAlign.Center)
        Spacer(Modifier.height(18.dp))
        if (GoogleSignIn.isConfigured) {
            Row(
                Modifier
                    .fillMaxWidth()
                    .heightIn(min = 54.dp)
                    .clip(RoundedCornerShape(18.dp))
                    .background(if (c.dark) Color.White else Color.Black)
                    .clickable(enabled = !shop.authWorking, role = Role.Button) {
                        val activity = context.activity() ?: return@clickable
                        scope.launch {
                            try {
                                val (token, nonce) = GoogleSignIn.requestIdToken(activity)
                                shop.signInWithGoogle(token, nonce)
                            } catch (_: GoogleSignIn.Cancelled) {
                            } catch (e: Exception) {
                                shop.authError = e.message ?: "Google sign-in failed. Try again."
                            }
                        }
                    }
                    .testTag("googleSignIn")
                    .padding(vertical = 15.dp),
                horizontalArrangement = Arrangement.Center,
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Text("G", fontSize = 20.sp, color = if (c.dark) Color.Black else Color.White, style = Type.button)
                Spacer(Modifier.size(10.dp))
                Text("Continue with Google", style = Type.button, color = if (c.dark) Color.Black else Color.White)
            }
            Spacer(Modifier.height(12.dp))
            Text("We use your Google account to save your closet and coins. Nothing is shared.", style = Type.caption, color = c.subtle, textAlign = TextAlign.Center)
        } else {
            Text("Account sign-in is coming to Android. You can browse the whole catalog in the meantime.", style = Type.caption, color = c.subtle, textAlign = TextAlign.Center)
        }
        Spacer(Modifier.height(12.dp))
        if (guestAction != null) SoftButton("Browse without an account", tag = "guestBrowse", onClick = guestAction)
        Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
            TextLink("Privacy Policy") { context.openUrl(Config.PRIVACY_URL) }
            TextLink("Terms") { context.openUrl(Config.TERMS_URL) }
        }
        if (DebugLaunchOptions.testerSignInAvailable) {
            TextLink("Continue as tester", tag = "testerSignIn") { scope.launch { shop.devSignIn() } }
        }
        shop.authError?.let { Text(it, style = Type.caption, color = Palette.red, textAlign = TextAlign.Center, modifier = Modifier.padding(top = 6.dp)) }
        if (shop.authWorking) CircularProgressIndicator(Modifier.padding(top = 10.dp), color = Palette.violet)
    }
}

@Composable
fun SignInPrompt(onClose: () -> Unit) {
    val c = LocalDC.current
    BackHandler(onBack = onClose)
    Box(Modifier.fillMaxSize().background(c.bg).windowInsetsPadding(WindowInsets.systemBars).testTag("signInPrompt")) {
        Column(Modifier.fillMaxSize().verticalScroll(rememberScrollState())) {
            SignInPanel(
                "Save your haul",
                "Sign in to collect coins, fill your cart and keep everything you buy in your closet. Browsing stays free.",
                Icons.Filled.AddShoppingCart, Palette.violet, guestAction = null,
            )
        }
        TextLink("Not now", Modifier.align(Alignment.TopEnd).padding(8.dp), tag = "signInNotNow", onClick = onClose)
    }
}

/** The floating capsule tab bar with per-tab stacks kept alive, like `MainTabView`. */
@Composable
fun MainTabs() {
    val nav = LocalNav.current
    val graph = LocalGraph.current
    BackHandler(enabled = nav.sheets.isNotEmpty() || nav.stacks.getValue(nav.tab).isNotEmpty() || nav.tab != Tab.TODAY) { nav.back() }
    Box(Modifier.fillMaxSize()) {
        val stack = nav.stacks.getValue(nav.tab)
        val top = stack.lastOrNull()
        AnimatedContent(
            targetState = Triple(nav.tab, top, stack.size),
            transitionSpec = {
                when {
                    initialState.first != targetState.first -> fadeIn(tween(160)) togetherWith fadeOut(tween(120))
                    targetState.third > initialState.third -> slideInHorizontally(tween(260)) { it } togetherWith slideOutHorizontally(tween(260)) { -it / 4 }
                    else -> slideInHorizontally(tween(240)) { -it / 4 } togetherWith slideOutHorizontally(tween(240)) { it }
                }
            },
            label = "tabs",
        ) { (tab, screen, _) ->
            when (screen) {
                is Screen.Detail -> ProductDetailScreen(screen.productId)
                is Screen.Brand -> BrandScreen(screen.brandId)
                Screen.Shop -> ShopScreen()
                null -> when (tab) {
                    Tab.TODAY -> TodayScreen()
                    Tab.FOR_YOU -> ForYouScreen()
                    Tab.CART -> CartScreen()
                    Tab.CLOSET -> ClosetScreen()
                    Tab.PROFILE -> ProfileScreen()
                }
            }
        }
        if (nav.stacks.getValue(nav.tab).isEmpty()) {
            FloatingTabBar(nav.tab, graph.shop.cartIds.size, Modifier.align(Alignment.BottomCenter)) { nav.select(it) }
        }
        nav.sheets.forEach { sheet ->
            val shown = remember(sheet) { MutableTransitionState(false).apply { targetState = true } }
            AnimatedVisibility(shown, enter = slideInVertically(tween(300)) { it }, exit = slideOutVertically { it }) {
                Box(Modifier.fillMaxSize().background(LocalDC.current.bg)) {
                    when (sheet) {
                        Sheet.COIN_SHOP -> CoinShopScreen()
                        Sheet.SPIN -> SpinScreen()
                        Sheet.CHECKOUT -> CheckoutScreen()
                        Sheet.PLUS -> PlusOfferScreen(onboarding = false) { nav.dismiss(Sheet.PLUS) }
                        Sheet.SHIPPING -> ShippingScreen()
                        Sheet.LEDGER -> LedgerScreen()
                    }
                }
            }
        }
    }
}

@Composable
private fun FloatingTabBar(current: Tab, cartCount: Int, modifier: Modifier, onSelect: (Tab) -> Unit) {
    val c = LocalDC.current
    Row(
        modifier
            .navigationBarsPadding()
            .padding(bottom = 6.dp, start = 12.dp, end = 12.dp)
            .widthIn(max = 420.dp)
            .fillMaxWidth()
            .drawBehind {
                drawRoundRect(Color.Black.copy(alpha = if (c.dark) 0.25f else 0.08f), topLeft = Offset(0f, 5.dp.toPx()), cornerRadius = CornerRadius(size.height / 2))
            }
            .clip(CircleShape)
            .background(c.surface)
            .border(1.dp, c.hairline, CircleShape)
            .padding(5.dp)
            .testTag("tabBar"),
    ) {
        Tab.entries.forEach { t ->
            val on = t == current
            Column(
                Modifier
                    .weight(1f)
                    .clip(CircleShape)
                    .background(if (on) Palette.violet.copy(alpha = if (c.dark) 0.24f else 0.12f) else Color.Transparent)
                    .clickable(role = Role.Tab) { onSelect(t) }
                    .semantics { selected = on; contentDescription = t.title }
                    .testTag("tab-${t.name}")
                    .padding(vertical = 9.dp),
                horizontalAlignment = Alignment.CenterHorizontally,
            ) {
                Box {
                    Icon(t.icon, contentDescription = null, tint = if (on) Palette.violet else c.ink.copy(alpha = 0.72f), modifier = Modifier.size(22.dp))
                    if (t == Tab.CART && cartCount > 0) {
                        Text(
                            if (cartCount > 99) "99+" else "$cartCount",
                            fontSize = 9.sp, color = Color.White, style = Type.badge,
                            modifier = Modifier.offset(x = 12.dp, y = (-6).dp).clip(CircleShape).background(Palette.pink).padding(horizontal = 4.dp, vertical = 1.dp),
                        )
                    }
                }
                Spacer(Modifier.height(3.dp))
                Text(t.title, fontSize = 11.sp, style = Type.label, color = if (on) Palette.violet else c.ink.copy(alpha = 0.72f), maxLines = 1)
            }
        }
    }
}

/** Large-title page header with the wallet pill (or Sign in for guests) on the right. */
@Composable
fun PageHeader(title: String, showWallet: Boolean = true, onBack: (() -> Unit)? = null, trailing: @Composable (() -> Unit)? = null) {
    val graph = LocalGraph.current
    val nav = LocalNav.current
    val c = LocalDC.current
    Column(Modifier.fillMaxWidth().statusBarsPadding().padding(horizontal = 16.dp)) {
        Row(Modifier.fillMaxWidth().heightIn(min = 52.dp), verticalAlignment = Alignment.CenterVertically) {
            if (onBack != null) {
                Box(
                    Modifier.size(48.dp).clip(CircleShape).clickable(role = Role.Button, onClick = onBack).testTag("back").semantics { contentDescription = "Back" },
                    contentAlignment = Alignment.Center,
                ) { Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = null, tint = c.ink) }
            }
            Spacer(Modifier.weight(1f))
            trailing?.invoke()
            if (showWallet) {
                if (graph.shop.isGuest) TextLink("Sign in", tag = "headerSignIn") { graph.shop.requireAccount("wallet") }
                else WalletPill(graph.shop.coins) { nav.present(Sheet.COIN_SHOP) }
            }
        }
        if (title.isNotEmpty()) Text(title, style = Type.hero, color = c.ink, modifier = Modifier.padding(bottom = 6.dp).testTag("pageTitle"))
    }
}

/** Sheet header: title centred, a close or Done action. */
@Composable
fun SheetHeader(title: String, leading: String? = null, onLeading: () -> Unit = {}, trailing: String? = "Done", onTrailing: () -> Unit = {}) {
    val c = LocalDC.current
    BackHandler { if (trailing != null) onTrailing() else onLeading() }
    Box(Modifier.fillMaxWidth().statusBarsPadding().padding(horizontal = 8.dp).heightIn(min = 56.dp)) {
        if (leading != null) TextLink(leading, Modifier.align(Alignment.CenterStart), tag = "sheetLeading", onClick = onLeading)
        Text(title, style = Type.item, color = c.ink, modifier = Modifier.align(Alignment.Center))
        if (trailing != null) TextLink(trailing, Modifier.align(Alignment.CenterEnd), tag = "sheetDone", onClick = onTrailing)
    }
}

@Composable
fun CloseButton(modifier: Modifier = Modifier, onClick: () -> Unit) {
    val c = LocalDC.current
    Box(
        modifier.size(48.dp).clip(CircleShape).clickable(role = Role.Button, onClick = onClick).semantics { contentDescription = "Close" },
        contentAlignment = Alignment.Center,
    ) { Icon(Icons.Filled.Close, contentDescription = null, tint = c.subtle) }
}
