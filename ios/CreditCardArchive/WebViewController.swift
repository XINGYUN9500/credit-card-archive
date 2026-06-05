import UIKit
import WebKit

final class WebViewController: UIViewController, WKNavigationDelegate {
    private var webView: WKWebView!

    override func loadView() {
        let configuration = WKWebViewConfiguration()
        configuration.preferences.javaScriptCanOpenWindowsAutomatically = true
        webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = self
        view = webView
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        webView.loadHTMLString(Self.embeddedHtml, baseURL: nil)
    }

    private static let embeddedHtml = #"""
<!doctype html>
<html lang="zh-CN">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width,initial-scale=1,viewport-fit=cover">
<title>信用卡档案</title>
<style>
body{margin:0;background:#f7faf8;color:#14211f;font-family:-apple-system,BlinkMacSystemFont,"PingFang SC",sans-serif}.app{padding:max(14px,env(safe-area-inset-top)) 14px max(22px,env(safe-area-inset-bottom));max-width:760px;margin:auto}header{display:flex;align-items:flex-start;justify-content:space-between;gap:12px}h1{margin:0;font-size:30px}p{color:#6b7b78}.tabs{display:grid;grid-template-columns:repeat(3,1fr);gap:8px;margin:16px 0}button,input,textarea{font:inherit}button{border:1px solid #dce8e4;background:white;border-radius:8px;padding:10px 12px;font-weight:700}.primary{background:#0f766e;color:white;border-color:#0f766e}.tab.active{background:#eaf5f1;color:#0f766e}.panel{display:none}.panel.active{display:block}input,textarea{width:100%;box-sizing:border-box;border:1px solid #dce8e4;border-radius:8px;padding:11px;background:white;margin:6px 0}.card{background:white;border:1px solid #dce8e4;border-radius:10px;padding:14px;margin:10px 0;box-shadow:0 8px 24px rgba(20,33,31,.06)}.meta{color:#6b7b78;line-height:1.55}.row{display:grid;grid-template-columns:1fr 1fr;gap:8px}.actions{display:flex;gap:8px;flex-wrap:wrap}.danger{color:#b42318}#dataBox{min-height:55vh;font-family:ui-monospace,Menlo,monospace;font-size:12px}
</style>
</head>
<body>
<main class="app">
<header><div><h1>信用卡档案</h1><p>iOS 内嵌测试版 0.1.3 build 4</p></div><button class="primary" onclick="showForm()">新增</button></header>
<nav class="tabs"><button class="tab active" onclick="tab('cards')">档案</button><button class="tab" onclick="tab('reminders')">提醒</button><button class="tab" onclick="tab('data')">数据</button></nav>
<section id="cards" class="panel active"><div id="form" class="card" style="display:none"><h3>卡片档案</h3><input id="bank" placeholder="银行"><input id="name" placeholder="卡名"><input id="last4" placeholder="尾号"><div class="row"><input id="statement" type="number" min="1" max="31" placeholder="账单日"><input id="payment" type="number" min="1" max="31" placeholder="还款日"></div><input id="cashback" placeholder="返利/活动，例如 Visa境外返现"><textarea id="notes" placeholder="备注"></textarea><div class="actions"><button class="primary" onclick="saveCard()">保存</button><button onclick="hideForm()">取消</button></div></div><div id="list"></div></section>
<section id="reminders" class="panel"><div id="reminderList"></div></section>
<section id="data" class="panel"><div class="actions"><button class="primary" onclick="copyData()">复制 JSON</button><button onclick="pasteData()">粘贴导入</button><button class="danger" onclick="clearData()">清空</button></div><textarea id="dataBox"></textarea></section>
</main>
<script>
let cards=JSON.parse(localStorage.cards||'[]');let editId=null;function save(){localStorage.cards=JSON.stringify(cards);render()}function esc(s){return String(s||'').replace(/[&<>]/g,m=>({'&':'&amp;','<':'&lt;','>':'&gt;'}[m]))}function tab(id){document.querySelectorAll('.panel').forEach(p=>p.classList.toggle('active',p.id===id));document.querySelectorAll('.tab').forEach((b,i)=>b.classList.toggle('active',['cards','reminders','data'][i]===id));render()}function showForm(c){document.getElementById('form').style.display='block';editId=c&&c.id;bank.value=c?.bank||'';name.value=c?.name||'';last4.value=c?.last4||'';statement.value=c?.statement||'';payment.value=c?.payment||'';cashback.value=c?.cashback||'';notes.value=c?.notes||''}function hideForm(){document.getElementById('form').style.display='none';editId=null}function saveCard(){const c={id:editId||Date.now(),bank:bank.value,name:name.value,last4:last4.value,statement:statement.value,payment:payment.value,cashback:cashback.value,notes:notes.value};if(editId){cards=cards.map(x=>x.id===editId?c:x)}else cards.unshift(c);hideForm();save()}function del(id){if(confirm('删除这张卡？')){cards=cards.filter(c=>c.id!==id);save()}}function nextDay(day){if(!day)return null;const n=new Date();n.setHours(0,0,0,0);let d=new Date(n.getFullYear(),n.getMonth(),Math.min(+day,28));if(d<n)d=new Date(n.getFullYear(),n.getMonth()+1,Math.min(+day,28));return d}function days(d){return d?Math.round((d-new Date().setHours(0,0,0,0))/86400000):999}function render(){list.innerHTML=cards.length?cards.map(c=>`<article class="card"><h3>${esc(c.bank||'未填银行')}</h3><div class="meta">${esc(c.name||'未命名')} · 尾号 ${esc(c.last4||'未填')}</div><p class="meta">账单日 ${esc(c.statement||'未设')} · 还款日 ${esc(c.payment||'未设')}</p>${c.cashback?`<p class="meta">返利：${esc(c.cashback)}</p>`:''}<p class="meta">${esc(c.notes)}</p><div class="actions"><button onclick='showForm(${JSON.stringify(c)})'>编辑</button><button class="danger" onclick="del(${c.id})">删除</button></div></article>`).join(''):'<article class="card"><h3>暂无卡片</h3><p>先新增一张卡。</p></article>';reminderList.innerHTML=cards.flatMap(c=>[['账单',nextDay(c.statement)],['还款',nextDay(c.payment)]].filter(x=>x[1]).map(([t,d])=>({t,d,c}))).sort((a,b)=>a.d-b.d).map(r=>`<article class="card"><h3>${esc(r.c.bank)} ${r.t}日</h3><p class="meta">${r.d.getMonth()+1}月${r.d.getDate()}日 · ${days(r.d)}天后 · 默认提前2天10:00提醒</p></article>`).join('')||'<article class="card"><h3>暂无提醒</h3></article>';dataBox.value=JSON.stringify(cards,null,2)}async function copyData(){dataBox.value=JSON.stringify(cards,null,2);dataBox.select();try{await navigator.clipboard.writeText(dataBox.value)}catch{document.execCommand('copy')}}function pasteData(){const v=prompt('粘贴 JSON');if(!v)return;try{cards=JSON.parse(v);save()}catch{alert('JSON 格式不正确')}}function clearData(){if(confirm('确定清空？')){cards=[];save()}}render();
</script>
</body>
</html>
"""#
}
