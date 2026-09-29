import io,re,sqlite3,hashlib,json,subprocess,collections,sys
from decimal import Decimal
import pdfplumber
import datetime
from pathlib import Path

def words_text(words):
    return ' '.join(w['text'] for w in sorted(words,key=lambda w:w['x0'])).replace('(cid:9)',' ')
def lines_for(page):
    lines=[]
    for w in sorted(page.extract_words(),key=lambda w:(w['top'],w['x0'])):
        if not lines or abs(lines[-1][0]-w['top'])>2:lines.append((w['top'],[w]))
        else:lines[-1][1].append(w)
    return [(top,sorted(words,key=lambda w:w['x0'])) for top,words in lines]
M=r'-?(?:\d+|\d{1,3}(?:,\d{3})+|\d{1,2}(?:,\d{2})*,\d{3})\.\d{2}'
def amount(v):
    assert re.fullmatch(M,v), 'invalid Money grammar'
    return Decimal(v.replace(',',''))
def axis_oracle(blob,pw):
    result=[];active=None;columns=None;pending=None;closed=False;currencies=collections.defaultdict(set)
    with pdfplumber.open(io.BytesIO(blob),password=pw or None) as pdf:
        for pi,page in enumerate(pdf.pages,1):
            previousColumns=columns
            columns=None
            for top,words in lines_for(page):
                text=words_text(words)
                if re.search(r'\bINR\b',text):
                    for mask in re.findall(r'\b[0-9X]{15}\b',text):
                        if 'X' in mask:currencies[mask].add('INR')
                heading=re.search(r'Statement\s+for\s+[Aa]ccount\s+[Nn]o\.\s+(\S+)\s+for\s+the\s+period\s+from\s+(\d{2}-\d{2}-\d{4})\s+to\s+(\d{2}-\d{2}-\d{4})',text)
                if heading:
                    identity,start,end=heading.groups()
                    if active is None:
                        active={'account':identity,'start':start,'end':end,'product':None,'rows':[],'opening':None,'closing':None,'total':None,'pages':[pi]}
                        result.append(active);pending=None;closed=False
                    else:
                        assert (identity,start,end)==(active['account'],active['start'],active['end']),'unclosed account section'
                        active['pages'].append(pi)
                    columns=None;continue
                if active is None:continue
                if 'Scheme' in text and re.search(r'[Nn]ame:',text):
                    value=re.split(r'Scheme\s+[Nn]ame:\s*',text)[-1].split('Joint')[0].strip()
                    assert active['product'] in (None,value),'changed scheme'
                    active['product']=value;continue
                if all(label in text.lower() for label in ('withdrawal','deposits','balance','date','transaction')):
                    def head(token):
                        return next(w for w in words if w['text'].lower().startswith(token))
                    mid=sum(w['top']+w['bottom'] for w in words)/(2*len(words))
                    raw_edges=sorted(edge['x0'] for edge in page.edges if edge['orientation']=='v' and edge['top']<=mid<=edge['bottom'])
                    clusters=[]
                    for x in raw_edges:
                        if not clusters or x-clusters[-1][-1]>1.5:clusters.append([x])
                        else:clusters[-1].append(x)
                    edges=[sum(c)/len(c) for c in clusters]
                    centers=[(head(k)['x0']+head(k)['x1'])/2 for k in ('date','transaction','chq','withdrawal','deposits','balance')]
                    slots=[next((j for j in range(len(edges)-1) if edges[j]<center<edges[j+1]),None) for center in centers]
                    assert all(x is not None for x in slots) and slots==list(range(slots[0],slots[0]+6)), 'header grid ownership'
                    edges=edges[slots[0]:slots[0]+7]
                    columns={'edges':edges,'dateEnd':edges[1],'narrationEnd':edges[2],
                             'moneyRight':edges[4:7],'chequeEnd':edges[3]}
                    continue
                if columns is None and previousColumns is not None and text.startswith('Closing Balance'):
                    columns=previousColumns
                if columns is None:continue
                if 'Opening Balance' in text:
                    vals=[w['text'] for w in words if re.fullmatch(M,w['text']) and columns['edges'][5]<(w['x0']+w['x1'])/2<columns['edges'][6]]
                    assert len(vals)==1 and active['opening'] in (None,vals[0]),'opening ownership'
                    active['opening']=vals[0];continue
                if 'Closing Balance' in text:
                    vals=[w['text'] for w in words if re.fullmatch(M,w['text']) and columns['edges'][5]<(w['x0']+w['x1'])/2<columns['edges'][6]]
                    assert len(vals)==1,'closing ownership'
                    active['closing']=vals[0];active['lastPage']=pi;closed=True;pending=None;continue
                if text.startswith('Total'):
                    assert closed,'total before closing'
                    active['total']=[w['text'] for w in words if re.fullmatch(M,w['text'])]
                    assert len(active['total'])==2,'totals ownership'
                    active=None;pending=None;columns=None;continue
                if closed:continue
                date_words=[w for w in words if w['x0']<columns['dateEnd'] and re.fullmatch(r'\d{2}-\d{2}-\d{4}',w['text'])]
                money=[w for w in words if re.fullmatch(M,w['text']) and w['x0']>=columns['chequeEnd']]
                assigned={}
                for w in money:
                    midpoint=(w['x0']+w['x1'])/2
                    slot=next((j for j in range(3) if columns['edges'][j+3]<midpoint<columns['edges'][j+4]),None)
                    assert slot is not None,'unaligned financial cell'
                    assert slot not in assigned,'duplicate financial cell'
                    assigned[slot]=w['text']
                narration=[w for w in words if columns['dateEnd']<=w['x0']<columns['narrationEnd']]
                cheques=[w for w in words if columns['narrationEnd']<=w['x0']<columns['chequeEnd'] and w not in money]
                if date_words:
                    assert len(date_words)==1 and 2 in assigned,'incomplete dated row'
                    debit=amount(assigned.get(0,'0.00'));credit=amount(assigned.get(1,'0.00'))
                    assert (debit>0) != (credit>0) and debit>=0 and credit>=0,'ambiguous amount side'
                    pending={'date':date_words[0]['text'],'valueDate':None,'page':pi,'narration':[],'cheque':[],
                             'withdrawal':assigned.get(0),'deposit':assigned.get(1),'balance':assigned[2],'signed':str(credit-debit)}
                    active['rows'].append(pending)
                else:
                    assert not assigned,'orphan monetary row'
                if pending:
                    if narration:pending['narration'].append(words_text(narration))
                    if cheques:pending['cheque'].append(words_text(cheques))
    assert active is None and result,'unclosed original'
    for section in result:
        assert currencies[section['account']]=={'INR'},'account currency observation'
        section['currency']='INR'
        assert section['product'] and section['opening'] is not None and section['closing'] is not None
        for row in section['rows']:assert row['narration'],'missing narration'
    return result


def grid_edges(page,words,role_tokens):
    mid=sum(w['top']+w['bottom'] for w in words)/(2*len(words))
    raw_edges=sorted(edge['x0'] for edge in page.edges if edge['orientation']=='v' and edge['top']<=mid<=edge['bottom'])
    clusters=[]
    for x in raw_edges:
        if not clusters or x-clusters[-1][-1]>1.5:clusters.append([x])
        else:clusters[-1].append(x)
    edges=[sum(c)/len(c) for c in clusters]
    centers=[]
    for token in role_tokens:
        w=next(w for w in words if w['text'].lower().startswith(token))
        centers.append((w['x0']+w['x1'])/2)
    slots=[next((j for j in range(len(edges)-1) if edges[j]<center<edges[j+1]),None) for center in centers]
    assert all(x is not None for x in slots) and slots==list(range(slots[0],slots[0]+len(role_tokens))), 'header grid ownership'
    return edges[slots[0]:slots[0]+len(role_tokens)+1]
def hdfc_oracle(blob,pw):
    sections=[];active=None
    with pdfplumber.open(io.BytesIO(blob),password=pw or None) as pdf:
        for pi,page in enumerate(pdf.pages,1):
            lines=lines_for(page)
            flat='\n'.join(words_text(w) for _,w in lines)
            account=re.search(r'Account Number\s*:\s*(\d{14})\b',flat)
            if not account:continue
            identity=account.group(1)
            metadata='\n'.join(words_text([w for w in words if w['x0']<page.width/2]) for top,words in lines)
            product=re.search(r'Account Type\s*:\s*(.+)',metadata).group(1).strip()
            dates=re.search(r'Statement From\s*:\s*(\d{2}/\d{2}/\d{4})\s+To\s+(\d{2}/\d{2}/\d{4})',metadata).groups()
            currency=re.search(r'Currency\s*:\s*(\w{3})',metadata).group(1)
            opening=re.search(r'Opening Balance\s*:\s*('+M+')',metadata).group(1)
            if active is None or active['account']!=identity:
                assert not any(s['account']==identity for s in sections),'noncontiguous account'
                active={'account':identity,'product':product,'start':dates[0],'end':dates[1],'currency':currency,'opening':opening,'rows':[],'pages':[],'summary':None}
                sections.append(active)
            else:
                assert (active['product'],active['start'],active['end'],active['currency'],active['opening'])==(product,*dates,currency,opening),'continuation identity changed'
            active['pages'].append(pi)
            headers=[(t,w) for t,w in lines if 'Txn Date Narration Withdrawals Deposits Closing Balance'==words_text(w)]
            assert len(headers)<=1,'ambiguous HDFC table'
            summary_heads=[i for i,(_,w) in enumerate(lines) if words_text(w)=='Opening Balance Debit Amount Credit Amount Closing Balance']
            assert len(summary_heads)<=1,'ambiguous HDFC summary'
            if summary_heads:
                si=summary_heads[0]
                vals=[w['text'] for w in lines[si+1][1] if re.fullmatch(M,w['text'])]
                assert len(vals)==4,'HDFC summary amounts'
                assert words_text(lines[si+2][1])=='Debit Count Credit Count','HDFC summary count labels'
                cs=[w['text'] for w in lines[si+3][1] if re.fullmatch(r'\d+',w['text'])]
                assert len(cs)==2,'HDFC summary counts'
                active['summary']={'opening':vals[0],'debits':vals[1],'credits':vals[2],'closing':vals[3],'debitCount':int(cs[0]),'creditCount':int(cs[1])}
            if not headers:
                assert active['summary'] is not None and active['summary']['debitCount']==0 and active['summary']['creditCount']==0 and not active['rows'],'unproven empty section'
                continue
            top,header=headers[0]
            edges=grid_edges(page,header,('txn','narration','withdrawals','deposits','closing'))
            containers=[r for r in page.rects if abs(r['x0']-edges[0])<2 and abs(r['x1']-edges[-1])<2 and r['top']<=top<r['bottom']]
            assert containers,'missing table rectangle'
            bottom=max(r['bottom'] for r in containers)
            current=active['rows'][-1] if active['rows'] else None
            for t,words in lines:
                if t<=top+2 or t>=bottom:continue
                cols=[[w for w in words if edges[k]<(w['x0']+w['x1'])/2<edges[k+1]] for k in range(5)]
                starts=[w for w in cols[0] if re.fullmatch(r'\d{2}/\d{2}/\d{4}',w['text'])]
                vals=[[w['text'] for w in group if re.fullmatch(M,w['text'])] for group in cols[2:]]
                if starts:
                    assert len(starts)==1 and all(len(v)==1 for v in vals),'HDFC incomplete row'
                    dv,cv,bv=[v[0] for v in vals]
                    debit,credit=amount(dv),amount(cv)
                    assert (debit>0)!=(credit>0) and debit>=0 and credit>=0,'HDFC amount ambiguity'
                    current={'date':starts[0]['text'],'page':pi,'narration':[],'withdrawal':dv,'deposit':cv,'balance':bv,'signed':str(credit-debit)}
                    active['rows'].append(current)
                else:
                    assert not any(vals),'HDFC orphan financial cells'
                assert not cols[0] or starts,'HDFC unexplained date cell'
                if cols[1]:
                    assert current is not None,'HDFC orphan narration'
                    current['narration'].append(words_text(cols[1]))
    assert len(sections)==2,'HDFC account section set'
    for s in sections:
        for row in s['rows']:
            narration=' '.join(row['narration'])
            ds=re.findall(r'Value\s*Dt\s*(\d{2}/\d{2}/\d{4})',narration)
            assert len(ds)==1,'HDFC missing or multiple value date'
            row['valueDate']=ds[0]
            ref=re.search(r'\bRef\s+(.+)$',narration)
            row['reference']=ref.group(1) if ref else None
    return sections


def standalone_hdfc_oracle(path, password):
    blob = path.read_bytes()
    rows, edges, account, current = [], None, None, None
    closed = False
    with pdfplumber.open(io.BytesIO(blob), password=password) as pdf:
        for page_number, page in enumerate(pdf.pages, 1):
            if closed:
                break
            lines = lines_for(page)
            flat = '\n'.join(words_text(words) for _, words in lines)
            identity = re.search(r'AccountNo\s*:\s*(\d{14})', flat).group(1)
            assert account in (None, identity)
            account = identity
            headers = [(top, words) for top, words in lines if 'Narration' in words_text(words) and 'Chq.' in words_text(words)]
            if headers:
                edges = grid_edges(page, headers[0][1], ('date', 'narration', 'chq.', 'valuedt', 'withdrawal', 'deposit', 'closing'))
            assert edges is not None
            borders = [rect for rect in page.rects if rect['width'] > 500 and rect['height'] < 1 and rect['top'] > 220]
            top, bottom = min(r['top'] for r in borders), max(r['bottom'] for r in borders)
            summaries = [y for y, words in lines if 'STATEMENTSUMMARY' in words_text(words)]
            if summaries:
                bottom, closed = min(bottom, summaries[0]), True
            for y, words in lines:
                if not top < y < bottom or (headers and abs(y - headers[0][0]) < 2):
                    continue
                cols = [words_text([w for w in words if edges[k] < (w['x0'] + w['x1']) / 2 < edges[k + 1]]) for k in range(7)]
                if re.fullmatch(r'\d{2}/\d{2}/\d{2}', cols[0]):
                    assert re.fullmatch(r'\d{2}/\d{2}/\d{2}', cols[3]), 'date roles'
                    debit, credit = [Decimal(v.replace(',', '')) if v else Decimal('0') for v in cols[4:6]]
                    assert (debit > 0) != (credit > 0)
                    current = dict(date=iso_date(cols[0]), valueDate=iso_date(cols[3]), signed=credit-debit,
                                   balance=Decimal(cols[6].replace(',', '')), reference=cols[2], narration=[cols[1]],
                                   account=account, ordinal=len(rows)+1, page=page_number, source=path.name)
                    rows.append(current)
                elif current is not None:
                    assert not any(cols[k] for k in [0, 3, 4, 5, 6]), 'unexplained non-narration cell'
                    if cols[1]: current['narration'].append(cols[1])
                    if cols[2]: current['reference'] += cols[2]
    assert closed
    return dict(sha256=hashlib.sha256(blob).hexdigest(), name=path.name, rows=rows)


def standalone_axis_oracles(password):
    sources, all_rows = [], []
    for path in sorted(Path('/Users/vyom/Documents/Ledger Forge/Originals/Axis/Bank Accounts').glob('*.pdf')):
        blob = path.read_bytes()
        rows, edges, identity = [], None, None
        with pdfplumber.open(io.BytesIO(blob), password=password) as pdf:
            for page_number, page in enumerate(pdf.pages, 1):
                lines = lines_for(page)
                flat = '\n'.join(words_text(words) for _, words in lines)
                if page_number == 1:
                    match = re.search(r'Statement\s+of\s+Axis\s+Account\s+No:\s*(\d{15})', flat)
                    assert match, 'standalone Axis identity'
                    identity = match.group(1)
                for _, words in lines:
                    if 'Particulars' in words_text(words):
                        edges = grid_edges(page, words, ('tran', 'chq', 'particulars', 'debit', 'credit', 'balance', 'init.'))
                assert edges is not None
                dates = [w for w in page.extract_words() if edges[0] < (w['x0']+w['x1'])/2 < edges[1] and re.fullmatch(r'\d{2}-\d{2}-\d{4}', w['text'])]
                for word in dates:
                    cells = [r for r in page.rects if abs(r['x0']-edges[0]) < 1 and abs(r['x1']-edges[1]) < 1 and r['top'] < (word['top']+word['bottom'])/2 < r['bottom']]
                    assert len(cells) == 1, 'Axis date cell ownership'
                    cell = cells[0]
                    columns = []
                    for column in range(7):
                        parts = [words_text([w for w in words if edges[column] < (w['x0']+w['x1'])/2 < edges[column+1]]) for top, words in lines if cell['top'] < top < cell['bottom']]
                        columns.append(' '.join(p for p in parts if p))
                    assert columns[0] == word['text']
                    debit, credit = [Decimal(v.replace(',', '')) if v else Decimal('0') for v in columns[3:5]]
                    assert (debit > 0) != (credit > 0), 'Axis standalone amount side'
                    rows.append(dict(date=datetime.datetime.strptime(columns[0], '%d-%m-%Y').date().isoformat(), signed=credit-debit, balance=Decimal(columns[5].replace(',', '')), reference=columns[1] or None, narration=columns[2], account=identity, ordinal=len(rows)+1, page=page_number, source=path.name))
        sources.append(dict(sha256=hashlib.sha256(blob).hexdigest(), name=path.name, rows=rows))
        all_rows.extend(rows)
    assert len(all_rows) == 182
    return sources

def iso_date(value):
    pattern = '%d-%m-%Y' if '-' in value else ('%d/%m/%y' if len(value) == 8 else '%d/%m/%Y')
    return datetime.datetime.strptime(value, pattern).date().isoformat()

def overlap_proofs(relationships, passwords):
    originals = standalone_axis_oracles(passwords['axis'])
    for original in originals: original['family'] = 'axis'
    hdfc = [standalone_hdfc_oracle(path, passwords['hdfc']) for path in sorted(Path('/Users/vyom/Documents/Ledger Forge/Originals/HDFC').glob('*.pdf'))]
    assert sorted(len(s['rows']) for s in hdfc) == [8,19,62,76]
    for original in hdfc: original['family'] = 'hdfc'
    originals += hdfc
    rows = []
    for original in originals:
        for row in original['rows']:
            row['sha256'] = original['sha256']; row['family'] = original['family']; rows.append(row)
    links, used, counts = [], set(), []
    for original in relationships:
        matched, outside, conflicts = 0,0,0
        for section_index, section in enumerate(original['sections'],1):
            positions = []
            for index,row in enumerate(section['rows'],1):
                identity = section['account']
                candidates = [r for r in rows if r['family']==original['family'] and len(identity)==len(r['account']) and all(a=='X' or a==b for a,b in zip(identity,r['account'])) and r['date']==iso_date(row['date']) and r.get('valueDate')==(iso_date(row['valueDate']) if row.get('valueDate') else None) and r['signed']==Decimal(row['signed'])]
                if not candidates: outside+=1; continue
                exact = [r for r in candidates if r['balance']==Decimal(row['balance'].replace(',',''))]
                if not exact:
                    conflicts+=1
                    for r in candidates:
                        links.append(dict(relationshipSHA=original['sha256'],sectionOrdinal=section_index,occurrenceIndex=index,standaloneSHA=r['sha256'],standaloneOrdinal=r['ordinal'],conflict=True))
                    continue
                remaining = [r for r in exact if (r['sha256'],r['ordinal']) not in used]
                assert remaining, 'counterpart multiplicity excess'
                chosen=remaining[0]; used.add((chosen['sha256'],chosen['ordinal']))
                positions.append((chosen['sha256'],chosen['ordinal']))
                left = ' '.join(row['cheque']) or None if original['family']=='axis' else row['reference']
                right = chosen['reference']
                reference_agrees = left==right
                if original['family']=='hdfc' and not reference_agrees:
                    reference_agrees = ((left is None and right=='000000000000000') or
                        (left is not None and re.fullmatch(r'(?:[0-9]{4}|[0-9]{12})',left) and right==left.zfill(16)) or
                        (left is not None and re.fullmatch(r'I[0-9]{11}',left) and right=='0000'+left) or
                        (left is None and re.fullmatch(r'(?:HDFCR5|HDFCN5|FDRLN5)[0-9]{16}',right) and re.match(r'(?:RTGS|NEFT)\s+(?:Dr|Cr)-',row['narration'][0]) and right in re.sub(r'\s+','', ' '.join(row['narration']))))
                assert reference_agrees, 'unproved reference representation'
                links.append(dict(relationshipSHA=original['sha256'],sectionOrdinal=section_index,occurrenceIndex=index,standaloneSHA=chosen['sha256'],standaloneOrdinal=chosen['ordinal'],conflict=False))
                matched+=1
            for sha in {p[0] for p in positions}:
                order=[p[1] for p in positions if p[0]==sha]
                assert order==sorted(order), 'counterpart order differs'
        counts.append(dict(sha256=original['sha256'],matched=matched,outside=outside,conflicts=conflicts))
    assert sum(c['matched'] for c in counts)==314 and sum(c['conflicts'] for c in counts)==33
    return dict(standalone=[dict(sha256=s['sha256'],family=s['family'],rowCount=len(s['rows'])) for s in originals],relationships=counts,links=links)

def main():
    request = json.load(sys.stdin)
    selected = request["sources"]
    passwords = {}
    result = []
    connection = sqlite3.connect("file:" + request["databasePath"] + "?mode=ro", uri=True)
    current_sha = ""
    try:
        for source in selected:
            current_sha = source["sha256"]
            family = source["family"]
            assert family in ("axis", "hdfc"), "unknown family"
            if family not in passwords:
                scope = "axis-bank" if family == "axis" else "hdfc-bank"
                credential = subprocess.run(["security", "find-generic-password", "-s",
                    "com.ledgerforge.statement-password", "-a", scope, "-w"],
                    stdout=subprocess.PIPE, stderr=subprocess.DEVNULL)
                assert credential.returncode == 0, "existing credential unavailable"
                passwords[family] = credential.stdout.decode().strip()
            row = connection.execute("SELECT original_bytes,byte_count FROM gmail_originals WHERE sha256=?",
                                     (current_sha,)).fetchone()
            assert row is not None, "original unavailable"
            blob, size = row
            assert len(blob) == size and hashlib.sha256(blob).hexdigest() == current_sha, "original integrity"
            sections = axis_oracle(blob, passwords[family]) if family == "axis" else hdfc_oracle(blob, passwords[family])
            result.append({"sha256": current_sha, "family": family, "sections": sections})
        json.dump({"method": "independent PDFPlumber drawn-grid and source-word oracle",
                   "version": pdfplumber.__version__, "sources": result,
                   "overlap": overlap_proofs(result, passwords) if request.get("includeOverlap") else None}, sys.stdout)
    except Exception as error:
        json.dump({"failedSource": current_sha, "errorType": type(error).__name__}, sys.stdout)
        raise SystemExit(2)
    finally:
        connection.close()
        passwords.clear()

if __name__ == "__main__":
    main()
