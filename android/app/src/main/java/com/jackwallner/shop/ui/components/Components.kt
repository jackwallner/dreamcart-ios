package com.jackwallner.shop.ui.components

import androidx.compose.animation.core.LinearEasing
import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.Refresh
import androidx.compose.material.icons.filled.Checkroom
import androidx.compose.material.icons.filled.ShoppingBag
import androidx.compose.material.icons.filled.AutoAwesome
import androidx.compose.material.icons.filled.Diamond
import androidx.compose.material.icons.filled.Star
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.drawBehind
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.jackwallner.shop.model.Format
import com.jackwallner.shop.model.Product
import com.jackwallner.shop.model.Rarity
import com.jackwallner.shop.ui.LocalGraph
import com.jackwallner.shop.ui.theme.LocalDC
import com.jackwallner.shop.ui.theme.Palette
import com.jackwallner.shop.ui.theme.Radii
import com.jackwallner.shop.ui.theme.Type

/** `cardStyle(_:)`: surface, hairline, and a soft drop shadow drawn behind (no elevation boxes). */
fun Modifier.card(dark: Boolean, surface: Color, hairline: Color, corner: Dp = Radii.card): Modifier = this
    .drawBehind {
        if (!dark) {
            val r = corner.toPx()
            for (i in 1..4) {
                drawRoundRect(
                    color = Color.Black.copy(alpha = 0.012f * (5 - i)),
                    topLeft = Offset(-i * 2f, i * 3f),
                    size = size.copy(width = size.width + i * 4f),
                    cornerRadius = CornerRadius(r + i * 2f),
                )
            }
        }
    }
    .clip(RoundedCornerShape(corner))
    .background(surface)
    .border(1.dp, hairline, RoundedCornerShape(corner))

@Composable
fun Modifier.dcCard(corner: Dp = Radii.card): Modifier {
    val c = LocalDC.current
    return card(c.dark, c.surface, c.hairline, corner)
}

@Composable
fun CandyButton(
    title: String,
    icon: ImageVector? = null,
    modifier: Modifier = Modifier,
    enabled: Boolean = true,
    tag: String? = null,
    onClick: () -> Unit,
) {
    Row(
        modifier
            .fillMaxWidth()
            .heightIn(min = 54.dp)
            .clip(CircleShape)
            .background(if (enabled) Palette.candy else Brush.linearGradient(listOf(Color(0xFFB9B4C4), Color(0xFFB9B4C4))))
            .clickable(enabled = enabled, role = Role.Button, onClick = onClick)
            .then(if (tag != null) Modifier.testTag(tag) else Modifier)
            .padding(horizontal = 20.dp, vertical = 15.dp),
        horizontalArrangement = Arrangement.Center,
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text(title, style = Type.button, color = Color.White, textAlign = TextAlign.Center)
        if (icon != null) {
            Spacer(Modifier.width(8.dp))
            Icon(icon, contentDescription = null, tint = Color.White, modifier = Modifier.size(20.dp))
        }
    }
}

@Composable
fun SoftButton(title: String, modifier: Modifier = Modifier, tag: String? = null, onClick: () -> Unit) {
    Box(
        modifier
            .fillMaxWidth()
            .heightIn(min = 50.dp)
            .clip(CircleShape)
            .background(Palette.violet.copy(alpha = 0.10f))
            .clickable(role = Role.Button, onClick = onClick)
            .then(if (tag != null) Modifier.testTag(tag) else Modifier)
            .padding(vertical = 14.dp),
        contentAlignment = Alignment.Center,
    ) { Text(title, style = Type.button, color = Palette.violet) }
}

@Composable
fun TextLink(title: String, modifier: Modifier = Modifier, color: Color = Palette.violet, tag: String? = null, onClick: () -> Unit) {
    Text(
        title,
        style = Type.label,
        color = color,
        modifier = modifier
            .clip(RoundedCornerShape(8.dp))
            .clickable(role = Role.Button, onClick = onClick)
            .then(if (tag != null) Modifier.testTag(tag) else Modifier)
            .heightIn(min = 48.dp)
            .padding(horizontal = 8.dp, vertical = 14.dp),
    )
}

/** The gold coin glyph. */
@Composable
fun CoinIcon(size: Dp = 16.dp) {
    Box(
        Modifier.size(size).clip(CircleShape).background(Palette.goldGradient).border(size * 0.08f, Color(0xFFD99A00), CircleShape),
        contentAlignment = Alignment.Center,
    ) {
        Text("¢", color = Color.White, fontSize = (size.value * 0.6f).sp, fontWeight = FontWeight.Black)
    }
}

@Composable
fun CoinLabel(amount: Int, size: Int = 14, color: Color = LocalDC.current.ink, weight: FontWeight = FontWeight.Black) {
    Row(verticalAlignment = Alignment.CenterVertically) {
        CoinIcon((size + 2).dp)
        Spacer(Modifier.width(4.dp))
        Text(Format.coins(amount), color = color, fontSize = size.sp, fontWeight = weight, maxLines = 1)
    }
}

/** The wallet pill in every tab's top bar. */
@Composable
fun WalletPill(coins: Int, onClick: () -> Unit) {
    val c = LocalDC.current
    Row(
        Modifier
            .clip(CircleShape)
            .background(c.surface)
            .border(1.dp, c.hairline, CircleShape)
            .clickable(role = Role.Button, onClick = onClick)
            .testTag("walletPill")
            .semantics { contentDescription = "${Format.coins(coins)} coins. Get more coins" }
            .heightIn(min = 40.dp)
            .padding(horizontal = 12.dp, vertical = 8.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        CoinIcon(18.dp)
        Spacer(Modifier.width(6.dp))
        Text(Format.coins(coins), style = Type.numeral, color = c.ink)
        Spacer(Modifier.width(6.dp))
        Box(Modifier.size(18.dp).clip(CircleShape).background(Palette.violet), contentAlignment = Alignment.Center) {
            Text("+", color = Color.White, fontSize = 13.sp, fontWeight = FontWeight.Black)
        }
    }
}

@Composable
fun Shimmer(modifier: Modifier = Modifier) {
    val t = rememberInfiniteTransition(label = "shimmer")
    val x by t.animateFloat(-1f, 2f, infiniteRepeatable(tween(1300, easing = LinearEasing), RepeatMode.Restart), label = "x")
    val base = if (LocalDC.current.dark) Color(0xFF26262B) else Color(0xFFEDEAE6)
    val hi = if (LocalDC.current.dark) Color(0xFF34343A) else Color(0xFFF8F6F3)
    Box(
        modifier.drawBehind {
            drawRect(base)
            val w = size.width
            drawRect(Brush.linearGradient(listOf(base, hi, base), start = Offset(w * x - w * 0.5f, 0f), end = Offset(w * x + w * 0.5f, size.height)))
        },
    )
}

/** `RemoteImage`: Pollinations art with a rarity wash, shimmer while loading and tap to retry. */
@Composable
fun RemoteImage(url: String, rarity: Rarity, modifier: Modifier = Modifier, maxPx: Int = 700) {
    val graph = LocalGraph.current
    val tint = Palette.rarity(rarity)
    var attempt by remember { mutableIntStateOf(0) }
    var bitmap by remember(url) { mutableStateOf(graph.images.cached(url, maxPx)) }
    var failed by remember(url) { mutableStateOf(false) }
    if (!graph.screenshotMode) {
        LaunchedEffect(url, attempt) {
            if (bitmap == null) {
                val b = graph.images.load(url, maxPx)
                bitmap = b
                failed = b == null
            }
        }
    }
    Box(modifier.background(Brush.verticalGradient(listOf(tint.copy(alpha = 0.16f), tint.copy(alpha = 0.04f)))), contentAlignment = Alignment.Center) {
        val b = bitmap
        when {
            graph.screenshotMode -> ScreenshotArtwork(url)
            b != null -> Image(b.asImageBitmap(), contentDescription = null, contentScale = ContentScale.Crop, modifier = Modifier.fillMaxSize())
            failed -> Column(
                Modifier.fillMaxSize().clickable { failed = false; attempt++ },
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.Center,
            ) {
                Icon(Icons.Filled.Refresh, contentDescription = null, tint = LocalDC.current.subtle.copy(alpha = 0.6f))
                Text("Tap to load", style = Type.caption, color = LocalDC.current.subtle.copy(alpha = 0.6f))
            }
            else -> Shimmer(Modifier.fillMaxSize())
        }
    }
}

/** `RemoteImage.screenshotArtwork`: stable gradient art so store captures never wait on the network. */
@Composable
private fun ScreenshotArtwork(seedSource: String) {
    val seed = seedSource.fold(0) { acc, ch -> (acc * 31 + ch.code) and 0x7fffffff }
    val styles = listOf(
        Triple(Color(0xFFAF52DE), Color(0xFFFF2D55), Icons.Filled.Checkroom),
        Triple(Color(0xFF007AFF), Color(0xFF5856D6), Icons.Filled.ShoppingBag),
        Triple(Color(0xFFFF9500), Color(0xFFFF2D55), Icons.Filled.ShoppingBag),
        Triple(Color(0xFF30B0C7), Color(0xFF007AFF), Icons.Filled.Star),
        Triple(Color(0xFF5856D6), Color(0xFFAF52DE), Icons.Filled.Diamond),
        Triple(Color(0xFFFF2D55), Color(0xFFFF9500), Icons.Filled.AutoAwesome),
    )
    val (a, b, icon) = styles[seed % styles.size]
    Box(Modifier.fillMaxSize().background(Brush.linearGradient(listOf(a, b))), contentAlignment = Alignment.Center) {
        Icon(icon, contentDescription = null, tint = Color.White.copy(alpha = 0.92f), modifier = Modifier.size(72.dp))
    }
}

@Composable
fun RarityChip(rarity: Rarity) {
    Text(
        rarity.label.uppercase(),
        style = Type.badge,
        color = Color.White,
        modifier = Modifier.clip(CircleShape).background(Palette.rarity(rarity)).padding(horizontal = 7.dp, vertical = 3.dp),
    )
}

/** `ProductCard`: art, brand, name, price, and NEW / owned markers. */
@Composable
fun ProductCard(product: Product, owned: Boolean, modifier: Modifier = Modifier, isNew: Boolean = false, onClick: () -> Unit) {
    val c = LocalDC.current
    Column(
        modifier
            .dcCard()
            .clickable(role = Role.Button, onClick = onClick)
            .testTag("product-${product.id}")
            .semantics(mergeDescendants = true) {},
    ) {
        Box(Modifier.fillMaxWidth().aspectRatio(0.86f)) {
            RemoteImage(product.imageUrl, product.rarityKind, Modifier.fillMaxSize())
            Row(Modifier.align(Alignment.TopStart).padding(8.dp), horizontalArrangement = Arrangement.spacedBy(4.dp)) {
                if (isNew) Text("NEW", style = Type.badge, color = Color.White, modifier = Modifier.clip(CircleShape).background(Palette.pink).padding(horizontal = 7.dp, vertical = 3.dp))
                if (product.rarityKind.glow) RarityChip(product.rarityKind)
            }
            if (owned) {
                Icon(
                    Icons.Filled.CheckCircle, contentDescription = "Owned", tint = Palette.green,
                    modifier = Modifier.align(Alignment.TopEnd).padding(8.dp).size(22.dp).clip(CircleShape).background(Color.White),
                )
            }
        }
        Column(Modifier.padding(horizontal = 10.dp, vertical = 9.dp)) {
            Text((product.brand?.name ?: "DreamCart").uppercase(), style = Type.badge, color = c.subtle, maxLines = 1)
            Text(product.name, style = Type.item, color = c.ink, maxLines = 2, overflow = TextOverflow.Ellipsis, modifier = Modifier.padding(top = 2.dp))
            Spacer(Modifier.size(4.dp))
            if (owned) Text("Owned", style = Type.price, color = Palette.green) else CoinLabel(product.price, size = 13)
        }
    }
}

@Composable
fun SectionHeader(title: String, subtitle: String? = null, actionTitle: String? = null, onAction: () -> Unit = {}) {
    val c = LocalDC.current
    Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
        Column(Modifier.weight(1f)) {
            Text(title, style = Type.section, color = c.ink)
            if (subtitle != null) Text(subtitle, style = Type.sub, color = c.subtle)
        }
        if (actionTitle != null) TextLink(actionTitle, onClick = onAction)
    }
}

@Composable
fun EmptyState(icon: ImageVector, title: String, message: String, modifier: Modifier = Modifier) {
    val c = LocalDC.current
    Column(modifier.fillMaxWidth().padding(horizontal = 28.dp), horizontalAlignment = Alignment.CenterHorizontally) {
        Box(Modifier.size(96.dp).clip(CircleShape).background(Palette.violet.copy(alpha = 0.12f)), contentAlignment = Alignment.Center) {
            Icon(icon, contentDescription = null, tint = Palette.violet, modifier = Modifier.size(40.dp))
        }
        Spacer(Modifier.size(16.dp))
        Text(title, style = Type.card, color = c.ink, textAlign = TextAlign.Center)
        Spacer(Modifier.size(6.dp))
        Text(message, style = Type.bodyText, color = c.subtle, textAlign = TextAlign.Center)
    }
}

@Composable
fun FilterChip(label: String, selected: Boolean, onClick: () -> Unit) {
    val c = LocalDC.current
    Text(
        label,
        style = Type.label,
        color = if (selected) Color.White else c.ink,
        modifier = Modifier
            .clip(CircleShape)
            .background(if (selected) Palette.violet else c.surface)
            .border(1.dp, if (selected) Color.Transparent else c.hairline, CircleShape)
            .clickable(role = Role.Tab, onClick = onClick)
            .heightIn(min = 40.dp)
            .padding(horizontal = 14.dp, vertical = 10.dp),
    )
}

/** `RewardOverlay`: the full-screen payoff after a claim, spin, pack or order. */
@Composable
fun RewardOverlay(title: String, amount: Int?, subtitle: String, onDone: () -> Unit) {
    val c = LocalDC.current
    val t = rememberInfiniteTransition(label = "reward")
    val glow by t.animateFloat(0.85f, 1.08f, infiniteRepeatable(tween(900), RepeatMode.Reverse), label = "glow")
    Box(
        Modifier.fillMaxSize().background(Color.Black.copy(alpha = 0.55f)).clickable(onClick = onDone).testTag("rewardOverlay"),
        contentAlignment = Alignment.Center,
    ) {
        Column(
            Modifier.padding(28.dp).dcCard(Radii.corner).clickable(enabled = false) {}.padding(26.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            Box(Modifier.size(96.dp).alpha(glow).clip(CircleShape).background(Palette.goldGradient), contentAlignment = Alignment.Center) {
                Icon(Icons.Filled.AutoAwesome, contentDescription = null, tint = Color.White, modifier = Modifier.size(44.dp))
            }
            Spacer(Modifier.size(14.dp))
            Text(title, style = Type.card, color = c.ink, textAlign = TextAlign.Center)
            if (amount != null) {
                Spacer(Modifier.size(6.dp))
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Text("+", style = Type.jumbo, color = Palette.gold)
                    CoinLabel(amount, size = 34, color = Palette.gold)
                }
            }
            Spacer(Modifier.size(8.dp))
            Text(subtitle, style = Type.bodyText, color = c.subtle, textAlign = TextAlign.Center)
            Spacer(Modifier.size(18.dp))
            CandyButton("Nice!", tag = "rewardDone", onClick = onDone)
        }
    }
}
