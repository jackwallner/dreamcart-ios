package com.jackwallner.shop.ui.theme

import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.Immutable
import androidx.compose.runtime.staticCompositionLocalOf
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.jackwallner.shop.model.Rarity

/** `Theme.swift` tokens. */
object Palette {
    val violet = Color(0xFF7C3AED)
    val pink = Color(0xFFFF3D8B)
    val coral = Color(0xFFFF8A65)
    val gold = Color(0xFFF5B301)
    val goldLite = Color(0xFFFFD34E)
    val green = Color(0xFF22A45D)
    val red = Color(0xFFE5484D)

    val candy = Brush.linearGradient(listOf(violet, pink, coral), start = Offset.Zero, end = Offset.Infinite)
    val goldGradient = Brush.verticalGradient(listOf(goldLite, gold))

    fun rarity(r: Rarity): Color = when (r) {
        Rarity.COMMON -> Color(0xFF999999)
        Rarity.RARE -> Color(0xFF3D8CF2)
        Rarity.EPIC -> violet
        Rarity.LEGENDARY -> gold
    }

    fun hex(raw: String, fallback: Color = violet): Color =
        runCatching { Color(0xFF000000 or raw.removePrefix("#").toLong(16)) }.getOrDefault(fallback)
}

@Immutable
data class DCColors(
    val dark: Boolean,
    val bg: Color,
    val surface: Color,
    val ink: Color,
    val subtle: Color,
    val hairline: Color,
)

val LightColors = DCColors(false, Color(0xFFFBF9F6), Color.White, Color(0xFF17141C), Color(0xFF615E69), Color.Black.copy(alpha = 0.05f))
val DarkColors = DCColors(true, Color(0xFF0E0E12), Color(0xFF1C1C1C), Color(0xFFF5F5F5), Color(0xFF9E9E9E), Color.White.copy(alpha = 0.06f))

val LocalDC = staticCompositionLocalOf { LightColors }

object Radii {
    val corner = 22.dp
    val card = 18.dp
}

/** The iOS `Font.dc*` scale: serif display faces for headlines, rounded-weight system text below. */
object Type {
    private val serif = FontFamily.Serif
    val hero = TextStyle(fontFamily = serif, fontWeight = FontWeight.Bold, fontSize = 32.sp, lineHeight = 38.sp)
    val title = TextStyle(fontFamily = serif, fontWeight = FontWeight.Bold, fontSize = 27.sp, lineHeight = 33.sp)
    val section = TextStyle(fontFamily = serif, fontWeight = FontWeight.Bold, fontSize = 22.sp, lineHeight = 27.sp)
    val card = TextStyle(fontFamily = serif, fontWeight = FontWeight.Bold, fontSize = 20.sp, lineHeight = 25.sp)
    val item = TextStyle(fontFamily = serif, fontWeight = FontWeight.SemiBold, fontSize = 16.sp, lineHeight = 21.sp)
    val jumbo = TextStyle(fontWeight = FontWeight.Black, fontSize = 40.sp)
    val stat = TextStyle(fontWeight = FontWeight.Black, fontSize = 22.sp)
    val numeral = TextStyle(fontWeight = FontWeight.Black, fontSize = 16.sp)
    val price = TextStyle(fontWeight = FontWeight.Black, fontSize = 14.sp)
    val button = TextStyle(fontWeight = FontWeight.Bold, fontSize = 17.sp)
    val body = TextStyle(fontWeight = FontWeight.SemiBold, fontSize = 16.sp, lineHeight = 22.sp)
    val bodyText = TextStyle(fontWeight = FontWeight.Medium, fontSize = 16.sp, lineHeight = 23.sp)
    val sub = TextStyle(fontWeight = FontWeight.Medium, fontSize = 14.sp, lineHeight = 19.sp)
    val label = TextStyle(fontWeight = FontWeight.Bold, fontSize = 14.sp)
    val caption = TextStyle(fontWeight = FontWeight.Medium, fontSize = 12.sp, lineHeight = 16.sp)
    val overline = TextStyle(fontWeight = FontWeight.Black, fontSize = 12.sp, letterSpacing = 0.6.sp)
    val badge = TextStyle(fontWeight = FontWeight.Black, fontSize = 10.sp, letterSpacing = 0.4.sp)
}

@Composable
fun DreamCartTheme(dark: Boolean, content: @Composable () -> Unit) {
    val dc = if (dark) DarkColors else LightColors
    val scheme = if (dark) {
        darkColorScheme(primary = Palette.violet, secondary = Palette.pink, background = dc.bg, surface = dc.surface, onSurface = dc.ink, onBackground = dc.ink)
    } else {
        lightColorScheme(primary = Palette.violet, secondary = Palette.pink, background = dc.bg, surface = dc.surface, onSurface = dc.ink, onBackground = dc.ink)
    }
    CompositionLocalProvider(LocalDC provides dc) {
        MaterialTheme(colorScheme = scheme, content = content)
    }
}
