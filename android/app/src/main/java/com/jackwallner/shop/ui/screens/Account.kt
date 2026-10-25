package com.jackwallner.shop.ui.screens

import android.content.Intent
import android.net.Uri
import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.CubicBezierEasing
import androidx.compose.animation.core.tween
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.combinedClickable
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
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ExitToApp
import androidx.compose.material.icons.automirrored.filled.OpenInNew
import androidx.compose.material.icons.filled.AddCircle
import androidx.compose.material.icons.filled.Brightness6
import androidx.compose.material.icons.filled.Description
import androidx.compose.material.icons.filled.History
import androidx.compose.material.icons.filled.Info
import androidx.compose.material.icons.filled.LocalFireDepartment
import androidx.compose.material.icons.filled.LocalShipping
import androidx.compose.material.icons.filled.Mail
import androidx.compose.material.icons.filled.NotificationsActive
import androidx.compose.material.icons.filled.Person
import androidx.compose.material.icons.filled.PersonAdd
import androidx.compose.material.icons.filled.PrivacyTip
import androidx.compose.material.icons.filled.Star
import androidx.compose.material.icons.filled.WorkspacePremium
import androidx.compose.material.icons.filled.ChevronRight
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.OutlinedTextFieldDefaults
import androidx.compose.material3.Switch
import androidx.compose.material3.SwitchDefaults
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
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.nativeCanvas
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.drawscope.rotate
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalHapticFeedback
import androidx.compose.ui.hapticfeedback.HapticFeedbackType
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.semantics.stateDescription
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import com.jackwallner.shop.Appearance
import com.jackwallner.shop.BuildConfig
import com.jackwallner.shop.data.Config
import com.jackwallner.shop.data.DropReminders
import com.jackwallner.shop.model.Format
import com.jackwallner.shop.model.PlusPlan
import com.jackwallner.shop.model.Wheel
import com.jackwallner.shop.ui.LocalGraph
import com.jackwallner.shop.ui.LocalNav
import com.jackwallner.shop.ui.PageHeader
import com.jackwallner.shop.ui.Sheet
import com.jackwallner.shop.ui.SheetHeader
import com.jackwallner.shop.ui.components.CandyButton
import com.jackwallner.shop.ui.components.EmptyState
import com.jackwallner.shop.ui.components.RewardOverlay
import com.jackwallner.shop.ui.components.TextLink
import com.jackwallner.shop.ui.components.dcCard
import com.jackwallner.shop.ui.openUrl
import com.jackwallner.shop.ui.theme.LocalDC
import com.jackwallner.shop.ui.theme.Palette
import com.jackwallner.shop.ui.theme.Type
import kotlin.math.cos
import kotlin.math.sin
import kotlinx.coroutines.launch

/** `ProfileView`: stats, DreamCart+, coins, address, reminders, appearance, legal, account. */
@Composable
fun ProfileScreen() {
    val graph = LocalGraph.current
    val shop = graph.shop
    val nav = LocalNav.current
    val c = LocalDC.current
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    var confirmDelete by remember { mutableStateOf(false) }
    var deleting by remember { mutableStateOf(false) }
    var deleteError by remember { mutableStateOf<String?>(null) }
    var reviewerCodeOpen by remember { mutableStateOf(false) }
    val permission = androidx.activity.compose.rememberLauncherForActivityResult(androidx.activity.result.contract.ActivityResultContracts.RequestPermission()) { granted ->
        if (granted) graph.reminders.enable()
    }
    Column(Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(bottom = TabBarClearance).testTag("profile")) {
        PageHeader("You")
        Column(Modifier.padding(horizontal = 16.dp), verticalArrangement = Arrangement.spacedBy(16.dp)) {
            if (shop.isGuest) {
                Column(Modifier.fillMaxWidth().dcCard().padding(20.dp), horizontalAlignment = Alignment.CenterHorizontally) {
                    Box(Modifier.size(72.dp).clip(CircleShape).background(Palette.violet.copy(alpha = 0.12f)), contentAlignment = Alignment.Center) {
                        Icon(Icons.Filled.Person, contentDescription = null, tint = Palette.violet, modifier = Modifier.size(34.dp))
                    }
                    Spacer(Modifier.height(10.dp))
                    Text("Browsing as guest", style = Type.card, color = c.ink)
                    Text("Sign in to earn coins and keep a closet.", style = Type.sub, color = c.subtle)
                }
                Rows { Row("Sign in", Icons.Filled.PersonAdd, Palette.violet, tag = "profileSignIn") { shop.requireAccount("profile") } }
            } else {
                PurchaseRecoveryStatus()
                val me = shop.me
                val name = me?.displayName?.trim().orEmpty().ifEmpty { "Shopper" }
                Column(Modifier.fillMaxWidth().dcCard().padding(20.dp), horizontalAlignment = Alignment.CenterHorizontally) {
                    Box(Modifier.size(72.dp).clip(CircleShape).background(Palette.candy), contentAlignment = Alignment.Center) {
                        Text(name.take(1).uppercase(), style = Type.title, color = Color.White)
                    }
                    Spacer(Modifier.height(10.dp))
                    Text(name, style = Type.card, color = c.ink)
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Icon(Icons.Filled.LocalFireDepartment, contentDescription = null, tint = Palette.coral, modifier = Modifier.size(16.dp))
                        Text("${me?.streak ?: 0}-day streak", style = Type.sub, color = c.subtle)
                    }
                    Spacer(Modifier.height(14.dp))
                    Row(Modifier.fillMaxWidth()) {
                        Stat(Format.coins(shop.coins), "Coins", Palette.gold)
                        Stat("${me?.itemsOwned ?: 0}", "Owned", Palette.violet)
                        Stat("${me?.bestStreak ?: 0}", "Best", Palette.pink)
                    }
                }
                Rows {
                    if (!graph.screenshotMode) {
                        if (shop.isPlus) Row(PlusPlan.NAME, Icons.Filled.WorkspacePremium, Palette.gold, "Active · manage or cancel in Google Play", tag = "profilePlusActive") { context.openUrl(PlusPlan.MANAGE_URL) }
                        else Row(PlusPlan.NAME, Icons.Filled.WorkspacePremium, Palette.gold, "Double daily coins, unlimited spins", tag = "profilePlus") { nav.present(Sheet.PLUS) }
                        Row("Get more coins", Icons.Filled.AddCircle, Palette.violet, tag = "profileCoins") { nav.present(Sheet.COIN_SHOP) }
                    }
                    Row("Shipping address", Icons.Filled.LocalShipping, Palette.coral, shop.shipping.shortSummary, tag = "profileShipping") { nav.present(Sheet.SHIPPING) }
                    Row("Coin history", Icons.Filled.History, c.subtle, tag = "profileLedger") { nav.present(Sheet.LEDGER) }
                }
            }
            Rows {
                val r = graph.reminders
                Row(Modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 10.dp), verticalAlignment = Alignment.CenterVertically) {
                    Icon(Icons.Filled.NotificationsActive, contentDescription = null, tint = Palette.pink)
                    Spacer(Modifier.width(14.dp))
                    Column(Modifier.weight(1f)) {
                        Text("New drop reminders", style = Type.body, color = c.ink)
                        Text(if (r.isEnabled) "One reminder daily at ${DropReminders.timeLabel(r.minuteOfDay)}" else "Off", style = Type.caption, color = c.subtle)
                    }
                    Switch(
                        r.isEnabled,
                        { on ->
                            if (!on) r.disable()
                            else if (android.os.Build.VERSION.SDK_INT >= 33 && !r.hasPermission) permission.launch(android.Manifest.permission.POST_NOTIFICATIONS)
                            else r.enable()
                        },
                        Modifier.testTag("reminderSwitch"),
                        colors = SwitchDefaults.colors(checkedTrackColor = Palette.violet),
                    )
                }
                AppearanceRow()
            }
            Rows {
                Row("Rate DreamCart", Icons.Filled.Star, Palette.gold) { context.openUrl(Config.PLAY_LISTING) }
                Row("Send feedback", Icons.Filled.Mail, Palette.violet) {
                    runCatching { context.startActivity(Intent(Intent.ACTION_SENDTO, Uri.parse("mailto:${Config.SUPPORT_EMAIL}?subject=DreamCart%20feedback"))) }
                }
                Row("Privacy Policy", Icons.Filled.PrivacyTip, c.subtle, external = true) { context.openUrl(Config.PRIVACY_URL) }
                Row("Terms of Use", Icons.Filled.Description, c.subtle, external = true) { context.openUrl(Config.TERMS_URL) }
                VersionRow { reviewerCodeOpen = true }
            }
            if (!shop.isGuest) {
                Rows { Row("Sign out", Icons.AutoMirrored.Filled.ExitToApp, c.subtle, tag = "signOut") { shop.signOut() } }
                TextLink("Delete account", Modifier.align(Alignment.CenterHorizontally), color = Palette.red, tag = "deleteAccount") { confirmDelete = true }
            }
            Text(
                "DreamCart is a virtual shopping game. Everything here, including coins, items, and delivery, is imaginary and has no cash value.",
                style = Type.caption, color = c.subtle, textAlign = TextAlign.Center, modifier = Modifier.fillMaxWidth().padding(horizontal = 12.dp),
            )
        }
    }
    if (reviewerCodeOpen) ReviewerCodeDialog(onUnlock = graph.reviewAccess::activate, onClose = { reviewerCodeOpen = false })
    if (confirmDelete) AlertDialog(
        onDismissRequest = { confirmDelete = false },
        title = { Text("Delete your account?") },
        text = { Text("This erases your closet, coins, and streak for good.") },
        confirmButton = {
            TextLink("Delete everything", color = Palette.red, tag = "confirmDelete") {
                confirmDelete = false
                scope.launch {
                    deleting = true
                    runCatching { shop.deleteAccount() }.onFailure { deleteError = it.message ?: "Could not delete your account. Try again." }
                    deleting = false
                }
            }
        },
        dismissButton = { TextLink("Cancel") { confirmDelete = false } },
    )
    deleteError?.let { msg ->
        AlertDialog(onDismissRequest = { deleteError = null }, title = { Text("Account not deleted") }, text = { Text(msg) }, confirmButton = { TextLink("OK") { deleteError = null } })
    }
    if (deleting) Box(Modifier.fillMaxSize().background(Color.Black.copy(alpha = 0.4f)), contentAlignment = Alignment.Center) {
        Column(Modifier.dcCard().padding(24.dp), horizontalAlignment = Alignment.CenterHorizontally) {
            CircularProgressIndicator(color = Palette.violet)
            Spacer(Modifier.height(10.dp))
            Text("Deleting your account…", style = Type.body, color = c.ink)
        }
    }
}

@Composable
private fun androidx.compose.foundation.layout.RowScope.Stat(value: String, label: String, tint: Color) {
    Column(Modifier.weight(1f), horizontalAlignment = Alignment.CenterHorizontally) {
        Text(value, style = Type.stat, color = tint)
        Text(label, style = Type.caption, color = LocalDC.current.subtle)
    }
}

@Composable
private fun Rows(content: @Composable () -> Unit) {
    Column(Modifier.fillMaxWidth().dcCard().padding(vertical = 4.dp)) { content() }
}

@Composable
private fun Row(title: String, icon: ImageVector, tint: Color, subtitle: String? = null, external: Boolean = false, tag: String? = null, onClick: () -> Unit) {
    val c = LocalDC.current
    androidx.compose.foundation.layout.Row(
        Modifier.fillMaxWidth().clickable(role = Role.Button, onClick = onClick).then(if (tag != null) Modifier.testTag(tag) else Modifier)
            .heightIn(min = 52.dp).padding(horizontal = 16.dp, vertical = 12.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Icon(icon, contentDescription = null, tint = tint)
        Spacer(Modifier.width(14.dp))
        Column(Modifier.weight(1f)) {
            Text(title, style = Type.body, color = c.ink)
            if (subtitle != null) Text(subtitle, style = Type.caption, color = c.subtle)
        }
        Icon(if (external) Icons.AutoMirrored.Filled.OpenInNew else Icons.Filled.ChevronRight, contentDescription = null, tint = c.subtle.copy(alpha = 0.5f), modifier = Modifier.size(20.dp))
    }
}

/** A long press opens the Play reviewer unlock; the row has no other action. */
@Composable
private fun VersionRow(onLongPress: () -> Unit) {
    val c = LocalDC.current
    androidx.compose.foundation.layout.Row(
        Modifier.fillMaxWidth().combinedClickable(onClick = {}, onLongClick = onLongPress).testTag("version-row")
            .heightIn(min = 52.dp).padding(horizontal = 16.dp, vertical = 12.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Icon(Icons.Filled.Info, contentDescription = null, tint = c.subtle)
        Spacer(Modifier.width(14.dp))
        Text("Version", style = Type.body, color = c.ink, modifier = Modifier.weight(1f))
        Text(BuildConfig.VERSION_NAME, style = Type.body, color = c.subtle)
    }
}

@Composable
private fun ReviewerCodeDialog(onUnlock: (String) -> Boolean, onClose: () -> Unit) {
    var code by remember { mutableStateOf("") }
    var failed by remember { mutableStateOf(false) }
    AlertDialog(
        onDismissRequest = onClose,
        title = { Text("Reviewer access") },
        text = {
            Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                Text("Enter the code from the Play review instructions.")
                OutlinedTextField(
                    value = code,
                    onValueChange = { code = it; failed = false },
                    label = { Text("Reviewer code") },
                    singleLine = true,
                    isError = failed,
                    keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Password, autoCorrectEnabled = false),
                    visualTransformation = PasswordVisualTransformation(),
                    colors = OutlinedTextFieldDefaults.colors(focusedBorderColor = Palette.violet, focusedLabelColor = Palette.violet),
                    modifier = Modifier.testTag("reviewer-code"),
                )
                if (failed) Text("That code isn't valid.", style = Type.caption, color = Palette.red)
            }
        },
        confirmButton = { TextLink("Unlock", tag = "reviewer-unlock") { if (onUnlock(code)) onClose() else failed = true } },
        dismissButton = { TextLink("Cancel") { onClose() } },
    )
}

@Composable
private fun AppearanceRow() {
    val graph = LocalGraph.current
    val c = LocalDC.current
    androidx.compose.foundation.layout.Row(
        Modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 10.dp).testTag("appearance"),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Icon(Icons.Filled.Brightness6, contentDescription = null, tint = Palette.violet)
        Spacer(Modifier.width(14.dp))
        Text("Appearance", style = Type.body, color = c.ink, modifier = Modifier.weight(1f))
        androidx.compose.foundation.layout.Row(Modifier.clip(CircleShape).background(c.bg).padding(3.dp)) {
            Appearance.entries.forEach { a ->
                val on = graph.appearance == a
                Text(
                    a.label, style = Type.label, color = if (on) Color.White else c.ink,
                    modifier = Modifier.clip(CircleShape).background(if (on) Palette.violet else Color.Transparent)
                        .clickable(role = Role.RadioButton) { graph.updateAppearance(a) }
                        .semantics { stateDescription = if (on) "Selected" else "" }
                        .testTag("appearance-${a.name}")
                        .padding(horizontal = 12.dp, vertical = 8.dp),
                )
            }
        }
    }
}

/** `LedgerView`: the last 60 coin movements. */
@Composable
fun LedgerScreen() {
    val shop = LocalGraph.current.shop
    val nav = LocalNav.current
    val c = LocalDC.current
    var loading by remember { mutableStateOf(true) }
    var error by remember { mutableStateOf<String?>(null) }
    LaunchedEffect(Unit) {
        runCatching { shop.loadLedger() }.onFailure { error = it.message }
        loading = false
    }
    Column(Modifier.fillMaxSize().testTag("ledger")) {
        SheetHeader("Coin history", onTrailing = { nav.dismiss(Sheet.LEDGER) })
        when {
            loading -> Box(Modifier.fillMaxWidth().padding(40.dp), contentAlignment = Alignment.Center) { CircularProgressIndicator(color = Palette.violet) }
            error != null -> EmptyState(Icons.Filled.History, "Couldn't load your coin history", "Check your connection and try again.", Modifier.padding(top = 40.dp))
            shop.ledger.isEmpty() -> EmptyState(Icons.Filled.History, "No coin activity yet", "Daily drops, spins, shopping, and coin packs will appear here.", Modifier.padding(top = 40.dp))
            else -> LazyColumn(Modifier.fillMaxSize().navigationBarsPadding(), contentPadding = PaddingValues(16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                items(shop.ledger, key = { it.id }) { e ->
                    androidx.compose.foundation.layout.Row(Modifier.fillMaxWidth().dcCard().padding(14.dp), verticalAlignment = Alignment.CenterVertically) {
                        Column(Modifier.weight(1f)) {
                            Text(e.label, style = Type.body, color = c.ink)
                            Text(e.createdAt.take(10), style = Type.caption, color = c.subtle)
                        }
                        Text("${if (e.delta > 0) "+" else ""}${Format.coins(e.delta)}", style = Type.price, color = if (e.delta >= 0) Palette.green else c.ink)
                    }
                }
            }
        }
    }
}

/** `SpinView`: the prize wheel. The server picks the slice; the wheel lands on it. */
@Composable
fun SpinScreen() {
    val graph = LocalGraph.current
    val shop = graph.shop
    val nav = LocalNav.current
    val c = LocalDC.current
    val scope = rememberCoroutineScope()
    val haptics = LocalHapticFeedback.current
    val rotation = remember { Animatable(0f) }
    var spinning by remember { mutableStateOf(false) }
    var result by remember { mutableStateOf<Pair<Int, Wheel.Tier>?>(null) }
    var error by remember { mutableStateOf<String?>(null) }
    val canSpin = shop.me != null && (shop.me?.canSpin == true || shop.isPlus)
    Column(Modifier.fillMaxSize().testTag("spin")) {
        SheetHeader("", trailing = "Close", onTrailing = { if (!spinning) nav.dismiss(Sheet.SPIN) })
        Column(Modifier.weight(1f).padding(horizontal = 24.dp), horizontalAlignment = Alignment.CenterHorizontally) {
            Text("Spin to win", style = Type.hero, color = c.ink)
            Spacer(Modifier.height(24.dp))
            Box(Modifier.fillMaxWidth().aspectRatio(1f), contentAlignment = Alignment.TopCenter) {
                WheelFace(rotation.value, Modifier.fillMaxSize().padding(top = 14.dp).semantics {
                    contentDescription = "Prize wheel: " + Wheel.PRIZES.joinToString(", ") { "$it coins" }
                })
                Pointer()
            }
            Spacer(Modifier.height(28.dp))
            CandyButton(if (spinning) "Spinning…" else if (canSpin) "Spin" else "Come back tomorrow", enabled = canSpin && !spinning, tag = "spinButton") {
                scope.launch {
                    spinning = true
                    error = null
                    val r = shop.spin()
                    if (r == null || !r.ok || r.slice == null || r.prize == null) {
                        error = if (r?.reason == "spun_today") "You've used today's spin." else "The wheel jammed. Try again."
                        spinning = false
                        shop.refreshMe()
                        return@launch
                    }
                    rotation.animateTo(Wheel.targetRotation(rotation.value, r.slice), tween(4200, easing = CubicBezierEasing(0.12f, 0.8f, 0.18f, 1f)))
                    haptics.performHapticFeedback(HapticFeedbackType.LongPress)
                    shop.refreshMe()
                    spinning = false
                    result = r.prize to Wheel.tier(r.prize)
                }
            }
            error?.let { Text(it, style = Type.caption, color = Palette.red, modifier = Modifier.padding(top = 8.dp)) }
            if (!canSpin && !spinning) Text("Resets at midnight", style = Type.caption, color = c.subtle, modifier = Modifier.padding(top = 8.dp))
        }
    }
    result?.let { (prize, tier) ->
        val title = when (tier) {
            Wheel.Tier.JACKPOT -> "JACKPOT!"
            Wheel.Tier.BIG -> "Big win!"
            Wheel.Tier.SMALL -> "You won"
        }
        RewardOverlay(title, prize, "Added to your wallet.") {
            result = null
            nav.dismiss(Sheet.SPIN)
        }
    }
}

private val sliceColors = listOf(Palette.violet, Palette.pink, Palette.coral, Palette.gold, Palette.violet, Palette.pink, Palette.coral, Palette.gold)

@Composable
private fun WheelFace(rotationDeg: Float, modifier: Modifier) {
    val labelPaint = remember {
        android.graphics.Paint().apply {
            color = android.graphics.Color.WHITE
            textAlign = android.graphics.Paint.Align.CENTER
            isFakeBoldText = true
            isAntiAlias = true
            setShadowLayer(4f, 0f, 2f, 0x59000000)
        }
    }
    Canvas(modifier) {
        val d = size.minDimension
        val r = d / 2
        val center = Offset(size.width / 2, size.height / 2)
        val per = 360f / Wheel.SLICES
        labelPaint.textSize = d * 0.055f
        rotate(rotationDeg, center) {
            for (i in 0 until Wheel.SLICES) {
                // Slice i is centred at i * per degrees clockwise from 12 o'clock.
                val start = -90f + i * per - per / 2
                drawArc(
                    Brush.radialGradient(listOf(sliceColors[i].copy(alpha = 0.78f), sliceColors[i]), center, r),
                    start, per, true, topLeft = Offset(center.x - r, center.y - r), size = Size(d, d),
                )
                drawArc(Color.White.copy(alpha = 0.55f), start, per, true, topLeft = Offset(center.x - r, center.y - r), size = Size(d, d), style = Stroke(2f))
                val a = Math.toRadians((i * per).toDouble())
                val lr = r * 0.66f
                val x = center.x + (lr * sin(a)).toFloat()
                val y = center.y - (lr * cos(a)).toFloat()
                // Labels on the lower half flip so they never read upside down.
                val labelAngle = i * per + if (i * per > 90f && i * per < 270f) 180f else 0f
                rotate(labelAngle, Offset(x, y)) {
                    drawContext.canvas.nativeCanvas.drawText(Format.coinsShort(Wheel.PRIZES[i]), x, y + labelPaint.textSize / 3, labelPaint)
                }
            }
            for (i in 0 until 16) {
                val a = Math.toRadians(i * 22.5)
                val pr = r * 0.93f
                drawCircle(Palette.goldLite, radius = d * (if (i % 2 == 0) 0.013f else 0.008f), center = Offset(center.x + (pr * sin(a)).toFloat(), center.y - (pr * cos(a)).toFloat()))
            }
        }
        drawCircle(Palette.goldGradient, radius = r - d * 0.013f, center = center, style = Stroke(d * 0.026f))
        drawCircle(Color.White, radius = d * 0.08f, center = center)
        drawCircle(Palette.gold, radius = d * 0.08f, center = center, style = Stroke(d * 0.012f))
    }
}

@Composable
private fun Pointer() {
    Canvas(Modifier.size(34.dp, 40.dp)) {
        val p = Path().apply {
            moveTo(0f, 0f)
            lineTo(size.width, 0f)
            lineTo(size.width / 2, size.height)
            close()
        }
        drawPath(p, Palette.pink)
        drawPath(p, Color.White, style = Stroke(3f))
    }
}

