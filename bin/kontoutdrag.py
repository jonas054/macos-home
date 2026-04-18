import csv, json, re, unicodedata
from collections import defaultdict
from datetime import datetime, timedelta
from decimal import Decimal
from pathlib import Path

csv_path = Path('/Users/jonas/Downloads/kontoutdrag 20260417-2230.csv')
html_path = Path('/Users/jonas/Downloads/kontoutdrag-analys.html')


def clean_text(text: str) -> str:
    text = text.split('/')[0].strip()
    text = re.sub(r'\s+', ' ', text)
    return text


def normalize(text: str) -> tuple[str, str]:
    cleaned = clean_text(text).upper()
    ascii_text = unicodedata.normalize('NFKD', cleaned).encode('ascii', 'ignore').decode('ascii')
    return cleaned, ascii_text


def has_any(text: str, needles: list[str]) -> bool:
    return any(needle in text for needle in needles)


def categorize(text: str) -> str:
    _, t = normalize(text)
    if re.fullmatch(r'(46\d{8,}|\d{9,}(?: [A-Z])?)', t) or t in {'JANSSON, JONAS'}:
        return 'Swish & överföringar'
    if has_any(t, ['SPARA', 'AVANZA']):
        return 'Sparande & investering'
    if has_any(t, ['SBAB', 'K-D ENERGI', 'KD ENERGI', 'NORDPOLEN ENERGI', 'KARLSTAD VA', 'VERISURE']):
        return 'Boende & räkningar'
    if has_any(t, ['GRANLIDEN', 'SOLPARTNER', 'SVEALANDS TAK', 'IKEA', 'K-RAUTA', 'BAUHAUS', 'COLORAMA', 'VARMLANDSTRA', 'KAKSERVICE', 'KAKELBUTIKEN', 'GRANNGARDEN', 'CLAS OHLSON', 'BATTERILAGRE', 'SOTNING']):
        return 'Hem & renovering'
    if has_any(t, ['ICA', 'COOP', 'WILLYS', 'LIDL', 'HEMKOP', 'MATMARKNADEN', 'CITY GROSS', 'KVANTUM', 'SUPERMARKET', 'SYSTEMBOLAGE']):
        return 'Mat & dagligvaror'
    if has_any(t, ['GO BANANA', 'LI AMICE', 'ALLEGRILLEN', 'KFC', 'THE CROKE', 'HONG BAO', 'BURGER', 'RESTAUR', 'PIZZA', 'SUSHI', 'ESPRESSO', 'CAFE', 'FUNKY STREET', 'BODA BORG', 'JUMPYARD', 'VIN O DELI', 'ARTISAN BREA', 'OKLAHOMA CIT', 'FRATELLI', 'SPICY HOT', 'BASTARD BURG', 'CHOPCHOP', 'JULINS RESTA', 'JOAN S KARLS', 'L SPRESSO', 'VICINOBARFRA', 'HEMMA HOS KA']):
        return 'Restaurang & nöje'
    if has_any(t, ['OKQ8', 'ST1', 'PREEM', 'INGO', 'BILTEMA', 'KARLSTADBUSS', 'VEHO BIL', 'VOLVOFINANS', 'DACKIA', 'BILLOGRAM', 'CITYVERKSTAD', 'CIRCLE K', 'QSTAR', 'PARKERING', 'EASYPARK', 'BESIKTA', 'WAXNAS CYKEL']):
        return 'Transport & bil'
    if has_any(t, ['APPLE', 'GOOGLE', 'MICROSOFT', 'NETFLIX', 'PATREON', 'PAYPAL', 'BOOKBEAT', 'HALLON', 'TELE2', 'TELIA', 'DISN', 'SKYSHOWTIME', 'NORTON']):
        return 'Digitalt & abonnemang'
    if has_any(t, ['APOT', 'APOTEA', 'APOHEM', 'FOLKTANDVARDEN', 'SMILE', 'LANSFORHALSA', 'KRONANS', 'REGION VARMLAND']):
        return 'Hälsa & apotek'
    if has_any(t, ['AMAZON', 'NETONNET', 'KJELL', 'KOMPLETT', 'INET', 'STADIUM', 'DRESSMANN', 'TEAM SPORTIA', 'EWHEELS', 'BODYSTORE', 'SPORT SCAN', 'MACBOOK PRO', 'JACK JONES', 'INTERSPORT', 'CLARKS', 'KAPPAHL', 'SHARKGAMING', 'POP STORY', 'QLIRO', 'WALLEY', 'ADYEN N.V.', 'BN-VF', 'ZETTLE']):
        return 'Shopping & elektronik'
    if has_any(t, ['RODA KORSET', 'RADDA BARNEN', 'HRFINSAMLING', 'GOD JUL']):
        return 'Gåvor & donationer'
    if has_any(t, ['SVEA BANK', 'LANSFORSAKRINGAR FINANS', 'WASA KREDIT', 'TF BANK']):
        return 'Lån & kredit'
    if has_any(t, ['RESA', 'FLYGBILJETT', 'PORTUGAL', 'SKISTAR', 'FOREX', 'SAN FRANCISC', 'HARPENDEN', 'DUBLIN', 'COURTYARD', 'BESTWEST']):
        return 'Resor'
    if has_any(t, ['IF SKADEFORSAKRING', 'GJENSIDIGE', 'LANSFORSAKRINGAR AB']):
        return 'Försäkring'
    if has_any(t, ['SV INGENJ', 'VF DRIFT AB', 'KILS SLALOMK', 'ENKLA VARDAG', 'RACKETCENTER', 'QOPLA', 'FLOWY INFORM', 'STIFTELSEN']):
        return 'Medlemskap & avgifter'
    return 'Övrigt'


def to_float(value: Decimal) -> float:
    return float(value.quantize(Decimal('0.01')))

rows = []
with csv_path.open(encoding='utf-8-sig', newline='') as f:
    reader = csv.DictReader(f, delimiter=';')
    for raw in reader:
        date_value = datetime.strptime(raw['Bokföringsdatum'], '%Y-%m-%d').date()
        amount = Decimal(raw['Belopp'])
        rows.append({
            'date': date_value,
            'amount': amount,
            'merchant': clean_text(raw['Text']),
            'category': categorize(raw['Text']),
        })

rows.sort(key=lambda r: r['date'])
min_date = rows[0]['date']
max_date = rows[-1]['date']
cutoff = max_date - timedelta(days=365)
last12 = [r for r in rows if r['date'] >= cutoff]
months = sorted({r['date'].strftime('%Y-%m') for r in last12})

category_colors = {
    'Boende & räkningar': '#4f46e5', 'Hem & renovering': '#7c3aed', 'Mat & dagligvaror': '#16a34a',
    'Restaurang & nöje': '#f59e0b', 'Transport & bil': '#0ea5e9', 'Digitalt & abonnemang': '#ec4899',
    'Hälsa & apotek': '#14b8a6', 'Shopping & elektronik': '#ef4444', 'Gåvor & donationer': '#84cc16',
    'Lån & kredit': '#6b7280', 'Resor': '#8b5cf6', 'Försäkring': '#f97316', 'Swish & överföringar': '#64748b',
    'Sparande & investering': '#111827', 'Medlemskap & avgifter': '#0891b2', 'Övrigt': '#94a3b8'
}

category_totals = defaultdict(Decimal)
for r in last12:
    if r['amount'] < 0:
        category_totals[r['category']] += -r['amount']
last12_total_outflow = sum(category_totals.values(), Decimal('0'))
all_categories = [{
    'label': category,
    'value': to_float(amount),
    'share': float(amount / last12_total_outflow * 100) if last12_total_outflow else 0,
    'color': category_colors.get(category, '#94a3b8'),
} for category, amount in sorted(category_totals.items(), key=lambda kv: kv[1], reverse=True)]

consumer_exclusions = {'Sparande & investering', 'Swish & överföringar'}
consumer_categories = [item for item in all_categories if item['label'] not in consumer_exclusions]
consumer_total = sum(Decimal(str(item['value'])) for item in consumer_categories)

merchant_totals = defaultdict(Decimal)
merchant_category = {}
for r in last12:
    if r['amount'] < 0 and r['category'] not in consumer_exclusions:
        merchant_totals[r['merchant']] += -r['amount']
        merchant_category[r['merchant']] = r['category']

top_merchants = [{
    'label': merchant,
    'value': to_float(amount),
    'category': merchant_category[merchant],
    'color': category_colors.get(merchant_category[merchant], '#94a3b8'),
} for merchant, amount in sorted(merchant_totals.items(), key=lambda kv: kv[1], reverse=True)[:15]]

month_income = defaultdict(Decimal)
month_outflow = defaultdict(Decimal)
for r in last12:
    key = r['date'].strftime('%Y-%m')
    if r['amount'] >= 0:
        month_income[key] += r['amount']
    else:
        month_outflow[key] += -r['amount']
monthly_cashflow = [{
    'month': month,
    'income': to_float(month_income[month]),
    'outflow': to_float(month_outflow[month]),
} for month in months]

stacked_categories = [item['label'] for item in consumer_categories[:6] if item['label'] != 'Övrigt']
if 'Övrigt' not in stacked_categories:
    stacked_categories.append('Övrigt')
monthly_category_totals = {month: defaultdict(Decimal) for month in months}
for r in last12:
    if r['amount'] >= 0 or r['category'] in consumer_exclusions:
        continue
    key = r['date'].strftime('%Y-%m')
    bucket = r['category'] if r['category'] in stacked_categories[:-1] else 'Övrigt'
    monthly_category_totals[key][bucket] += -r['amount']
monthly_stacked = []
for month in months:
    row = {'month': month}
    for category in stacked_categories:
        row[category] = to_float(monthly_category_totals[month][category])
    monthly_stacked.append(row)

recurring_stats = defaultdict(lambda: {'count': 0, 'months': set(), 'total': Decimal('0'), 'category': None})
for r in last12:
    if r['amount'] >= 0:
        continue
    stats = recurring_stats[r['merchant']]
    stats['count'] += 1
    stats['months'].add(r['date'].strftime('%Y-%m'))
    stats['total'] += -r['amount']
    stats['category'] = r['category']
recurring = []
for merchant, stats in recurring_stats.items():
    if len(stats['months']) >= 6 and stats['count'] >= 6:
        recurring.append({
            'merchant': merchant,
            'category': stats['category'],
            'transactions': stats['count'],
            'months': len(stats['months']),
            'total': to_float(stats['total']),
            'avgMonthly': to_float(stats['total'] / Decimal(len(stats['months']))),
        })
recurring.sort(key=lambda item: item['total'], reverse=True)
recurring = recurring[:14]

insights = []
if all_categories:
    insights.append(f"Storsta utflodet senaste 12 manaderna ar {all_categories[0]['label'].lower()} med cirka {round(all_categories[0]['value']):,} kr.".replace(',', ' '))
if consumer_categories:
    insights.append(f"Nar sparande och överföringar raknas bort ar {consumer_categories[0]['label'].lower()} storst med cirka {round(consumer_categories[0]['value']):,} kr.".replace(',', ' '))
if top_merchants:
    leaders = ', '.join(f"{item['label']} ({round(item['value']):,} kr)".replace(',', ' ') for item in top_merchants[:3])
    insights.append(f"Mest pengar gar till: {leaders}.")
subscriptions = [item for item in recurring if item['category'] == 'Digitalt & abonnemang']
if subscriptions:
    total_subs = sum(Decimal(str(item['total'])) for item in subscriptions)
    insights.append(f"Aterkommande digitala abonnemang uppgar till ungefarligt {round(float(total_subs)):,} kr under 12 manader.".replace(',', ' '))

summary_cards = [
    {'label': 'Analyserad period', 'value': f'{min_date.isoformat()} till {max_date.isoformat()}'},
    {'label': 'Utflode senaste 12 manaderna', 'value': f"{round(float(last12_total_outflow)):,} kr".replace(',', ' ')},
    {'label': 'Konsumtion exkl. sparande/överföringar', 'value': f"{round(float(consumer_total)):,} kr".replace(',', ' ')},
    {'label': 'Snitt per manad (konsumtion)', 'value': f"{round(float(consumer_total) / max(len(months),1)):,} kr".replace(',', ' ')},
]

data = {
    'subtitle': 'Automatisk kategorisering baserad pa transaktionstext. Tolkningen ar heuristisk men tillrackligt bra for att se tydliga monster.',
    'summaryCards': summary_cards,
    'insights': insights,
    'charts': {
        'categoryAll': all_categories,
        'categoryConsumer': consumer_categories,
        'topMerchants': top_merchants,
        'monthlyCashflow': monthly_cashflow,
        'monthlyStacked': monthly_stacked,
        'stackedCategories': stacked_categories,
    },
    'recurring': recurring,
}

html = f"""<!doctype html>
<html lang=\"sv\">
<head>
  <meta charset=\"utf-8\">
  <meta name=\"viewport\" content=\"width=device-width, initial-scale=1\">
  <title>Kontoutdragsanalys</title>
  <style>
    :root {{ color-scheme: light dark; --text: #e5e7eb; --muted: #94a3b8; --border: rgba(148, 163, 184, 0.18); }}
    * {{ box-sizing: border-box; }}
    body {{ margin: 0; font: 15px/1.5 Inter, ui-sans-serif, system-ui, sans-serif; background: linear-gradient(180deg, #020617, #0f172a 26%, #111827); color: var(--text); }}
    .wrap {{ max-width: 1320px; margin: 0 auto; padding: 32px 20px 48px; }}
    h1, h2, p {{ margin: 0; }} h1 {{ font-size: 2rem; margin-bottom: 8px; }} .subtle {{ color: var(--muted); max-width: 920px; }}
    .hero {{ display: grid; gap: 16px; margin-bottom: 24px; }} .cards {{ display: grid; grid-template-columns: repeat(auto-fit, minmax(220px, 1fr)); gap: 14px; margin: 24px 0; }}
    .card, .panel {{ background: rgba(15, 23, 42, 0.72); border: 1px solid var(--border); border-radius: 18px; backdrop-filter: blur(8px); box-shadow: 0 10px 30px rgba(2, 6, 23, 0.35); }}
    .card {{ padding: 18px; }} .card .label {{ font-size: 0.9rem; color: var(--muted); margin-bottom: 8px; }} .card .value {{ font-size: 1.45rem; font-weight: 700; }}
    .insights {{ padding: 18px 20px; margin-bottom: 24px; }} .insights ul {{ margin: 12px 0 0; padding-left: 18px; }}
    .grid {{ display: grid; grid-template-columns: repeat(12, 1fr); gap: 16px; }} .panel {{ padding: 18px; }} .span-6 {{ grid-column: span 6; }} .span-12 {{ grid-column: span 12; }}
    @media (max-width: 960px) {{ .span-6 {{ grid-column: span 12; }} }}
    .panel-header {{ display: flex; justify-content: space-between; gap: 12px; align-items: baseline; margin-bottom: 16px; }} .panel-header h2 {{ font-size: 1.05rem; }} .panel-header .meta {{ color: var(--muted); font-size: 0.9rem; }}
    .bar-list {{ display: grid; gap: 12px; }} .bar-row {{ display: grid; grid-template-columns: minmax(0, 220px) 1fr minmax(90px, auto); gap: 12px; align-items: center; }}
    .bar-label {{ white-space: nowrap; overflow: hidden; text-overflow: ellipsis; color: #e2e8f0; }} .bar-track {{ position: relative; height: 14px; border-radius: 999px; background: rgba(148, 163, 184, 0.14); overflow: hidden; }} .bar-fill {{ position: absolute; inset: 0 auto 0 0; border-radius: 999px; }} .bar-value {{ text-align: right; font-variant-numeric: tabular-nums; color: var(--muted); }}
    svg {{ width: 100%; height: auto; display: block; }} .legend {{ display: flex; flex-wrap: wrap; gap: 10px 14px; margin-top: 12px; }} .legend-item {{ display: inline-flex; align-items: center; gap: 8px; color: var(--muted); font-size: 0.92rem; }} .swatch {{ width: 11px; height: 11px; border-radius: 999px; display: inline-block; }}
    table {{ width: 100%; border-collapse: collapse; font-size: 0.94rem; }} th, td {{ padding: 10px 8px; border-bottom: 1px solid rgba(148, 163, 184, 0.12); text-align: left; }} th {{ color: var(--muted); font-weight: 600; }} td.num {{ text-align: right; font-variant-numeric: tabular-nums; }} .footnote {{ color: var(--muted); font-size: 0.88rem; margin-top: 18px; }}
  </style>
</head>
<body>
  <div class=\"wrap\">
    <section class=\"hero\">
      <div><h1>Vad pengarna gar till</h1><p class=\"subtle\">Analysen bygger pa <strong>{len(rows)}</strong> transaktioner i perioden <strong>{min_date.isoformat()}</strong> till <strong>{max_date.isoformat()}</strong>. Graferna fokuserar pa senaste 12 manaderna for att ge en mer relevant bild av ditt nuvarande beteende.</p></div>
      <p class=\"subtle\">{data['subtitle']}</p>
    </section>
    <section class=\"cards\" id=\"summary-cards\"></section>
    <section class=\"panel insights\"><h2>Det som sticker ut</h2><ul id=\"insight-list\"></ul></section>
    <section class=\"grid\">
      <article class=\"panel span-6\"><div class=\"panel-header\"><h2>Utfloden per kategori</h2><div class=\"meta\">Senaste 12 manaderna</div></div><div id=\"category-all\" class=\"bar-list\"></div></article>
      <article class=\"panel span-6\"><div class=\"panel-header\"><h2>Konsumtion per kategori</h2><div class=\"meta\">Exklusive sparande och överföringar</div></div><div id=\"category-consumer\" class=\"bar-list\"></div></article>
      <article class=\"panel span-6\"><div class=\"panel-header\"><h2>Manad for manad: in vs ut</h2><div class=\"meta\">Senaste 12 manaderna</div></div><svg id=\"cashflow-chart\" viewBox=\"0 0 760 320\"></svg><div class=\"legend\" id=\"cashflow-legend\"></div></article>
      <article class=\"panel span-6\"><div class=\"panel-header\"><h2>Hur konsumtionen fordlar sig over tid</h2><div class=\"meta\">Stackade manadsstaplar</div></div><svg id=\"stacked-chart\" viewBox=\"0 0 760 320\"></svg><div class=\"legend\" id=\"stacked-legend\"></div></article>
      <article class=\"panel span-12\"><div class=\"panel-header\"><h2>Storst mottagare av pengar</h2><div class=\"meta\">Senaste 12 manaderna, exklusive sparande och överföringar</div></div><div id=\"top-merchants\" class=\"bar-list\"></div></article>
      <article class=\"panel span-12\"><div class=\"panel-header\"><h2>Aterkommande dragningar</h2><div class=\"meta\">Mottagare med minst 6 manader och 6 transaktioner</div></div><table><thead><tr><th>Mottagare</th><th>Kategori</th><th class=\"num\">Antal</th><th class=\"num\">Manader</th><th class=\"num\">Summa</th><th class=\"num\">Snitt/manad</th></tr></thead><tbody id=\"recurring-body\"></tbody></table><p class=\"footnote\">Swish-liknande nummer, sparande och vissa egna överföringar kan se ut som kostnader i ett kontoutdrag. Darfor visar rapporten bade totalbilden och en konsumtionsvy dar sparande/överföringar har lyfts bort.</p></article>
    </section>
  </div>
  <script id=\"report-data\" type=\"application/json\">{json.dumps(data, ensure_ascii=False)}</script>
  <script>
    const DATA = JSON.parse(document.getElementById('report-data').textContent);
    const money = new Intl.NumberFormat('sv-SE', {{ maximumFractionDigits: 0 }});
    const formatKr = value => `${{money.format(Math.round(value))}} kr`;
    document.getElementById('summary-cards').innerHTML = DATA.summaryCards.map(card => `<div class=\"card\"><div class=\"label\">${{card.label}}</div><div class=\"value\">${{card.value}}</div></div>`).join('');
    document.getElementById('insight-list').innerHTML = DATA.insights.map(item => `<li>${{item}}</li>`).join('');
    function renderBarList(id, items, showShare = true) {{ const root = document.getElementById(id); const max = Math.max(...items.map(item => item.value), 1); root.innerHTML = items.map(item => `<div class=\"bar-row\"><div class=\"bar-label\" title=\"${{item.label}}\">${{item.label}}</div><div class=\"bar-track\"><div class=\"bar-fill\" style=\"width:${{(item.value / max) * 100}}%; background:${{item.color}}\"></div></div><div class=\"bar-value\">${{formatKr(item.value)}}${{showShare && item.share ? ` · ${{item.share.toFixed(1)}} %` : ''}}</div></div>`).join(''); }}""" + """
    function polylinePoints(values, width, height, left, top, max) {{ const step = values.length > 1 ? width / (values.length - 1) : width; return values.map((value, index) => `${{left + index * step}},${{top + height - (value / max) * height}}`).join(' '); }}
    function renderCashflowChart() {{ const svg = document.getElementById('cashflow-chart'); const data = DATA.charts.monthlyCashflow; const width = 760, height = 320, left = 56, right = 18, top = 20, bottom = 48; const innerW = width - left - right; const innerH = height - top - bottom; const max = Math.max(...data.flatMap(d => [d.income, d.outflow]), 1); const step = data.length > 1 ? innerW / (data.length - 1) : innerW; const ticks = [0, 0.25, 0.5, 0.75, 1].map(f => { const y = top + innerH - innerH * f; return `<line x1=\"${{left}}\" y1=\"${{y}}\" x2=\"${{width - right}}\" y2=\"${{y}}\" stroke=\"rgba(148,163,184,0.18)\" /><text x=\"${{left - 8}}\" y=\"${{y + 4}}\" text-anchor=\"end\" fill=\"#94a3b8\" font-size=\"11\">${{Math.round((max * f) / 1000)}}k</text>`; }).join(''); const labels = data.map((row, i) => `<text x=\"${{left + i * step}}\" y=\"${{height - 16}}\" text-anchor=\"middle\" fill=\"#94a3b8\" font-size=\"11\">${{row.month.slice(2)}}</text>`).join(''); const points = data.map((row, i) => { const x = left + i * step; const incomeY = top + innerH - (row.income / max) * innerH; const outflowY = top + innerH - (row.outflow / max) * innerH; return `<circle cx=\"${{x}}\" cy=\"${{incomeY}}\" r=\"4\" fill=\"#22c55e\"><title>${{row.month}} inkomster: ${{formatKr(row.income)}}</title></circle><circle cx=\"${{x}}\" cy=\"${{outflowY}}\" r=\"4\" fill=\"#f97316\"><title>${{row.month}} utfloden: ${{formatKr(row.outflow)}}</title></circle>`; }).join(''); svg.innerHTML = `${{ticks}}<polyline fill=\"none\" stroke=\"#22c55e\" stroke-width=\"3\" points=\"${{polylinePoints(data.map(d => d.income), innerW, innerH, left, top, max)}}\"></polyline><polyline fill=\"none\" stroke=\"#f97316\" stroke-width=\"3\" points=\"${{polylinePoints(data.map(d => d.outflow), innerW, innerH, left, top, max)}}\"></polyline>${{points}}${{labels}}`; document.getElementById('cashflow-legend').innerHTML = '<span class=\"legend-item\"><span class=\"swatch\" style=\"background:#22c55e\"></span>Inkomster</span><span class=\"legend-item\"><span class=\"swatch\" style=\"background:#f97316\"></span>Utfloden</span>'; }}
    function renderStackedChart() {{ const svg = document.getElementById('stacked-chart'); const rows = DATA.charts.monthlyStacked; const categories = DATA.charts.stackedCategories; const width = 760, height = 320, left = 48, right = 16, top = 20, bottom = 48; const innerW = width - left - right; const innerH = height - top - bottom; const totals = rows.map(row => categories.reduce((sum, category) => sum + (row[category] || 0), 0)); const max = Math.max(...totals, 1); const band = innerW / rows.length; const barW = Math.max(18, band - 10); let bars = ''; rows.forEach((row, i) => {{ const x = left + i * band + (band - barW) / 2; let currentTop = top + innerH; categories.forEach(category => {{ const value = row[category] || 0; if (!value) return; const match = DATA.charts.categoryConsumer.find(item => item.label === category) || DATA.charts.categoryAll.find(item => item.label === category) || {{ color: '#94a3b8' }}; const h = (value / max) * innerH; currentTop -= h; bars += `<rect x=\"${{x}}\" y=\"${{currentTop}}\" width=\"${{barW}}\" height=\"${{h}}\" rx=\"4\" fill=\"${{match.color}}\"><title>${{row.month}} · ${{category}}: ${{formatKr(value)}}</title></rect>`; }}); bars += `<text x=\"${{x + barW / 2}}\" y=\"${{height - 16}}\" text-anchor=\"middle\" fill=\"#94a3b8\" font-size=\"11\">${{row.month.slice(2)}}</text>`; }}); const ticks = [0, 0.25, 0.5, 0.75, 1].map(f => {{ const y = top + innerH - innerH * f; return `<line x1=\"${{left}}\" y1=\"${{y}}\" x2=\"${{width - right}}\" y2=\"${{y}}\" stroke=\"rgba(148,163,184,0.18)\" /><text x=\"${{left - 8}}\" y=\"${{y + 4}}\" text-anchor=\"end\" fill=\"#94a3b8\" font-size=\"11\">${{Math.round((max * f) / 1000)}}k</text>`; }}).join(''); svg.innerHTML = ticks + bars; document.getElementById('stacked-legend').innerHTML = categories.map(category => {{ const match = DATA.charts.categoryConsumer.find(item => item.label === category) || DATA.charts.categoryAll.find(item => item.label === category) || {{ color: '#94a3b8' }}; return `<span class=\"legend-item\"><span class=\"swatch\" style=\"background:${{match.color}}\"></span>${{category}}</span>`; }}).join(''); }}
    document.getElementById('recurring-body').innerHTML = DATA.recurring.map(row => `<tr><td>${{row.merchant}}</td><td>${{row.category}}</td><td class=\"num\">${{row.transactions}}</td><td class=\"num\">${{row.months}}</td><td class=\"num\">${{formatKr(row.total)}}</td><td class=\"num\">${{formatKr(row.avgMonthly)}}</td></tr>`).join('');
    renderBarList('category-all', DATA.charts.categoryAll); renderBarList('category-consumer', DATA.charts.categoryConsumer); renderBarList('top-merchants', DATA.charts.topMerchants, false); renderCashflowChart(); renderStackedChart();
  </script>
</body>
</html>
"""

html_path.write_text(html, encoding='utf-8')
print(f'Wrote: {html_path}')
print(f'Rows analyzed: {len(rows)}')
print(f'Period: {min_date} -> {max_date}')
print(f'Last 12 months outflow: {round(float(last12_total_outflow)):,} kr'.replace(',', ' '))
print(f'Consumer spend ex savings/transfers: {round(float(consumer_total)):,} kr'.replace(',', ' '))
print('Top 5 categories last 12 months:')
for item in all_categories[:5]:
    print(f"  - {item['label']}: {round(item['value']):,} kr ({item['share']:.1f}%)".replace(',', ' '))
print('Top 5 consumer merchants:')
for item in top_merchants[:5]:
    print(f"  - {item['label']}: {round(item['value']):,} kr [{item['category']}]".replace(',', ' '))
