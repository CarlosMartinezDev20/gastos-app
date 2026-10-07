package com.example.appgastos

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.RectF
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

/**
 * Home-screen widget. The app sends the texts already formatted (see
 * `lib/core/utils/phone_widget.dart`); this only lays them out with the
 * chosen colors and draws the week bars or the goal progress.
 */
class FinanceWidgetProvider : HomeWidgetProvider() {

  private data class Theme(val background: Int, val foreground: Int, val muted: Int, val highlight: Int)

  // Same values as PhoneWidgetTheme in Dart.
  private val themes = mapOf(
    "light" to Theme(0xFFFFFFFF.toInt(), 0xFF1C1C1E.toInt(), 0xFF64646D.toInt(), 0xFF8DBF1F.toInt()),
    "dark" to Theme(0xFF1C1C1E.toInt(), 0xFFF7F7F8.toInt(), 0xFFA1A1A8.toInt(), 0xFFC8F04B.toInt()),
    "lime" to Theme(0xFFC8F04B.toInt(), 0xFF1A2006.toInt(), 0xFF4A5A1C.toInt(), 0xFF1A2006.toInt()),
    "lilac" to Theme(0xFFE2DDFF.toInt(), 0xFF514578.toInt(), 0xFF7A6FA3.toInt(), 0xFF514578.toInt()),
  )

  override fun onUpdate(
    context: Context,
    appWidgetManager: AppWidgetManager,
    appWidgetIds: IntArray,
    widgetData: SharedPreferences,
  ) {
    val theme = themes[widgetData.getString("theme", null)] ?: themes.getValue("dark")
    val title = widgetData.getString("title", null) ?: "Finanzas"
    val amount = widgetData.getString("amount", null) ?: "—"
    val caption = widgetData.getString("caption", null) ?: "Abre la app para ver tus datos"
    val progress = widgetData.getInt("progress", -1)
    val bars = widgetData.getString("bars", null)
      ?.split(',')
      ?.mapNotNull { it.toFloatOrNull() }
      .orEmpty()

    val chart = when {
      progress >= 0 -> progressBitmap(progress / 100f, theme)
      bars.isNotEmpty() -> barsBitmap(bars, theme)
      else -> null
    }

    for (id in appWidgetIds) {
      val views = RemoteViews(context.packageName, R.layout.widget_finance).apply {
        setInt(R.id.widget_background, "setColorFilter", theme.background)
        setTextViewText(R.id.widget_title, title)
        setTextColor(R.id.widget_title, theme.muted)
        setInt(R.id.widget_icon, "setColorFilter", theme.foreground)
        setTextViewText(R.id.widget_amount, amount)
        setTextColor(R.id.widget_amount, theme.foreground)
        setTextViewText(R.id.widget_caption, caption)
        setTextColor(R.id.widget_caption, theme.muted)
        if (chart != null) {
          setImageViewBitmap(R.id.widget_chart, chart)
          setViewVisibility(R.id.widget_chart, View.VISIBLE)
        } else {
          setViewVisibility(R.id.widget_chart, View.GONE)
        }
        setOnClickPendingIntent(
          R.id.widget_root,
          HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java),
        )
      }
      appWidgetManager.updateAppWidget(id, views)
    }
  }

  private fun withAlpha(color: Int, alpha: Float) =
    Color.argb((alpha * 255).toInt(), Color.red(color), Color.green(color), Color.blue(color))

  /** Seven rounded bars; the last one (today) in the highlight color. */
  private fun barsBitmap(bars: List<Float>, theme: Theme): Bitmap {
    val width = 420
    val height = 90
    val bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
    val canvas = Canvas(bitmap)
    val paint = Paint(Paint.ANTI_ALIAS_FLAG)
    val gap = 12f
    val barWidth = (width - gap * (bars.size - 1)) / bars.size
    bars.forEachIndexed { i, value ->
      val h = height * value.coerceIn(0.1f, 1f)
      val left = i * (barWidth + gap)
      paint.color = if (i == bars.lastIndex) theme.highlight else withAlpha(theme.foreground, .22f)
      canvas.drawRoundRect(RectF(left, height - h, left + barWidth, height.toFloat()), 10f, 10f, paint)
    }
    return bitmap
  }

  private fun progressBitmap(progress: Float, theme: Theme): Bitmap {
    val width = 420
    val height = 20
    val bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
    val canvas = Canvas(bitmap)
    val paint = Paint(Paint.ANTI_ALIAS_FLAG)
    val radius = height / 2f
    paint.color = withAlpha(theme.foreground, .12f)
    canvas.drawRoundRect(RectF(0f, 0f, width.toFloat(), height.toFloat()), radius, radius, paint)
    val filled = width * progress.coerceIn(0f, 1f)
    if (filled > 0) {
      paint.color = theme.highlight
      canvas.drawRoundRect(RectF(0f, 0f, maxOf(filled, height.toFloat()), height.toFloat()), radius, radius, paint)
    }
    return bitmap
  }
}
