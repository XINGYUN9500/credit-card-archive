const STORAGE_KEY = "credit-card-archive-ios-v1";
const DEFAULT_LEAD_DAYS = 2;
const DEFAULT_TIME = "10:00";
let state = loadState();

const $ = (id) => document.querySelector(id);
const els = {
  buildText: $("#buildText"),
  tabs: document.querySelectorAll(".tab"),
  panels: document.querySelectorAll(".panel"),
  addCardBtn: $("#addCardBtn"),
  cardDialog: $("#cardDialog"),
  cardForm: $("#cardForm"),
  closeDialogBtn: $("#closeDialogBtn"),
  cancelBtn: $("#cancelBtn"),
  searchInput: $("#searchInput"),
  sortMode: $("#sortMode"),
  cardList: $("#cardList"),
  reminderList: $("#reminderList"),
  usageList: $("#usageList"),
  dataBox: $("#dataBox"),
  copyBtn: $("#copyBtn"),
  pasteBtn: $("#pasteBtn"),
  resetBtn: $("#resetBtn")
};

const fields = ["cardId", "bank", "cardName", "last4", "statementDay", "paymentDay", "annualFeeDate", "reminderLeadDays", "reminderTime", "cashbackType", "cashbackRate", "useTags", "replacement", "notes"]
  .reduce((map, id) => ({ ...map, [id]: $(`#${id}`) }), {});

function loadState() {
  try {
    return JSON.parse(localStorage.getItem(STORAGE_KEY)) || { cards: [] };
  } catch {
    return { cards: [] };
  }
}

function saveState() {
  localStorage.setItem(STORAGE_KEY, JSON.stringify(state, null, 2));
}

function makeId() {
  return crypto?.randomUUID?.() || `id-${Date.now()}-${Math.random().toString(16).slice(2)}`;
}

function esc(value) {
  return String(value ?? "").replaceAll("&", "&amp;").replaceAll("<", "&lt;").replaceAll(">", "&gt;").replaceAll('"', "&quot;");
}

function today() {
  const d = new Date();
  d.setHours(0, 0, 0, 0);
  return d;
}

function daysInMonth(year, month) {
  return new Date(year, month + 1, 0).getDate();
}

function nextMonthlyDate(day) {
  if (!day) return null;
  const now = today();
  let d = new Date(now.getFullYear(), now.getMonth(), Math.min(Number(day), daysInMonth(now.getFullYear(), now.getMonth())));
  if (d < now) d = new Date(now.getFullYear(), now.getMonth() + 1, Math.min(Number(day), daysInMonth(now.getFullYear(), now.getMonth() + 1)));
  return d;
}

function parseDate(value) {
  if (!value) return null;
  const d = new Date(`${value}T00:00:00`);
  return Number.isNaN(d.getTime()) ? null : d;
}

function annualDate(value) {
  const base = parseDate(value);
  if (!base) return null;
  const now = today();
  let d = new Date(now.getFullYear(), base.getMonth(), base.getDate());
  if (d < now) d = new Date(now.getFullYear() + 1, base.getMonth(), base.getDate());
  return d;
}

function daysUntil(date) {
  if (!date) return Infinity;
  return Math.round((date - today()) / 86400000);
}

function addDays(date, days) {
  const d = new Date(date);
  d.setDate(d.getDate() + days);
  return d;
}

function leadDays(value) {
  const n = Number(value);
  return Number.isFinite(n) && n >= 0 ? Math.min(n, 30) : DEFAULT_LEAD_DAYS;
}

function reminderTime(date, card) {
  if (!date) return null;
  const d = addDays(date, -leadDays(card.reminderLeadDays));
  const [h = 10, m = 0] = String(card.reminderTime || DEFAULT_TIME).split(":").map(Number);
  d.setHours(h, m, 0, 0);
  return d;
}

function fmt(date) {
  if (!date) return "未设置";
  return `${date.getMonth() + 1}月${date.getDate()}日`;
}

function fmtTime(date) {
  if (!date) return "不提醒";
  return `${fmt(date)} ${String(date.getHours()).padStart(2, "0")}:${String(date.getMinutes()).padStart(2, "0")}`;
}

function hasCashback(card) {
  return /返利|返现|cashback|账单抵扣|现金|满减|立减/.test([card.cashbackType, card.cashbackRate].join(" ").toLowerCase());
}

function getCards() {
  const kw = els.searchInput.value.trim().toLowerCase();
  let cards = state.cards.filter((card) => !kw || [card.bank, card.name, card.last4, card.useTags, card.cashbackType].join(" ").toLowerCase().includes(kw));
  if (els.sortMode.value === "cashback") cards = cards.filter(hasCashback);
  return cards.sort((a, b) => {
    if (els.sortMode.value === "statement") return daysUntil(nextMonthlyDate(a.statementDay)) - daysUntil(nextMonthlyDate(b.statementDay));
    if (els.sortMode.value === "payment") return daysUntil(nextMonthlyDate(a.paymentDay)) - daysUntil(nextMonthlyDate(b.paymentDay));
    if (els.sortMode.value === "cashback") return Number(hasCashback(b)) - Number(hasCashback(a));
    return daysUntil(nextMonthlyDate(b.paymentDay)) - daysUntil(nextMonthlyDate(a.paymentDay));
  });
}

function getReminders() {
  const reminders = [];
  state.cards.forEach((card) => {
    const name = `${card.bank || ""} ${card.name || ""} 尾号${card.last4 || "未填"}`.trim();
    const items = [
      ["账单", nextMonthlyDate(card.statementDay), "账单日后适合拉长还款周期"],
      ["还款", nextMonthlyDate(card.paymentDay), "确认是否已还款，避免逾期"],
      ["年费", annualDate(card.annualFeeDate), "检查年费规则"]
    ];
    items.forEach(([type, date, meta]) => {
      if (date) reminders.push({ type, date, title: `${name} ${type}日`, meta, remindAt: reminderTime(date, card) });
    });
  });
  return reminders.sort((a, b) => a.date - b.date || a.remindAt - b.remindAt);
}

function renderCards() {
  const cards = getCards();
  els.cardList.innerHTML = cards.length ? cards.map((card) => `
    <article class="card">
      <h2>${esc(card.bank || "未填写银行")}</h2>
      <div class="meta">${esc(card.name || "未命名卡片")} · 尾号 ${esc(card.last4 || "未填")}</div>
      <div class="chips">
        <span class="chip">账单 ${esc(card.statementDay || "未设")}</span>
        <span class="chip">还款 ${esc(card.paymentDay || "未设")}</span>
        ${hasCashback(card) ? `<span class="chip">返利</span>` : ""}
      </div>
      <p class="meta">${esc(card.notes || card.replacement || "暂无备注")}</p>
      <div class="actions">
        <button data-action="edit" data-id="${card.id}" type="button">编辑</button>
        <button class="danger" data-action="delete" data-id="${card.id}" type="button">删除</button>
      </div>
    </article>
  `).join("") : `<article class="card"><h3>暂无卡片</h3><p>先新增一张卡。</p></article>`;
}

function renderReminders() {
  const reminders = getReminders();
  els.reminderList.innerHTML = reminders.length ? reminders.map((item) => {
    const due = daysUntil(item.date);
    return `
      <article class="card">
        <h3>${esc(item.title)}</h3>
        <div class="meta">${fmt(item.date)} · ${due === 0 ? "今天" : due > 0 ? `${due}天后` : `已过${Math.abs(due)}天`}</div>
        <p class="meta">${esc(item.meta)} · 提醒 ${fmtTime(item.remindAt)}</p>
      </article>
    `;
  }).join("") : `<article class="card"><h3>暂无提醒</h3></article>`;
}

function renderUsage() {
  const cashbackCards = state.cards.filter(hasCashback);
  const bestPay = [...state.cards].sort((a, b) => daysUntil(nextMonthlyDate(b.paymentDay)) - daysUntil(nextMonthlyDate(a.paymentDay))).slice(0, 3);
  els.usageList.innerHTML = `
    <article class="card"><h3>返利</h3>${cashbackCards.length ? cashbackCards.map((c) => `<p class="meta">${esc(c.bank)} ${esc(c.name)} · ${esc(c.cashbackType || c.cashbackRate)}</p>`).join("") : `<p class="meta">没有设置返利字段的卡</p>`}</article>
    <article class="card"><h3>最长还款</h3>${bestPay.map((c) => `<p class="meta">${esc(c.bank)} ${esc(c.name)} · 还款日 ${esc(c.paymentDay || "未设")}</p>`).join("")}</article>
  `;
}

function renderData() {
  els.dataBox.value = JSON.stringify(state, null, 2);
}

function render() {
  els.buildText.textContent = `iOS IPA 测试版 ${new Date().toLocaleDateString("zh-CN")}`;
  renderCards();
  renderReminders();
  renderUsage();
  renderData();
  saveState();
}

function openCard(card = null) {
  fields.cardId.value = card?.id || "";
  fields.bank.value = card?.bank || "";
  fields.cardName.value = card?.name || "";
  fields.last4.value = card?.last4 || "";
  fields.statementDay.value = card?.statementDay || "";
  fields.paymentDay.value = card?.paymentDay || "";
  fields.annualFeeDate.value = card?.annualFeeDate || "";
  fields.reminderLeadDays.value = card?.reminderLeadDays ?? "";
  fields.reminderTime.value = card?.reminderTime || DEFAULT_TIME;
  fields.cashbackType.value = card?.cashbackType || "";
  fields.cashbackRate.value = card?.cashbackRate || "";
  fields.useTags.value = card?.useTags || "";
  fields.replacement.value = card?.replacement || "";
  fields.notes.value = card?.notes || "";
  els.cardDialog.showModal();
}

function saveCard() {
  const card = {
    id: fields.cardId.value || makeId(),
    bank: fields.bank.value.trim(),
    name: fields.cardName.value.trim(),
    last4: fields.last4.value.trim().slice(-4),
    statementDay: fields.statementDay.value,
    paymentDay: fields.paymentDay.value,
    annualFeeDate: fields.annualFeeDate.value,
    reminderLeadDays: fields.reminderLeadDays.value === "" ? "" : Number(fields.reminderLeadDays.value),
    reminderTime: fields.reminderTime.value || DEFAULT_TIME,
    cashbackType: fields.cashbackType.value.trim(),
    cashbackRate: fields.cashbackRate.value.trim(),
    useTags: fields.useTags.value.trim(),
    replacement: fields.replacement.value.trim(),
    notes: fields.notes.value.trim()
  };
  const index = state.cards.findIndex((item) => item.id === card.id);
  if (index >= 0) state.cards[index] = card;
  else state.cards.unshift(card);
  render();
}

function setView(view) {
  els.panels.forEach((panel) => panel.classList.toggle("active", panel.id === `${view}View`));
  els.tabs.forEach((tab) => tab.classList.toggle("active", tab.dataset.view === view));
  if (view === "cards") {
    els.searchInput.value = "";
    els.sortMode.value = "best";
    renderCards();
  }
}

els.tabs.forEach((tab) => tab.addEventListener("click", () => setView(tab.dataset.view)));
els.addCardBtn.addEventListener("click", () => openCard());
els.closeDialogBtn.addEventListener("click", () => els.cardDialog.close());
els.cancelBtn.addEventListener("click", () => els.cardDialog.close());
els.cardForm.addEventListener("submit", (event) => {
  event.preventDefault();
  saveCard();
  els.cardDialog.close();
});
els.searchInput.addEventListener("input", renderCards);
els.sortMode.addEventListener("change", renderCards);
document.addEventListener("click", (event) => {
  const button = event.target.closest("[data-action]");
  if (!button) return;
  const card = state.cards.find((item) => item.id === button.dataset.id);
  if (button.dataset.action === "edit" && card) openCard(card);
  if (button.dataset.action === "delete") {
    state.cards = state.cards.filter((item) => item.id !== button.dataset.id);
    render();
  }
});
els.copyBtn.addEventListener("click", async () => {
  renderData();
  els.dataBox.select();
  try { await navigator.clipboard.writeText(els.dataBox.value); } catch { document.execCommand("copy"); }
});
els.pasteBtn.addEventListener("click", () => {
  const text = prompt("粘贴 JSON");
  if (!text) return;
  try { state = JSON.parse(text); render(); } catch { alert("JSON 格式不正确"); }
});
els.resetBtn.addEventListener("click", () => {
  if (!confirm("确定清空？")) return;
  state = { cards: [] };
  render();
});

render();
