package com.meowscope.meowscope.widget

/**
 * ウィジェットの表示と、押したときの動きを決める（F-WG-01、Issue #80）。
 *
 * Android の仕組みに頼らない形にして、単体テストで確かめる。描くのは [RecordWidgetProvider]。
 * 渡される内容（[Snapshot]）は Dart の WidgetSnapshot が作る。
 */

/** 名前と ID。 */
data class Item(val id: String, val name: String, val icon: String? = null)

/** Dart から渡される内容。 */
data class Snapshot(
    val status: String,
    val message: String?,
    val buttons: List<Item>,
    val pages: List<List<Item>>,
    val onlyCat: Item?,
)

/** 今の表示。mode は buttons・cats・done。until を過ぎたらボタンに戻す。 */
data class Ui(
    val mode: String = BUTTONS,
    val message: String? = null,
    val until: Long? = null,
    val type: Item? = null,
    val page: Int = 0,
) {
    companion object {
        const val BUTTONS = "buttons"
        const val CATS = "cats"
        const val DONE = "done"
    }
}

/** 押したときの動き。 */
sealed interface Action {
    data class Button(val index: Int) : Action
    data class Cat(val index: Int) : Action
    data object Next : Action
    data object Cancel : Action
    data object Expire : Action
}

/** 枠の1つ。action が null なら押せない。icon はアプリのイラストの場所（なければ文字だけ）。 */
data class Cell(val label: String, val action: Action?, val icon: String? = null)

/** 描く内容。message があれば枠の代わりに出す。openApp なら、押すとアプリを開く。 */
data class Screen(
    val title: String? = null,
    val message: String? = null,
    val cells: List<Cell?> = List(4) { null },
    val openApp: Boolean = false,
)

/** 押した結果、Dart の側で記録する内容。 */
data class Record(val typeId: String, val catId: String)

/** 押した後の表示と、記録するもの。 */
data class Outcome(val ui: Ui, val record: Record? = null)

object WidgetModel {
    /** 選ばずに放っておいたら、ボタンに戻すまでの時間。 */
    const val SELECT_TIMEOUT_MS = 15_000L

    /** 記録の結果を出す時間。 */
    const val DONE_MS = 2_000L

    /**
     * 保存が終わらなければ、失敗として扱うまでの時間（アプリの更新の直後など、裏側の処理が動かないとき）。
     * 結果は押した時点で先に出すので、保存の終わりは別の印（記録待ち）で見る
     */
    const val SAVE_TIMEOUT_MS = 10_000L

    /** 失敗の文を出す時間。 */
    const val FAILED_MS = 3_000L

    const val FAILED_MESSAGE = "記録できませんでした。アプリを開いてください"

    private const val READY = "ready"
    private const val NO_CATS = "noCats"

    /** 期限を過ぎていたら、ボタンの表示として扱う。 */
    fun current(ui: Ui, now: Long): Ui = if (ui.until != null && now >= ui.until) Ui() else ui

    fun screen(snapshot: Snapshot?, ui: Ui, now: Long): Screen {
        if (snapshot == null) {
            return Screen(message = "MeowScope を開いてください", openApp = true)
        }
        if (snapshot.status != READY && snapshot.status != NO_CATS) {
            return Screen(message = snapshot.message, openApp = true)
        }
        val shown = current(ui, now)
        return when (shown.mode) {
            Ui.DONE -> Screen(message = shown.message)
            Ui.CATS -> catsScreen(snapshot, shown)
            else -> Screen(
                cells = List(4) { i ->
                    snapshot.buttons.getOrNull(i)?.let { Cell(it.name, Action.Button(i), it.icon) }
                },
                // 猫がいなければ、ボタンを押すとアプリを開き、ホームで猫の登録を促す
                openApp = snapshot.status == NO_CATS,
            )
        }
    }

    private fun catsScreen(snapshot: Snapshot, ui: Ui): Screen {
        val page = snapshot.pages.getOrNull(ui.page) ?: return screen(snapshot, Ui(), 0)
        val next = if (snapshot.pages.size > 1) Cell("次へ ▶", Action.Next) else null
        return Screen(
            title = "${ui.type?.name}：どの子？",
            cells = listOf(
                page.getOrNull(0)?.let { Cell(it.name, Action.Cat(0), it.icon) },
                page.getOrNull(1)?.let { Cell(it.name, Action.Cat(1), it.icon) },
                next,
                Cell("やめる", Action.Cancel),
            ),
        )
    }

    /**
     * 記録を頼み、保存を待たずに結果を出す（待ちを感じさせないため。Issue #80 で決定）。
     * 保存できなかったときは、Dart の側が失敗の文に書き換える
     */
    private fun recorded(type: Item, cat: Item, now: Long) = Outcome(
        Ui(mode = Ui.DONE, message = "✓ ${cat.name}の${type.name}を記録しました", until = now + DONE_MS),
        Record(type.id, cat.id),
    )

    /** 記録待ちの印が [SAVE_TIMEOUT_MS] を過ぎても残っていたら、失敗の表示を返す。 */
    fun overdue(pendingSince: Long?, now: Long): Ui? =
        if (pendingSince != null && now >= pendingSince + SAVE_TIMEOUT_MS) {
            Ui(mode = Ui.DONE, message = FAILED_MESSAGE, until = now + FAILED_MS)
        } else {
            null
        }

    fun onAction(snapshot: Snapshot?, ui: Ui, action: Action, now: Long): Outcome {
        val shown = current(ui, now)
        if (snapshot == null || snapshot.status != READY) {
            // 記録できない状態では、枠を押すと直接アプリが開く（[Screen.openApp]）。ここでは何もしない
            return Outcome(Ui())
        }
        return when (action) {
            is Action.Button -> {
                val type = snapshot.buttons.getOrNull(action.index) ?: return Outcome(Ui())
                val only = snapshot.onlyCat
                if (only != null) {
                    // 猫が1匹なら選ばずに記録する（BR-23）
                    recorded(type, only, now)
                } else {
                    Outcome(Ui(mode = Ui.CATS, type = type, until = now + SELECT_TIMEOUT_MS))
                }
            }
            is Action.Cat -> {
                val cat = snapshot.pages.getOrNull(shown.page)?.getOrNull(action.index)
                val type = shown.type
                if (shown.mode != Ui.CATS || cat == null || type == null) {
                    Outcome(Ui())
                } else {
                    recorded(type, cat, now)
                }
            }
            Action.Next -> if (shown.mode != Ui.CATS || snapshot.pages.isEmpty()) {
                Outcome(Ui())
            } else {
                // 最後のページの次は最初に戻る
                Outcome(shown.copy(page = (shown.page + 1) % snapshot.pages.size, until = now + SELECT_TIMEOUT_MS))
            }
            Action.Cancel -> Outcome(Ui())
            // 期限の知らせ。期限を過ぎていれば current でボタンに戻っている
            Action.Expire -> Outcome(shown)
        }
    }
}
