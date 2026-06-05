const STORAGE_KEY = "credit-card-profile-v1";
const BUILD = "2026-06-05-2015";
let state = loadState();

const els = {
  todayText: document.querySelector("#todayText"),
  tabs: document.querySelectorAll(".tab"),
  summaryStrip: document.querySelector("#summaryStrip"),
  recommendationCard: document.querySelector("#recommendationCard"),
  searchInput: document.querySelector("#searchInput"),
  statusFilter: document.querySelector("#statusFilter"),
  sortMode: document.querySelector("#sortMode"),
  cardList: document.querySelector("#cardList"),
  cardCount: document.querySelector("#cardCount"),
  remindersList: document.querySelector("#remindersList"),
  scenarioList: document.querySelector("#scenarioList"),
  campaignList: document.querySelector("#campaignList"),
  dataPreview: document.querySelector("#dataPreview"),
  addCardBtn: document.querySelector("#addCardBtn"),
  addCampaignBtn: document.querySelector("#addCampaignBtn"),
  exportBtn: document.querySelector("#exportBtn"),
  importInput: document.querySelector("#importInput"),
  resetBtn: document.querySelector("#resetBtn"),
  cardDialog: document.querySelector("#cardDialog"),
  cardForm: document.querySelector("#cardForm"),
  campaignDialog: document.querySelector("#campaignDialog"),
  campaignForm: document.querySelector("#campaignForm")
};

const cardFieldIds = ["cardId", "bank", "cardName", "network", "spendingCurrency", "last4", "holder", "status", "statementDay", "paymentDay", "annualFeeDay", "annualFeeRule", "creditLimit", "currency", "useTags", "avoidTags", "bindings", "replacement", "notes", "cashbackType", "cashbackRate", "rewardProgram", "benefitResetCycle"];
const cardFields = Object.fromEntries(cardFieldIds.map((id) => [id, document.querySelector(`#${id}`)]));
const campaignFields = Object.fromEntries(["campaignId", "campaignName", "campaignSource", "campaignStart", "campaignEnd", "campaignCards", "campaignRule", "campaignStatus"].map((id) => [id, document.querySelector(`#${id}`)]));

function loadState() {
  try {
    const raw = localStorage.getItem(STORAGE_KEY);
    if (raw) return JSON.parse(raw);
  } catch {}
  return { cards: [], campaigns: [] };
}
function saveState() { localStorage.setItem(STORAGE_KEY, JSON.stringify(state, null, 2)); }
function makeId() { return globalThis.crypto?.randomUUID?.() || `id-${Date.now()}-${Math.random().toString(16).slice(2)}`; }
function esc(value) { return String(value ?? "").replaceAll("&", "&amp;").replaceAll("<", "&lt;").replaceAll(">", "&gt;").replaceAll('"', "&quot;").replaceAll("'", "&#039;"); }
function splitTags(value) { if (Array.isArray(value)) return value.map((x) => String(x).trim()).filter(Boolean); return String(value || "").split(/[,，、\s;；]+/).map((x) => x.trim()).filter(Boolean); }
function nextMonthlyDate(day) { if (!day) return null; const now = new Date(); now.setHours(0,0,0,0); let date = new Date(now.getFullYear(), now.getMonth(), Math.min(Number(day), 28)); if (date < now) date = new Date(now.getFullYear(), now.getMonth() + 1, Math.min(Number(day), 28)); return date; }
function daysUntil(date) { if (!date) return Infinity; const now = new Date(); now.setHours(0,0,0,0); return Math.round((date - now) / 86400000); }
function fmtDate(date) { if (!date) return "未设置"; return `${date.getMonth() + 1}月${date.getDate()}日`; }
function money(value) { const match = String(value || "").replaceAll(",", "").match(/\d+(\.\d+)?/); return match ? Number(match[0]) : 0; }
function directCashbackScore(card) { const text = [card.cashbackType, card.cashbackRate, card.useTags].flat().join(" ").toLowerCase(); return /返利|返现|cashback|账单抵扣|现金/.test(text) ? 100 + money(card.cashbackRate) : 0; }
function cardScore(card) { let score = 0; const payDays = daysUntil(nextMonthlyDate(card.paymentDay)); if (payDays > 0 && Number.isFinite(payDays)) score += payDays; if (directCashbackScore(card)) score += 20; if (card.status !== "正常" && card.status !== "备用") score -= 100; return score; }

function installAndroidSafeControls() {
  document.querySelectorAll("dialog button[value='cancel']").forEach((button) => {
    button.type = "button";
    button.addEventListener("click", () => button.closest("dialog")?.close());
  });
  if (els.exportBtn && !document.querySelector("#copyDataBtn")) {
    const copyBtn = document.createElement("button");
    copyBtn.className = "ghost-btn";
    copyBtn.id = "copyDataBtn";
    copyBtn.type = "button";
    copyBtn.textContent = "复制 JSON";
    copyBtn.addEventListener("click", copyDataToClipboard);
    els.exportBtn.insertAdjacentElement("afterend", copyBtn);
  }
  if (els.exportBtn && !document.querySelector("#pasteImportBtn")) {
    const pasteBtn = document.createElement("button");
    pasteBtn.className = "ghost-btn";
    pasteBtn.id = "pasteImportBtn";
    pasteBtn.type = "button";
    pasteBtn.textContent = "粘贴导入";
    pasteBtn.addEventListener("click", () => {
      const text = prompt("把导出的 JSON 粘贴到这里：");
      if (text) importJsonText(text);
    });
    els.exportBtn.insertAdjacentElement("afterend", pasteBtn);
  }
}

function filteredCards() {
  const keyword = (els.searchInput.value || "").trim().toLowerCase();
  const status = els.statusFilter.value;
  let cards = state.cards.filter((card) => {
    const text = [card.bank, card.name, card.last4, card.network, card.useTags, card.notes, card.bindings, card.cashbackType, card.cashbackRate].flat().join(" ").toLowerCase();
    return (status === "all" || card.status === status) && (!keyword || text.includes(keyword));
  });
  if (els.sortMode.value === "cashback") cards = cards.filter((card) => directCashbackScore(card));
  return cards.sort((a, b) => {
    const mode = els.sortMode.value;
    if (mode === "statement" || mode === "statementBest") return Number(a.statementDay || 99) - Number(b.statementDay || 99);
    if (mode === "payment") return Number(a.paymentDay || 99) - Number(b.paymentDay || 99);
    if (mode === "creditLimit") return money(b.creditLimit) - money(a.creditLimit);
    if (mode === "cashback") return directCashbackScore(b) - directCashbackScore(a);
    return cardScore(b) - cardScore(a);
  });
}

function renderSummary() {
  const byBank = new Map();
  state.cards.filter((card) => card.status !== "已注销").forEach((card) => { if (!card.bank) return; byBank.set(card.bank, Math.max(byBank.get(card.bank) || 0, money(card.creditLimit))); });
  const total = [...byBank.values()].reduce((sum, value) => sum + value, 0);
  els.summaryStrip.innerHTML = `<div class="summary-item"><span>本人总额度</span><strong>${total ? `${total.toLocaleString("zh-CN")} CNY` : "未录入"}</strong><small>同一银行取最高额度</small></div><div class="summary-item"><span>有效卡片</span><strong>${state.cards.filter((card) => card.status !== "已注销").length} 张</strong><small>本机保存</small></div><div class="summary-item"><span>活动</span><strong>${state.campaigns.length} 个</strong><small>绑定具体卡片</small></div>`;
}
function renderRecommendation() {
  const best = [...state.cards].filter((card) => card.status === "正常" || card.status === "备用").sort((a, b) => cardScore(b) - cardScore(a))[0];
  els.recommendationCard.innerHTML = best ? `<div><div class="recommend-title">今日适合用卡</div><h2>${esc(best.bank || "未填写银行")}</h2><div class="recommend-card-name">${esc(best.name || "未命名卡片")} · 尾号 ${esc(best.last4 || "未填")}</div></div><div class="reason-list"><span class="reason-chip">距还款约 ${daysUntil(nextMonthlyDate(best.paymentDay))} 天</span>${directCashbackScore(best) ? '<span class="reason-chip">返利卡</span>' : ""}</div>` : `<div><div class="recommend-title">今日适合用卡</div><h2>暂无卡片</h2><div class="recommend-card-name">先新增一张卡</div></div>`;
}
function renderCards() { const cards = filteredCards(); els.cardCount.textContent = `${cards.length} 张`; els.cardList.innerHTML = cards.length ? cards.map(cardHtml).join("") : `<div class="empty">暂无卡片</div>`; }
function cardHtml(card) {
  const tags = splitTags(card.useTags).map((tag) => `<span class="tag">${esc(tag)}</span>`).join("");
  return `<article class="credit-card"><div class="card-top"><div><div class="bank-name">${esc(card.bank || "未填写银行")}</div><div class="card-title">${esc(card.name || "未命名卡片")}</div><div class="card-subtitle">${esc(card.network || "")}${card.spendingCurrency ? ` · ${esc(card.spendingCurrency)}` : ""} · 尾号 ${esc(card.last4 || "未填")}</div></div><span class="status-pill">${esc(card.status || "正常")}</span></div><div class="metrics"><div class="metric"><span>账单日</span><strong>${esc(card.statementDay || "未设")}</strong></div><div class="metric"><span>还款日</span><strong>${esc(card.paymentDay || "未设")}</strong></div><div class="metric"><span>年费</span><strong>${esc(card.annualFeeRule || "未设")}</strong></div></div><div class="tag-row">${tags}</div><div class="note-block">${esc(card.bindings || card.notes || "暂无备注")}</div><div class="note-block">返利：${esc(card.cashbackType || "未设置")} ${esc(card.cashbackRate || "")} · 额度：${esc(card.creditLimit || "未设置")} ${esc(card.currency || "")}</div><div class="note-block">消费/结算货币：${esc(card.spendingCurrency || "未设置")}</div><div class="card-actions"><button class="small-btn" data-action="edit-card" data-id="${card.id}">编辑</button><button class="small-btn" data-action="add-campaign-for-card" data-id="${card.id}">添加活动</button><button class="small-btn danger-text" data-action="delete-card" data-id="${card.id}">删除</button></div></article>`;
}
function renderReminders() {
  const items = [];
  state.cards.forEach((card) => { if (card.paymentDay) items.push({ type: "还款", date: nextMonthlyDate(card.paymentDay), title: `${card.bank} ${card.name || ""} 还款日`, meta: "确认是否已还款" }); if (card.statementDay) items.push({ type: "账单", date: nextMonthlyDate(card.statementDay), title: `${card.bank} ${card.name || ""} 账单日`, meta: "账单日后适合拉长还款周期" }); });
  state.campaigns.forEach((campaign) => { if (campaign.end) items.push({ type: "活动", date: new Date(`${campaign.end}T00:00:00`), title: `${campaign.name} 结束`, meta: campaign.rule || campaign.cards || "" }); });
  items.sort((a, b) => a.date - b.date);
  els.remindersList.innerHTML = items.length ? items.map((item) => `<article class="timeline-item"><div class="date-badge"><strong>${fmtDate(item.date)}</strong><span>${daysUntil(item.date)}天</span></div><div><div class="timeline-title">${esc(item.title)}</div><div class="timeline-meta">${esc(item.meta)}</div></div><span class="status-pill">${esc(item.type)}</span></article>`).join("") : `<div class="empty">暂无提醒</div>`;
}
function renderUsage() {
  const scenarios = ["大额", "最长还款", "返利", "里程", "境外", "网购", "酒店", "机票", "餐饮"];
  els.scenarioList.innerHTML = scenarios.map((scenario) => {
    const list = [...state.cards].filter((card) => card.status === "正常" || card.status === "备用").sort((a, b) => { if (scenario === "返利") return directCashbackScore(b) - directCashbackScore(a); if (scenario === "最长还款") return daysUntil(nextMonthlyDate(b.paymentDay)) - daysUntil(nextMonthlyDate(a.paymentDay)); return (splitTags(b.useTags).includes(scenario) ? 1 : 0) - (splitTags(a.useTags).includes(scenario) ? 1 : 0); }).slice(0, 3);
    return `<article class="scenario-card"><h3>${scenario}</h3><p>根据卡片档案字段筛选。</p>${list.map((card) => `<div class="credit-mini"><strong>${esc(card.bank)} ${esc(card.name || "")} · ${esc(card.last4 || "未填")}</strong><p>${esc(splitTags(card.useTags).join("；") || "备选")}</p></div>`).join("")}</article>`;
  }).join("");
}
function renderCampaigns() { els.campaignList.innerHTML = state.campaigns.length ? state.campaigns.map((campaign) => `<article class="campaign-card"><div><h3>${esc(campaign.name)}</h3><p>${esc(campaign.source || "活动")} · ${esc(campaign.cards)}</p><p>${esc(campaign.rule)}</p><div class="tag-row"><span class="tag">${esc(campaign.start || "未设")} 至 ${esc(campaign.end || "未设")}</span><span class="tag">${esc(campaign.status || "未用")}</span></div></div><div class="campaign-actions"><button class="small-btn" data-action="edit-campaign" data-id="${campaign.id}">编辑</button></div></article>`).join("") : `<div class="empty">暂无活动</div>`; }
function renderData() { els.dataPreview.value = JSON.stringify(state, null, 2); }
function render() { els.todayText.textContent = `${new Date().toLocaleDateString("zh-CN")} · APK修复版 ${BUILD}`; renderSummary(); renderRecommendation(); renderCards(); renderReminders(); renderUsage(); renderCampaigns(); renderData(); saveState(); }
function setView(view) { document.querySelectorAll(".view").forEach((node) => node.classList.remove("active")); document.querySelector(`#${view}View`).classList.add("active"); els.tabs.forEach((tab) => tab.classList.toggle("active", tab.dataset.view === view)); }

function importJsonText(text) { try { const parsed = JSON.parse(text); state = { cards: Array.isArray(parsed.cards) ? parsed.cards : [], campaigns: Array.isArray(parsed.campaigns) ? parsed.campaigns : [] }; render(); alert("导入成功。"); } catch { alert("JSON 格式不正确，导入失败。"); } }
async function copyDataToClipboard() { const text = JSON.stringify(state, null, 2); els.dataPreview.value = text; els.dataPreview.focus(); els.dataPreview.select(); try { await navigator.clipboard?.writeText(text); alert("JSON 已复制。"); } catch { document.execCommand?.("copy"); alert("JSON 已显示在下方，请长按文本框复制。"); } }
function openCardDialog(card = null) { cardFields.cardId.value = card?.id || ""; cardFields.bank.value = card?.bank || ""; cardFields.cardName.value = card?.name || ""; cardFields.network.value = card?.network || "Visa"; cardFields.spendingCurrency.value = card?.spendingCurrency || ""; cardFields.last4.value = card?.last4 || ""; cardFields.holder.value = card?.holder || "本人"; cardFields.status.value = card?.status || "正常"; cardFields.statementDay.value = card?.statementDay || ""; cardFields.paymentDay.value = card?.paymentDay || ""; cardFields.annualFeeDay.value = card?.annualFeeDate || ""; cardFields.annualFeeRule.value = card?.annualFeeRule || "终身免年费"; cardFields.creditLimit.value = card?.creditLimit || ""; cardFields.currency.value = card?.currency || ""; cardFields.useTags.value = splitTags(card?.useTags).join(", "); cardFields.avoidTags.value = splitTags(card?.avoidTags).join(", "); cardFields.bindings.value = card?.bindings || ""; cardFields.replacement.value = card?.replacement || ""; cardFields.notes.value = card?.notes || ""; cardFields.cashbackType.value = card?.cashbackType || ""; cardFields.cashbackRate.value = card?.cashbackRate || ""; cardFields.rewardProgram.value = card?.rewardProgram || ""; cardFields.benefitResetCycle.value = card?.benefitResetCycle || "未知"; els.cardDialog.showModal(); }
function saveCard() { const card = { id: cardFields.cardId.value || makeId(), bank: cardFields.bank.value.trim(), name: cardFields.cardName.value.trim(), network: cardFields.network.value, spendingCurrency: cardFields.spendingCurrency.value.trim(), last4: cardFields.last4.value.trim().slice(-4), holder: cardFields.holder.value.trim() || "本人", status: cardFields.status.value, statementDay: cardFields.statementDay.value, paymentDay: cardFields.paymentDay.value, annualFeeDate: cardFields.annualFeeDay.value, annualFeeRule: cardFields.annualFeeRule.value, creditLimit: cardFields.creditLimit.value.trim(), currency: cardFields.currency.value.trim(), useTags: cardFields.useTags.value, avoidTags: cardFields.avoidTags.value, bindings: cardFields.bindings.value.trim(), replacement: cardFields.replacement.value.trim(), notes: cardFields.notes.value.trim(), cashbackType: cardFields.cashbackType.value.trim(), cashbackRate: cardFields.cashbackRate.value.trim(), rewardProgram: cardFields.rewardProgram.value.trim(), benefitResetCycle: cardFields.benefitResetCycle.value }; const index = state.cards.findIndex((item) => item.id === card.id); if (index >= 0) state.cards[index] = card; else state.cards.unshift(card); render(); }
function openCampaignDialog(campaign = null) { campaignFields.campaignId.value = campaign?.id || ""; campaignFields.campaignName.value = campaign?.name || ""; campaignFields.campaignSource.value = campaign?.source || ""; campaignFields.campaignStart.value = campaign?.start || ""; campaignFields.campaignEnd.value = campaign?.end || ""; campaignFields.campaignCards.value = campaign?.cards || ""; campaignFields.campaignRule.value = campaign?.rule || ""; campaignFields.campaignStatus.value = campaign?.status || "未用"; els.campaignDialog.showModal(); }
function saveCampaign() { if (!campaignFields.campaignCards.value.trim()) return alert("请填写适用卡。"); const campaign = { id: campaignFields.campaignId.value || makeId(), name: campaignFields.campaignName.value.trim(), source: campaignFields.campaignSource.value.trim(), start: campaignFields.campaignStart.value, end: campaignFields.campaignEnd.value, cards: campaignFields.campaignCards.value.trim(), rule: campaignFields.campaignRule.value.trim(), status: campaignFields.campaignStatus.value }; const index = state.campaigns.findIndex((item) => item.id === campaign.id); if (index >= 0) state.campaigns[index] = campaign; else state.campaigns.unshift(campaign); render(); }

installAndroidSafeControls();
els.tabs.forEach((tab) => tab.addEventListener("click", () => setView(tab.dataset.view)));
els.searchInput.addEventListener("input", renderCards);
els.statusFilter.addEventListener("change", renderCards);
els.sortMode.addEventListener("change", renderCards);
document.querySelectorAll(".quick-view").forEach((button) => button.addEventListener("click", () => { els.sortMode.value = button.dataset.sort; setView("cards"); renderCards(); }));
els.addCardBtn.addEventListener("click", () => openCardDialog());
els.addCampaignBtn.addEventListener("click", () => openCampaignDialog());
els.cardForm.addEventListener("submit", (event) => { event.preventDefault(); saveCard(); els.cardDialog.close(); });
els.campaignForm.addEventListener("submit", (event) => { event.preventDefault(); saveCampaign(); els.campaignDialog.close(); });

document.addEventListener("click", (event) => { const button = event.target.closest("[data-action]"); if (!button) return; const { action, id } = button.dataset; if (action === "edit-card") openCardDialog(state.cards.find((card) => card.id === id)); if (action === "delete-card") { state.cards = state.cards.filter((card) => card.id !== id); render(); } if (action === "add-campaign-for-card") { const card = state.cards.find((item) => item.id === id); if (card) openCampaignDialog({ cards: `${card.bank} ${card.name || ""} 尾号${card.last4 || "未填"}`, status: "未用" }); } if (action === "edit-campaign") openCampaignDialog(state.campaigns.find((campaign) => campaign.id === id)); });

els.exportBtn.addEventListener("click", () => { const text = JSON.stringify(state, null, 2); els.dataPreview.value = text; const blob = new Blob([text], { type: "application/json" }); const link = document.createElement("a"); link.href = URL.createObjectURL(blob); link.download = `信用卡档案-${new Date().toISOString().slice(0, 10)}.json`; link.click(); URL.revokeObjectURL(link.href); setTimeout(() => alert("如果手机没有出现下载文件，请点“复制 JSON”，先用复制方式备份。"), 120); });
els.importInput.addEventListener("change", async (event) => { const file = event.target.files?.[0]; if (!file) return; importJsonText(await file.text()); event.target.value = ""; });
els.resetBtn.addEventListener("click", () => { if (confirm("确定清空并恢复空数据？")) { state = { cards: [], campaigns: [] }; render(); } });

render();