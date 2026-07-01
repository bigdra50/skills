/* ============================================================
 * .claude/reports/_index.js
 * レポートのマニフェスト。
 * new-report.sh が自動でエントリ追加するため、通常は手で編集しなくて良い。
 * ============================================================ */

window.REPORTS_INDEX = [
  // ----------------------------------------------------------
  // ここに各レポートのエントリが入る (new-report.sh が prepend する)
  // ----------------------------------------------------------
];

/**
 * 型定義 (JSDoc)
 *
 * @typedef {Object} ReportEntry
 * @property {string} id        - スラッグ (例: "2026-05-20-shallow-class")
 * @property {string} title     - 表示タイトル
 * @property {"review"|"plan"|"audit"|"adr-analysis"} type
 * @property {string} date      - "YYYY-MM-DD"
 * @property {string} path      - .claude/reports/ からの相対パス
 * @property {string[]} tags
 * @property {string} summary   - 1〜2行の要約
 * @property {"done"|"draft"|"in-progress"|"template"|"archived"} status
 * @property {string} [author]
 */
