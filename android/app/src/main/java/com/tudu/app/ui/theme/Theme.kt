package com.tudu.app.ui.theme

import android.os.Build
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.dynamicDarkColorScheme
import androidx.compose.material3.dynamicLightColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.Immutable
import androidx.compose.runtime.staticCompositionLocalOf
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext

private val Indigo = Color(0xFF4F5BD5)

private val LightColors = lightColorScheme(
    primary = Indigo,
    onPrimary = Color.White,
    primaryContainer = Color(0xFFE0E0FF),
    onPrimaryContainer = Color(0xFF00006E),
    secondary = Color(0xFF5C5D72),
    tertiary = Color(0xFF78536B),
)

private val DarkColors = darkColorScheme(
    primary = Color(0xFFBEC2FF),
    onPrimary = Color(0xFF1A2398),
    primaryContainer = Color(0xFF343EB3),
    onPrimaryContainer = Color(0xFFE0E0FF),
    secondary = Color(0xFFC5C4DD),
    tertiary = Color(0xFFE7B9D5),
)

/** Status colors that are not part of the Material scheme. */
@Immutable
data class TuduColors(val overdue: Color, val success: Color, val danger: Color, val high: Color)

val LocalTuduColors = staticCompositionLocalOf {
    TuduColors(Color(0xFFE8710A), Color(0xFF2E7D32), Color(0xFFC62828), Color(0xFFD32F2F))
}

@Composable
fun TuduTheme(darkTheme: Boolean = isSystemInDarkTheme(), content: @Composable () -> Unit) {
    val context = LocalContext.current
    val scheme = when {
        Build.VERSION.SDK_INT >= Build.VERSION_CODES.S ->
            if (darkTheme) dynamicDarkColorScheme(context) else dynamicLightColorScheme(context)
        darkTheme -> DarkColors
        else -> LightColors
    }
    val extra = if (darkTheme) {
        TuduColors(Color(0xFFFFA65C), Color(0xFF81C784), Color(0xFFEF9A9A), Color(0xFFFF8A80))
    } else {
        TuduColors(Color(0xFFE8710A), Color(0xFF2E7D32), Color(0xFFC62828), Color(0xFFD32F2F))
    }
    androidx.compose.runtime.CompositionLocalProvider(LocalTuduColors provides extra) {
        MaterialTheme(colorScheme = scheme, content = content)
    }
}
