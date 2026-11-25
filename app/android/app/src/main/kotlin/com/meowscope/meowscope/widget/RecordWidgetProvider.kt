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
 * （widgetBackgroundCallback）に `meowscope://widget/record?type=...&cat=...&widget=...` で頼む。
 *
 * おうちごとに置けるよう（BR-40）、表示・記録待ちの印・どのおうちかは、ウィジェットごと（appWidgetId）に持つ。
 * 押したときの道筋にも、どのウィジェットかを入れる（`meowscope://widget/<appWidgetId>/button/0` など）
 */
class RecordWidgetProvider : HomeWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        val state = state(widgetData)
        val now = System.currentTimeMillis()
        for (id in appWidgetIds) {
            val screen = WidgetModel.screen(state, widgetData.getString(keyHousehold(id), null), ui(widgetData, id), now)
            appWidgetManager.updateAppWidget(id, views(context, id, screen))
        }
    }

    /** ウィジェットを外したら、そのウィジェットの分（表示・記録待ちの印・おうち）を消す。 */
    override fun onDeleted(context: Context, appWidgetIds: IntArray) {
        val edit = HomeWidgetPlugin.getData(context).edit()
        for (id in appWidgetIds) {
            edit.remove(keyUi(id)).remove(keyPending(id)).remove(keyHousehold(id))
        }
        edit.apply()
        super.onDeleted(context, appWidgetIds)
    }

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == ACTION_TAP) {
            parseTap(intent.data)?.let { (widgetId, action) ->
                if (widgetId == EXPIRE_ALL) {
                    // 予備のアラーム：すべてのウィジェットの期限を確かめる
                    for (id in widgetIds(context)) {
                        apply(context, id, Action.Expire)
                    }
                } else {
                    apply(context, widgetId, action)
                }
            }
        } else {
            super.onReceive(context, intent)
        }
        armExpire(context)
    }

    private fun apply(context: Context, widgetId: Int, action: Action) {
        val prefs = HomeWidgetPlugin.getData(context)
        val now = System.currentTimeMillis()
        val assigned = prefs.getString(keyHousehold(widgetId), null)
        val outcome = WidgetModel.onAction(state(prefs), assigned, ui(prefs, widgetId), action, now)
        val edit = prefs.edit().putString(keyUi(widgetId), uiJson(outcome.ui))
        // おうちを選んだら、このウィジェットのおうちとして覚える
        outcome.assign?.let { edit.putString(keyHousehold(widgetId), it) }
        // 記録待ちの印。Dart が保存を終えたら消す。残ったままなら失敗を出す
        if (outcome.record != null) {
            edit.putLong(keyPending(widgetId), now)
        } else {
            WidgetModel.overdue(pendingSince(prefs, widgetId), now)?.let {
                edit.putString(keyUi(widgetId), uiJson(it)).remove(keyPending(widgetId))
            }
        }
        edit.apply()
        outcome.record?.let {
            val uri = Uri.parse(
                "meowscope://widget/record?type=${Uri.encode(it.typeId)}&cat=${Uri.encode(it.catId)}&widget=$widgetId",
            )
            HomeWidgetBackgroundIntent.getBroadcast(context, uri).send()
        }
        redraw(context)
    }

    private fun widgetIds(context: Context): IntArray =
        AppWidgetManager.getInstance(context).getAppWidgetIds(ComponentName(context, RecordWidgetProvider::class.java))

    private fun redraw(context: Context) {
        onUpdate(context, AppWidgetManager.getInstance(context), widgetIds(context), HomeWidgetPlugin.getData(context))
    }

    /**
     * 期限のある表示（猫の選択・記録の結果）を、期限ちょうどにボタンへ戻す。
     *
     * 結果は Dart の裏側の処理が書くが、その処理は書いた後すぐに止められるので、戻すのはこちらで行う。
     * アラームは OS がまとめて遅らせる（1分ほど）ため、アプリの中のタイマーで戻す。
     * 受け取りの処理を延ばす（goAsync）と、その間は次に押した知らせが待たされて反応が数秒遅れるので使わない。
     * アプリが凍結されてタイマーが止まったときのために、アラームも予備として掛けておく。
     * ウィジェットが2つ以上あるときは、いちばん早い期限で掛け、期限が来たらすべてのウィジェットを確かめる
     */
    private fun armExpire(context: Context) {
        val now = System.currentTimeMillis()
        val prefs = HomeWidgetPlugin.getData(context)
        val ids = widgetIds(context)
        val until = ids.flatMap { id ->
            listOfNotNull(ui(prefs, id).until, pendingSince(prefs, id)?.plus(WidgetModel.SAVE_TIMEOUT_MS))
        }.filter { it > now }.minOrNull() ?: return
        scheduleExpire(context, until - now)
        val app = context.applicationContext
        timer.removeCallbacksAndMessages(null)
        timer.postDelayed({
            for (id in widgetIds(app)) {
                apply(app, id, Action.Expire)
            }
            // 失敗の文に変わったときなど、次の期限を掛け直す
            armExpire(app)
        }, until - now)
    }

    /**
     * 選ばずに放っておかれたら、期限で描き直してボタンに戻す。
     * 端末が省電力（Doze）に入っても後回しにされないよう、AllowWhileIdle で掛ける（Issue #93）
     */
    private fun scheduleExpire(context: Context, delayMs: Long) {
        val alarms = context.getSystemService(AlarmManager::class.java) ?: return
        alarms.setAndAllowWhileIdle(
            AlarmManager.ELAPSED_REALTIME,
            SystemClock.elapsedRealtime() + delayMs.coerceAtLeast(0),
            tap(context, EXPIRE_ALL, "expire"),
        )
    }

    private fun views(context: Context, widgetId: Int, screen: Screen): RemoteViews {
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
            // イラストのない枠（次へ・やめる・おうち）は、文字を大きくして枠の真ん中に出す
            v.setTextViewTextSize(LABELS[i], TypedValue.COMPLEX_UNIT_SP, if (icon == null) 15f else 13f)
            val click = when {
                cell == null -> null
                screen.openApp -> open
                else -> cell.action?.let { tap(context, widgetId, actionPath(it)) }
            }
            v.setOnClickPendingIntent(cellId, click)
        }
        // 空いている所を押しても何もしない。押し先がないと、ランチャーがアプリを開いてしまう（意図しない動き）
        val ignore = tap(context, widgetId, "none")
        v.setOnClickPendingIntent(R.id.widget_root, ignore)
        v.setOnClickPendingIntent(R.id.widget_message, if (screen.openApp) open else ignore)
        return v
    }

    /** 押したときの知らせ。道筋（data）がウィジェットと枠ごとに違うので、知らせは別々のものになる。 */
    private fun tap(context: Context, widgetId: Int, path: String): PendingIntent {
        val intent = Intent(context, RecordWidgetProvider::class.java)
            .setAction(ACTION_TAP)
            .setData(Uri.parse("meowscope://widget/$widgetId/$path"))
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

        /** 予備のアラームの知らせ。どのウィジェットのものでもないので、期限を過ぎたすべてのウィジェットを確かめる。 */
        private const val EXPIRE_ALL = -1

        /** ウィジェットごとの表示（Dart の WidgetKeys.ui と同じ）。 */
        fun keyUi(widgetId: Int) = "meowscope.ui.$widgetId"

        /** ウィジェットごとの記録待ちの印（Dart の WidgetKeys.pending と同じ）。 */
        fun keyPending(widgetId: Int) = "meowscope.pending.$widgetId"

        /** ウィジェットごとのおうち（BR-40）。Android の側だけで持つ。 */
        fun keyHousehold(widgetId: Int) = "meowscope.household.$widgetId"

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
            is Action.Household -> "household/${action.index}"
            Action.Next -> "next"
            Action.Cancel -> "cancel"
            Action.Expire -> "expire"
        }

        /**
         * 押したときの道筋から、どのウィジェットの何を押したかを読む。
         * 予備のアラームは、ウィジェットの番号の代わりに [EXPIRE_ALL] が入る
         */
        fun parseTap(uri: Uri?): Pair<Int, Action>? = uri?.pathSegments?.let(::parseTapPath)

        fun parseTapPath(segments: List<String>): Pair<Int, Action>? {
            val widgetId = segments.firstOrNull()?.toIntOrNull() ?: return null
            return parsePath(segments.drop(1))?.let { widgetId to it }
        }

        fun parsePath(segments: List<String>): Action? {
            val index = segments.getOrNull(1)?.toIntOrNull()
            return when (segments.firstOrNull()) {
                "button" -> index?.let { Action.Button(it) }
                "cat" -> index?.let { Action.Cat(it) }
                "household" -> index?.let { Action.Household(it) }
                "next" -> Action.Next
                "cancel" -> Action.Cancel
                "expire" -> Action.Expire
                else -> null
            }
        }

        /** Dart の WidgetState の JSON を読む。古い形や壊れた内容なら null（アプリを開いてもらう）。 */
        fun parseState(text: String?): WidgetState? {
            if (text == null) {
                return null
            }
            return try {
                val json = JSONObject(text)
                val households = json.getJSONArray("households")
                WidgetState(
                    status = json.getString("status"),
                    message = json.optString("message").takeIf { !json.isNull("message") },
                    households = List(households.length()) { i ->
                        val h = households.getJSONObject(i)
                        HouseholdSnapshot(h.getString("id"), h.getString("name"), snapshot(h.getJSONObject("snapshot")))
                    },
                )
            } catch (e: org.json.JSONException) {
                null
            }
        }

        private fun state(prefs: SharedPreferences): WidgetState? = parseState(prefs.getString(KEY_SNAPSHOT, null))

        private fun snapshot(json: JSONObject) = Snapshot(
            status = json.getString("status"),
            message = json.optString("message").takeIf { !json.isNull("message") },
            buttons = items(json.getJSONArray("buttons")),
            pages = json.getJSONArray("pages").let { pages -> List(pages.length()) { items(pages.getJSONArray(it)) } },
            onlyCat = json.optJSONObject("onlyCat")?.let(::item),
        )

        private fun pendingSince(prefs: SharedPreferences, widgetId: Int): Long? =
            if (prefs.contains(keyPending(widgetId))) prefs.getLong(keyPending(widgetId), 0) else null

        private fun ui(prefs: SharedPreferences, widgetId: Int): Ui {
            val text = prefs.getString(keyUi(widgetId), null) ?: return Ui()
            return try {
                val json = JSONObject(text)
                Ui(
                    mode = json.optString("mode", Ui.BUTTONS),
                    message = json.optString("message").takeIf { json.has("message") },
                    until = if (json.has("until")) json.getLong("until") else null,
                    type = json.optJSONObject("type")?.let(::item),
                    page = json.optInt("page", 0),
                    rev = if (json.has("rev")) json.getInt("rev") else null,
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
            ui.rev?.let { put("rev", it) }
        }.toString()

        private fun items(array: JSONArray): List<Item> = List(array.length()) { item(array.getJSONObject(it)) }

        private fun item(json: JSONObject) =
            Item(json.getString("id"), json.getString("name"), json.optString("icon").takeIf { it.isNotEmpty() })
    }
}
