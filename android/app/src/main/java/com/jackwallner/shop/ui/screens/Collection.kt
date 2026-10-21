package com.jackwallner.shop.ui.screens

import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.gestures.detectDragGestures
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.GridItemSpan
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.foundation.lazy.grid.items
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.Undo
import androidx.compose.material.icons.filled.AddShoppingCart
import androidx.compose.material.icons.filled.AutoAwesome
import androidx.compose.material.icons.filled.Checkroom
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.Search
import androidx.compose.material.icons.automirrored.filled.Sort
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.TransformOrigin
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.semantics.CustomAccessibilityAction
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.customActions
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.unit.dp
import com.jackwallner.shop.model.Categories
import com.jackwallner.shop.model.ClosetSort
import com.jackwallner.shop.model.Product
import com.jackwallner.shop.ui.LocalGraph
import com.jackwallner.shop.ui.LocalNav
import com.jackwallner.shop.ui.PageHeader
import com.jackwallner.shop.ui.Screen
import com.jackwallner.shop.ui.components.CandyButton
import com.jackwallner.shop.ui.components.CoinLabel
import com.jackwallner.shop.ui.components.EmptyState
import com.jackwallner.shop.ui.components.FilterChip
import com.jackwallner.shop.ui.components.ProductCard
import com.jackwallner.shop.ui.components.RemoteImage
import com.jackwallner.shop.ui.components.SectionHeader
import com.jackwallner.shop.ui.components.dcCard
import com.jackwallner.shop.ui.theme.LocalDC
import com.jackwallner.shop.ui.theme.Palette
import com.jackwallner.shop.ui.theme.Radii
import com.jackwallner.shop.ui.theme.Type
import kotlin.math.abs
import kotlinx.coroutines.launch

/** `ForYouView`: a swipe deck of ranked picks. Pass left, cart right. */
@Composable
fun ForYouScreen() {
    val graph = LocalGraph.current
    val shop = graph.shop
    val nav = LocalNav.current
    val c = LocalDC.current
    val scope = rememberCoroutineScope()
    val picks = shop.logic().forYou()
    val dx = remember { Animatable(0f) }
    var flash by remember { mutableStateOf(false) }
    var position by remember { mutableStateOf(0) }

    fun decide(product: Product, accepted: Boolean) {
        graph.analytics.track(if (accepted) "swipe_like" else "swipe_discard", mapOf("product_id" to product.id, "direction" to if (accepted) "right" else "left", "position" to position))
        position++
        if (accepted) {
            if (!shop.requireAccount("add_to_cart")) return
            shop.addToCart(product.id, recommendation = true)
        } else {
            shop.dismissRecommendation(product.id)
        }
    }

    fun fling(product: Product, direction: Int, width: Float) {
        scope.launch {
            if (direction > 0 && shop.isGuest) {
                dx.animateTo(0f)
                shop.requireAccount("add_to_cart")
                return@launch
            }
            flash = direction > 0
            dx.animateTo(direction * width * 1.4f, tween(220))
            decide(product, direction > 0)
            dx.snapTo(0f)
            flash = false
        }
    }

    Column(Modifier.fillMaxSize()) {
        PageHeader("For You")
        Row(Modifier.padding(horizontal = 16.dp), verticalAlignment = Alignment.Bottom) {
            Column(Modifier.weight(1f)) {
                Text("Your next obsession", style = Type.card, color = c.ink)
                Text("Pass left. Cart right.", style = Type.sub, color = c.subtle)
            }
            Text("${picks.size} picks", style = Type.label, color = Palette.violet)
        }
        val top = picks.firstOrNull()
        if (top == null) {
            Column(Modifier.fillMaxWidth().padding(top = 40.dp, start = 32.dp, end = 32.dp), horizontalAlignment = Alignment.CenterHorizontally) {
                EmptyState(Icons.Filled.AutoAwesome, "You're all caught up", "Fresh picks appear as new pieces drop. You can also bring passed items back.")
                Spacer(Modifier.height(18.dp))
                CandyButton("Reconsider passes", Icons.AutoMirrored.Filled.Undo, tag = "reconsider") { shop.resetRecommendationDismissals() }
            }
            return@Column
        }
        androidx.compose.foundation.layout.BoxWithConstraints(Modifier.weight(1f).fillMaxWidth().padding(16.dp)) {
            val width = constraints.maxWidth.toFloat()
            picks.take(3).reversed().forEachIndexed { revIndex, p ->
                val slot = minOf(picks.size, 3) - 1 - revIndex
                val isTop = slot == 0
                Box(
                    Modifier
                        .fillMaxSize()
                        .padding(top = (slot * 10).dp)
                        .graphicsLayer {
                            if (isTop) {
                                translationX = dx.value
                                rotationZ = dx.value / width * 14f
                                transformOrigin = TransformOrigin(0.5f, 1f)
                            } else {
                                scaleX = 1f - slot * 0.04f
                                scaleY = 1f - slot * 0.04f
                            }
                        }
                        .then(
                            if (isTop) Modifier
                                .pointerInput(p.id) {
                                    detectDragGestures(
                                        onDragEnd = {
                                            val v = dx.value
                                            if (abs(v) > width * 0.28f) fling(p, if (v >= 0) 1 else -1, width)
                                            else scope.launch { dx.animateTo(0f) }
                                        },
                                        onDrag = { change, drag ->
                                            change.consume()
                                            scope.launch { dx.snapTo(dx.value + drag.x) }
                                        },
                                    )
                                }
                                .clickable { nav.push(Screen.Detail(p.id)) }
                                .semantics {
                                    contentDescription = "${p.name}, ${p.price} coins"
                                    customActions = listOf(
                                        CustomAccessibilityAction("Pass") { fling(p, -1, width); true },
                                        CustomAccessibilityAction("Add to cart") { fling(p, 1, width); true },
                                    )
                                }
                                .testTag("deckTop")
                            else Modifier,
                        ),
                ) { DeckCard(p, if (isTop) dx.value / width else 0f, flash && isTop) }
            }
        }
        Row(Modifier.fillMaxWidth().padding(bottom = TabBarClearance, top = 4.dp), horizontalArrangement = Arrangement.spacedBy(36.dp, Alignment.CenterHorizontally)) {
            RoundAction(Icons.Filled.Close, Palette.red, "Pass", "deckPass") { fling(top, -1, 1000f) }
            RoundAction(Icons.Filled.AddShoppingCart, Palette.green, "Add to cart", "deckAdd") { fling(top, 1, 1000f) }
        }
    }
}

@Composable
private fun DeckCard(p: Product, progress: Float, carted: Boolean) {
    Box(Modifier.fillMaxSize().clip(RoundedCornerShape(Radii.corner)).dcCard(Radii.corner)) {
        RemoteImage(p.imageUrl, p.rarityKind, Modifier.fillMaxSize(), maxPx = 1400)
        Column(
            Modifier.align(Alignment.BottomStart).fillMaxWidth()
                .background(Brush.verticalGradient(listOf(Color.Transparent, Color.Black.copy(alpha = 0.72f))))
                .padding(18.dp),
        ) {
            Text(p.brand?.name?.uppercase() ?: "DREAMCART", style = Type.overline, color = Color.White.copy(alpha = 0.85f))
            Text(p.name, style = Type.title, color = Color.White)
            Row(verticalAlignment = Alignment.CenterVertically) {
                CoinLabel(p.price, size = 16, color = Color.White)
                Spacer(Modifier.width(12.dp))
                Text(p.styleTags.take(3).joinToString("  ") { "#$it" }, style = Type.sub, color = Color.White.copy(alpha = 0.85f), maxLines = 1)
            }
        }
        if (progress > 0.05f || carted) Stamp(if (carted) "CARTED!" else "ADD", Palette.green, -10f, Modifier.align(Alignment.TopStart).graphicsLayer { alpha = if (carted) 1f else (progress * 3).coerceIn(0f, 1f) })
        if (progress < -0.05f) Stamp("PASS", Palette.red, 10f, Modifier.align(Alignment.TopEnd).graphicsLayer { alpha = (-progress * 3).coerceIn(0f, 1f) })
    }
}

@Composable
private fun Stamp(text: String, color: Color, angle: Float, modifier: Modifier) {
    Text(
        text, style = Type.title, color = color,
        modifier = modifier.padding(22.dp).graphicsLayer { rotationZ = angle }
            .background(Color.White.copy(alpha = 0.9f), RoundedCornerShape(10.dp)).padding(horizontal = 12.dp, vertical = 4.dp),
    )
}

@Composable
private fun RoundAction(icon: androidx.compose.ui.graphics.vector.ImageVector, color: Color, label: String, tag: String, onClick: () -> Unit) {
    Box(
        Modifier.size(64.dp).clip(CircleShape).background(LocalDC.current.surface).clickable(role = Role.Button, onClick = onClick)
            .semantics { contentDescription = label }.testTag(tag),
        contentAlignment = Alignment.Center,
    ) { Icon(icon, contentDescription = null, tint = color, modifier = Modifier.size(30.dp)) }
}

/** `ClosetView`: owned pieces with search, category chips, sort, and the fresh "New haul". */
@Composable
fun ClosetScreen() {
    val shop = LocalGraph.current.shop
    val nav = LocalNav.current
    val c = LocalDC.current
    var query by remember { mutableStateOf("") }
    var category by remember { mutableStateOf<String?>(null) }
    var sort by remember { mutableStateOf(ClosetSort.NEWEST) }
    var sortOpen by remember { mutableStateOf(false) }
    val closet = shop.closet
    val t = query.trim().lowercase()
    val filtered = closet
        .filter { category == null || it.category == category }
        .filter { p -> t.isEmpty() || p.name.lowercase().contains(t) || p.colorName.lowercase().contains(t) || p.styleTags.any { it.lowercase().contains(t) } }
        .let { list ->
            when (sort) {
                ClosetSort.NEWEST -> list.sortedByDescending { shop.closetAcquiredAt[it.id] ?: "" }
                ClosetSort.NAME -> list.sortedBy { it.name.lowercase() }
                ClosetSort.PRICE_HIGH -> list.sortedByDescending { it.price }
                ClosetSort.PRICE_LOW -> list.sortedBy { it.price }
            }
        }
    val highlight = nav.closetHighlight.mapNotNull { id -> closet.firstOrNull { it.id == id } }
    LazyVerticalGrid(
        GridCells.Adaptive(160.dp), Modifier.fillMaxSize().testTag("closetGrid"),
        contentPadding = PaddingValues(start = 16.dp, end = 16.dp, bottom = TabBarClearance),
        horizontalArrangement = Arrangement.spacedBy(12.dp), verticalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        item(span = { GridItemSpan(maxLineSpan) }) { Column(Modifier.bleed(16.dp)) { PageHeader("Closet") } }
        when {
            shop.isGuest -> item(span = { GridItemSpan(maxLineSpan) }) {
                GuestGate(Icons.Filled.Checkroom, "Your closet lives in your account", "Sign in so everything you buy is saved and ready to style into outfits.", "closet_tab")
            }
            closet.isEmpty() -> item(span = { GridItemSpan(maxLineSpan) }) {
                EmptyState(Icons.Filled.Checkroom, "Your closet is empty", "Pieces you buy stay here so you can revisit your collection anytime.", Modifier.padding(top = 50.dp))
            }
            else -> {
                item(span = { GridItemSpan(maxLineSpan) }) {
                    Row(Modifier.fillMaxWidth().dcCard().padding(16.dp), verticalAlignment = Alignment.CenterVertically) {
                        Icon(Icons.Filled.Checkroom, contentDescription = null, tint = Palette.violet)
                        Spacer(Modifier.width(12.dp))
                        Column {
                            Text("Your collection", style = Type.card, color = c.ink)
                            Text(if (closet.size == 1) "1 piece owned" else "${closet.size} pieces owned", style = Type.sub, color = c.subtle)
                        }
                    }
                }
                if (highlight.isNotEmpty()) {
                    item(span = { GridItemSpan(maxLineSpan) }) {
                        Column {
                            SectionHeader("New haul", "Just added to your closet", "Done") { nav.closetHighlight = emptyList() }
                            LazyRow(contentPadding = PaddingValues(vertical = 10.dp), horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                                items(highlight, key = { "h" + it.id }) { p -> ProductCard(p, owned = true, Modifier.width(150.dp), isNew = true) { nav.push(Screen.Detail(p.id)) } }
                            }
                        }
                    }
                }
                item(span = { GridItemSpan(maxLineSpan) }) {
                    Column(Modifier.bleed(16.dp)) {
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            Box(Modifier.weight(1f)) { SearchField(query, "Search your closet", tag = "closetSearch") { query = it } }
                            Box(Modifier.padding(end = 12.dp)) {
                                Box(
                                    Modifier.size(48.dp).clip(CircleShape).clickable { sortOpen = true }.semantics { contentDescription = "Sort closet, ${sort.label}" },
                                    contentAlignment = Alignment.Center,
                                ) { Icon(Icons.AutoMirrored.Filled.Sort, contentDescription = null, tint = Palette.violet) }
                                DropdownMenu(sortOpen, { sortOpen = false }) {
                                    ClosetSort.entries.forEach { s -> DropdownMenuItem(text = { Text(s.label) }, onClick = { sort = s; sortOpen = false }) }
                                }
                            }
                        }
                        LazyRow(contentPadding = PaddingValues(horizontal = 16.dp, vertical = 8.dp), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                            item { FilterChip("All", category == null) { category = null } }
                            items(closet.map { it.category }.distinct().sortedBy { Categories.label(it) }) { cat ->
                                FilterChip(Categories.label(cat), category == cat) { category = if (category == cat) null else cat }
                            }
                        }
                        Box(Modifier.padding(horizontal = 16.dp)) {
                            SectionHeader(if (query.isEmpty()) "All pieces" else "Search results", if (filtered.size == 1) "1 piece" else "${filtered.size} pieces")
                        }
                    }
                }
                if (filtered.isEmpty()) item(span = { GridItemSpan(maxLineSpan) }) { EmptyState(Icons.Filled.Search, "Nothing matches", "Try another search or category.") }
                items(filtered, key = { it.id }) { p -> ProductCard(p, owned = true) { nav.push(Screen.Detail(p.id)) } }
            }
        }
    }
}

