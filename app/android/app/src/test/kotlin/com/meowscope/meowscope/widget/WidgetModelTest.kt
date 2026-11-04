package com.meowscope.meowscope.widget

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/** ウィジェットの表示と動き（テスト仕様書 UT-WG）。 */
class WidgetModelTest {
    private val food = Item("t1", "ご飯")
    private val water = Item("t2", "水")
    private val mike = Item("c1", "ミケ")
    private val tama = Item("c2", "タマ")
    private val kuro = Item("c3", "クロ")
    private val now = 1_000_000L

    private fun ready(vararg cats: Item) = Snapshot(
        status = "ready",
        message = null,
        buttons = listOf(food, water),
        pages = if (cats.size <= 1) emptyList() else cats.toList().chunked(2),
        onlyCat = cats.singleOrNull(),
    )

    private fun labels(screen: Screen) = screen.cells.map { it?.label }

    @Test
    fun `UT-WG-01 ボタンの表示：登録した順に4つの枠へ出し、足りない枠は空ける`() {
        val screen = WidgetModel.screen(ready(mike, tama), Ui(), now)
        assertEquals(listOf("ご飯", "水", null, null), labels(screen))
        assertNull(screen.title)
        assertEquals(false, screen.openApp)
    }

    @Test
    fun `UT-WG-02 猫が1匹なら、選ばずにその猫で記録を頼み、記録中を出す（BR-23）`() {
        val out = WidgetModel.onAction(ready(mike), Ui(), Action.Button(0), now)
        assertEquals(Record("t1", "c1"), out.record)
        assertEquals("記録しています…", WidgetModel.screen(ready(mike), out.ui, now).message)
    }

    @Test
    fun `UT-WG-03 猫が2匹なら、見出しと猫2匹とやめるを出す。次へは出さない`() {
        val out = WidgetModel.onAction(ready(mike, tama), Ui(), Action.Button(1), now)
        assertNull(out.record)
        val screen = WidgetModel.screen(ready(mike, tama), out.ui, now)
        assertEquals("水：どの子？", screen.title)
        assertEquals(listOf("ミケ", "タマ", null, "やめる"), labels(screen))

        val chosen = WidgetModel.onAction(ready(mike, tama), out.ui, Action.Cat(1), now)
        assertEquals(Record("t2", "c2"), chosen.record)
    }

    @Test
    fun `UT-WG-04 猫が3匹ならページ送り。次へで2ページ目、最後の次は最初に戻る`() {
        val s = ready(mike, tama, kuro)
        var ui = WidgetModel.onAction(s, Ui(), Action.Button(0), now).ui
        assertEquals(listOf("ミケ", "タマ", "次へ ▶", "やめる"), labels(WidgetModel.screen(s, ui, now)))

        ui = WidgetModel.onAction(s, ui, Action.Next, now).ui
        assertEquals(listOf("クロ", null, "次へ ▶", "やめる"), labels(WidgetModel.screen(s, ui, now)))
        assertEquals(Record("t1", "c3"), WidgetModel.onAction(s, ui, Action.Cat(0), now).record)
        // 2ページ目にない2つ目の猫は押せない（記録しない）
        assertNull(WidgetModel.onAction(s, ui, Action.Cat(1), now).record)

        ui = WidgetModel.onAction(s, ui, Action.Next, now).ui
        assertEquals(0, ui.page)
    }

    @Test
    fun `UT-WG-05 やめるでボタンに戻り、記録しない`() {
        val s = ready(mike, tama)
        val ui = WidgetModel.onAction(s, Ui(), Action.Button(0), now).ui
        val out = WidgetModel.onAction(s, ui, Action.Cancel, now)
        assertNull(out.record)
        assertEquals(Ui(), out.ui)
    }

    @Test
    fun `UT-WG-06 境界値：選択は15秒で期限切れ。直前は選択のまま、ちょうどでボタンに戻る。次へで延びる`() {
        val s = ready(mike, tama, kuro)
        val ui = WidgetModel.onAction(s, Ui(), Action.Button(0), now).ui
        val limit = now + WidgetModel.SELECT_TIMEOUT_MS
        assertEquals(Ui.CATS, WidgetModel.onAction(s, ui, Action.Expire, limit - 1).ui.mode)
        assertEquals(Ui.BUTTONS, WidgetModel.onAction(s, ui, Action.Expire, limit).ui.mode)
        // 期限を過ぎた選択の猫を押しても記録しない
        assertNull(WidgetModel.onAction(s, ui, Action.Cat(0), limit).record)

        val later = WidgetModel.onAction(s, ui, Action.Next, now + 10_000).ui
        assertEquals(now + 10_000 + WidgetModel.SELECT_TIMEOUT_MS, later.until)
    }

    @Test
    fun `UT-WG-07 記録の結果を期限まで出し、過ぎたらボタンに戻す`() {
        val done = Ui(mode = Ui.DONE, message = "✓ ミケのご飯を記録しました", until = now + 2_000)
        assertEquals("✓ ミケのご飯を記録しました", WidgetModel.screen(ready(mike), done, now).message)
        assertNull(WidgetModel.screen(ready(mike), done, now + 2_000).message)
    }

    @Test
    fun `UT-WG-08 記録できない状態：案内を出して押すとアプリを開く。猫がいなければボタンを押すとアプリを開く`() {
        for (snapshot in listOf(null, Snapshot("needsApp", "MeowScope を開いてください", emptyList(), emptyList(), null))) {
            val screen = WidgetModel.screen(snapshot, Ui(), now)
            assertEquals("MeowScope を開いてください", screen.message)
            assertTrue(screen.openApp)
        }
        val noCats = Snapshot("noCats", "先に猫を登録してください", listOf(food), emptyList(), null)
        val screen = WidgetModel.screen(noCats, Ui(), now)
        assertEquals(listOf("ご飯", null, null, null), labels(screen))
        assertTrue(screen.openApp)
        assertNull(WidgetModel.onAction(noCats, Ui(), Action.Button(0), now).record)
    }

    @Test
    fun `UT-WG-09 異常系：ないボタン・選択していないときの猫や次へは、記録せずにボタンに戻す`() {
        val s = ready(mike, tama)
        for (action in listOf(Action.Button(3), Action.Cat(0), Action.Next)) {
            val out = WidgetModel.onAction(s, Ui(), action, now)
            assertNull(out.record)
            assertEquals(Ui(), out.ui)
        }
        // ページがなくなった（猫が減った）選択の表示はボタンに戻す
        val stale = Ui(mode = Ui.CATS, type = food, page = 5, until = now + 1)
        assertEquals(listOf("ご飯", "水", null, null), labels(WidgetModel.screen(s, stale, now)))
    }

    @Test
    fun `UT-WG-10 押したときの道筋を行き来できる。知らない道筋は無視する`() {
        for (action in listOf(Action.Button(2), Action.Cat(1), Action.Next, Action.Cancel, Action.Expire)) {
            val path = RecordWidgetProvider.actionPath(action)
            assertEquals(action, parse(path))
        }
        assertNull(parse("button/x"))
        assertNull(parse("other"))
    }

    /** android.net.Uri は単体テストでは使えないので、道筋の部分だけで確かめる。 */
    private fun parse(path: String): Action? = RecordWidgetProvider.parsePath(path.split("/"))
}
