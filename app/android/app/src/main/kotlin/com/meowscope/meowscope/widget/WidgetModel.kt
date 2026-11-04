package com.meowscope.meowscope.widget

/**
 * ウィジェットの表示と、押したときの動きを決める（F-WG-01、Issue #80）。
 *
 * Android の仕組みに頼らない形にして、単体テストで確かめる。描くのは [RecordWidgetProvider]。
 * 渡される内容（[Snapshot]）は Dart の WidgetSnapshot が作る。
 */

/** 名前と ID。 */
data class Item(val id: String, val name: String)

/** Dart から渡される内容。 */
data class Snapshot(
    val status: String,
    val message: String?,
    val buttons: List<Item>,
    val pages: List<List<Item>>,
    val onlyCat: Item?,
)

/** 今の表示。mode は buttons・cats・busy・done。until を過ぎたらボタンに戻す。 */
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
        const val BUSY = "busy"
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

/** 枠の1つ。action が null なら押せない。 */
data class Cell(val label: String, val action: Action?)

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
            Ui.BUSY -> Screen(message = "記録しています…")
            Ui.DONE -> Screen(message = shown.message)
            Ui.CATS -> catsScreen(snapshot, shown)
            else -> Screen(
                cells = List(4) { i ->
                    snapshot.buttons.getOrNull(i)?.let { Cell(it.name, Action.Button(i)) }
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
                page.getOrNull(0)?.let { Cell(it.name, Action.Cat(0)) },
                page.getOrNull(1)?.let { Cell(it.name, Action.Cat(1)) },
                next,
                Cell("やめる", Action.Cancel),
            ),
        )
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
                    Outcome(Ui(mode = Ui.BUSY), Record(type.id, only.id))
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
                    Outcome(Ui(mode = Ui.BUSY), Record(type.id, cat.id))
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
