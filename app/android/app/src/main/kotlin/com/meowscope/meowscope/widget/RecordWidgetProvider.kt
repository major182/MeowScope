package com.meowscope.meowscope.widget

import android.app.AlarmManager
import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import android.util.TypedValue
import android.view.View
import android.widget.RemoteViews
import com.meowscope.meowscope.MainActivity
import com.meowscope.meowscope.R
import es.antonborri.home_widget.HomeWidgetBackgroundIntent
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetPlugin
import es.antonborri.home_widget.HomeWidgetProvider
import org.json.JSONArray
import org.json.JSONObject

/**
 * 記録のウィジェット（F-WG-01）。表示と動きは [WidgetModel] が決め、ここでは描くことと受け取ることだけをする。
 *
 * ボタン・「次へ」・「やめる」は、ここですぐに表示を切り替える。記録は Dart の裏側の処理
 * （widgetBackgroundCallback）に `meowscope://widget/record?type=...&cat=...` で頼む。
 */
class RecordWidgetProvider : HomeWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        val screen = WidgetModel.screen(snapshot(widgetData), ui(widgetData), System.currentTimeMillis())
        for (id in appWidgetIds) {
            appWidgetManager.updateAppWidget(id, views(context, screen))
        }
    }

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == ACTION_TAP) {
            parseAction(intent.data)?.let { apply(context, it) }
        } else {
            super.onReceive(context, intent)
        }
        armExpire(context)
    }

    private fun apply(context: Context, action: Action) {
        val prefs = HomeWidgetPlugin.getData(context)
        val now = System.currentTimeMillis()
        val outcome = WidgetModel.onAction(snapshot(prefs), ui(prefs), action, now)
        val edit = prefs.edit().putString(KEY_UI, uiJson(outcome.ui))
        // 記録待ちの印。Dart が保存を終えたら消す。残ったままなら失敗を出す
        if (outcome.record != null) {
            edit.putLong(KEY_PENDING, now)
        } else {
            WidgetModel.overdue(pendingSince(prefs), now)?.let {
                edit.putString(KEY_UI, uiJson(it)).remove(KEY_PENDING)
            }
        }
        edit.apply()
        outcome.record?.let {
            val uri = Uri.parse("meowscope://widget/record?type=${Uri.encode(it.typeId)}&cat=${Uri.encode(it.catId)}")
            HomeWidgetBackgroundIntent.getBroadcast(context, uri).send()
        }
        redraw(context)
    }

    private fun redraw(context: Context) {
        val manager = AppWidgetManager.getInstance(context)
        val ids = manager.getAppWidgetIds(ComponentName(context, RecordWidgetProvider::class.java))
        onUpdate(context, manager, ids, HomeWidgetPlugin.getData(context))
    }

    /**
     * 期限のある表示（猫の選択・記録の結果）を、期限ちょうどにボタンへ戻す。
     *
     * 結果は Dart の裏側の処理が書くが、その処理は書いた後すぐに止められるので、戻すのはこちらで行う。
     * アラームは OS がまとめて遅らせる（1分ほど）ため、アプリの中のタイマーで戻す。
     * 受け取りの処理を延ばす（goAsync）と、その間は次に押した知らせが待たされて反応が数秒遅れるので使わない。
     * アプリが凍結されてタイマーが止まったときのために、アラームも予備として掛けておく
     */
    private fun armExpire(context: Context) {
        val now = System.currentTimeMillis()
        val prefs = HomeWidgetPlugin.getData(context)
        val until = listOfNotNull(
            ui(prefs).until,
            pendingSince(prefs)?.plus(WidgetModel.SAVE_TIMEOUT_MS),
        ).filter { it > now }.minOrNull() ?: return
        scheduleExpire(context, until - now)
        val app = context.applicationContext
        timer.removeCallbacksAndMessages(null)
        timer.postDelayed({
            apply(app, Action.Expire)
            // 失敗の文に変わったときなど、次の期限を掛け直す
            armExpire(app)
        }, until - now)
    }

    /** 選ばずに放っておかれたら、期限で描き直してボタンに戻す。 */
    private fun scheduleExpire(context: Context, delayMs: Long) {
        val alarms = context.getSystemService(AlarmManager::class.java) ?: return
        alarms.set(
            AlarmManager.ELAPSED_REALTIME,
            SystemClock.elapsedRealtime() + delayMs.coerceAtLeast(0),
            tap(context, "expire"),
        )
    }

    private fun views(context: Context, screen: Screen): RemoteViews {
        val v = RemoteViews(context.packageName, R.layout.widget_record)
        val showMessage = screen.message != null
        v.setViewVisibility(R.id.widget_message, if (showMessage) View.VISIBLE else View.GONE)
        v.setViewVisibility(R.id.widget_grid, if (showMessage) View.GONE else View.VISIBLE)
        v.setTextViewText(R.id.widget_message, screen.message ?: "")
        v.setViewVisibility(R.id.widget_title, if (screen.title != null) View.VISIBLE else View.GONE)
        v.setTextViewText(R.id.widget_title, screen.title ?: "")
        // アプリを開くときは、受け取り口を通さずに直接開く（Android 12 からは裏側から画面を開けない）
        val open = HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java)
        for ((i, cellId) in CELLS.withIndex()) {
            val cell = screen.cells.getOrNull(i)
            v.setViewVisibility(cellId, if (cell == null) View.INVISIBLE else View.VISIBLE)
            v.setTextViewText(LABELS[i], cell?.label ?: "")
            val icon = cell?.icon?.let { loadIcon(context, it) }
            v.setViewVisibility(ICONS[i], if (icon == null) View.GONE else View.VISIBLE)
            icon?.let { v.setImageViewBitmap(ICONS[i], it) }
            // イラストのない枠（次へ・やめる）は、文字を大きくして枠の真ん中に出す
            v.setTextViewTextSize(LABELS[i], TypedValue.COMPLEX_UNIT_SP, if (icon == null) 15f else 13f)
            val click = when {
                cell == null -> null
                screen.openApp -> open
                else -> cell.action?.let { tap(context, actionPath(it)) }
            }
            v.setOnClickPendingIntent(cellId, click)
        }
        // 空いている所を押しても何もしない。押し先がないと、ランチャーがアプリを開いてしまう（意図しない動き）
        val ignore = tap(context, "none")
        v.setOnClickPendingIntent(R.id.widget_root, ignore)
        v.setOnClickPendingIntent(R.id.widget_message, if (screen.openApp) open else ignore)
        return v
    }

    private fun tap(context: Context, path: String): PendingIntent {
        val intent = Intent(context, RecordWidgetProvider::class.java)
            .setAction(ACTION_TAP)
            .setData(Uri.parse("meowscope://widget/$path"))
        return PendingIntent.getBroadcast(
            context,
            0,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }

    companion object {
        // 使うときに作る（単体テストでは Android の Looper がないため）
        private val timer by lazy { Handler(Looper.getMainLooper()) }
        const val ACTION_TAP = "com.meowscope.meowscope.widget.TAP"
        const val KEY_SNAPSHOT = "meowscope.snapshot"
        const val KEY_UI = "meowscope.ui"
        const val KEY_PENDING = "meowscope.pending"
        private val CELLS = intArrayOf(R.id.widget_cell0, R.id.widget_cell1, R.id.widget_cell2, R.id.widget_cell3)
        private val ICONS =
            intArrayOf(R.id.widget_cell0_icon, R.id.widget_cell1_icon, R.id.widget_cell2_icon, R.id.widget_cell3_icon)
        private val LABELS =
            intArrayOf(R.id.widget_cell0_label, R.id.widget_cell1_label, R.id.widget_cell2_label, R.id.widget_cell3_label)

        /** 枠に出すイラストの大きさ（px）。元の画像（512px）のままだとウィジェットに渡せる量を超えるので縮める。 */
        private const val ICON_PX = 160
        private val iconCache = HashMap<String, Bitmap?>()

        /**
         * アプリのイラスト（Flutter の assets/icons）を読む。アプリの中の flutter_assets にあるので、画像を二重に持たない。
         * 読めなければ null（文字だけで出す）
         */
        private fun loadIcon(context: Context, path: String): Bitmap? = iconCache.getOrPut(path) {
            try {
                context.assets.open("flutter_assets/$path").use { input ->
                    BitmapFactory.decodeStream(input)?.let { Bitmap.createScaledBitmap(it, ICON_PX, ICON_PX, true) }
                }
            } catch (e: java.io.IOException) {
                null
            }
        }

        fun actionPath(action: Action): String = when (action) {
            is Action.Button -> "button/${action.index}"
            is Action.Cat -> "cat/${action.index}"
            Action.Next -> "next"
            Action.Cancel -> "cancel"
            Action.Expire -> "expire"
        }

        fun parseAction(uri: Uri?): Action? = uri?.pathSegments?.let(::parsePath)

        fun parsePath(segments: List<String>): Action? {
            val index = segments.getOrNull(1)?.toIntOrNull()
            return when (segments.firstOrNull()) {
                "button" -> index?.let { Action.Button(it) }
                "cat" -> index?.let { Action.Cat(it) }
                "next" -> Action.Next
                "cancel" -> Action.Cancel
                "expire" -> Action.Expire
                else -> null
            }
        }

        private fun snapshot(prefs: SharedPreferences): Snapshot? {
            val text = prefs.getString(KEY_SNAPSHOT, null) ?: return null
            return try {
                val json = JSONObject(text)
                Snapshot(
                    status = json.getString("status"),
                    message = json.optString("message").takeIf { !json.isNull("message") },
                    buttons = items(json.getJSONArray("buttons")),
                    pages = json.getJSONArray("pages").let { pages -> List(pages.length()) { items(pages.getJSONArray(it)) } },
                    onlyCat = json.optJSONObject("onlyCat")?.let(::item),
                )
            } catch (e: org.json.JSONException) {
                null
            }
        }

        private fun pendingSince(prefs: SharedPreferences): Long? =
            if (prefs.contains(KEY_PENDING)) prefs.getLong(KEY_PENDING, 0) else null

        private fun ui(prefs: SharedPreferences): Ui {
            val text = prefs.getString(KEY_UI, null) ?: return Ui()
            return try {
                val json = JSONObject(text)
                Ui(
                    mode = json.optString("mode", Ui.BUTTONS),
                    message = json.optString("message").takeIf { json.has("message") },
                    until = if (json.has("until")) json.getLong("until") else null,
                    type = json.optJSONObject("type")?.let(::item),
                    page = json.optInt("page", 0),
                )
            } catch (e: org.json.JSONException) {
                Ui()
            }
        }

        private fun uiJson(ui: Ui): String = JSONObject().apply {
            put("mode", ui.mode)
            ui.message?.let { put("message", it) }
            ui.until?.let { put("until", it) }
            ui.type?.let { put("type", JSONObject().put("id", it.id).put("name", it.name)) }
            put("page", ui.page)
        }.toString()

        private fun items(array: JSONArray): List<Item> = List(array.length()) { item(array.getJSONObject(it)) }

        private fun item(json: JSONObject) =
            Item(json.getString("id"), json.getString("name"), json.optString("icon").takeIf { it.isNotEmpty() })
    }
}
