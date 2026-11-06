"""Mock of NectarLink's /v1/notifications API with groups, Live Updates, one-time codes, replies. Records every POST in the log file given as argv[1]. Run it with NECTARLINK_DATA pointing at a folder holding api-token.json {"port":53399,"token":"<64 chars>"}."""
import json, sys, time, threading, copy
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import urlparse, parse_qs
PORT=53399; LOG=sys.argv[1]
DEV="mockdevice0000000000000000000000000000000000000000000000000000"
now=int(time.time()*1000)
def n(key,app,name,title,text,**k):
    d=dict(deviceId=DEV,deviceName="Mock Phone",key=key,app=app,appName=name,title=title,text=text,sub="",when=now-60000,iconUrl="",imageUrl="",
      actions=[],replyAction="",replyLabel="",silent=False,ongoing=False,replies=[],otpCode="",live=None,conversation=None,
      groupCount=1,groupIndex=0,groupExpanded=False,groupSummary="")
    d.update(k); return d
ITEMS=[
 n("live1","com.ride","Rides","Driver arriving","Toyota Corolla · 4 min",when=now-120000,live=dict(progress=60,max=100,indeterminate=False,chip="4 min",segments=[],points=[],chronometer=True,countdown=True,when=now+240000),ongoing=True),
 n("wa1","com.whatsapp","WhatsApp","Dure Kafian","H",when=now-5000,replyAction="0",replyLabel="Reply",actions=[dict(id="1",title="Mark as read")],replies=[dict(text="On my way",pending=False)]),
 n("g1","com.google","Google","How-To Geek","I'm tired of AI companies calling their models open source when they aren't",when=now-3600000,actions=[dict(id="a",title="Interested"),dict(id="b",title="Not interested")]),
 n("m1","com.samsung.android.messaging","Messages","JazzCash","Use code 481516 to confirm. Muft Rs 80 ke liye tayar?",when=now-900000,otpCode="481516"),
 n("t1","com.telegram","Telegram","Ali","hey",when=now-300000,groupCount=3,groupIndex=0,groupSummary="Sara · Group chat",replyAction="r",replyLabel="Reply"),
]
EXTRA=[ n("t2","com.telegram","Telegram","Sara","call me",when=now-400000,groupCount=3,groupIndex=1,groupExpanded=True),
        n("t3","com.telegram","Telegram","Group chat","3 new messages",when=now-500000,groupCount=3,groupIndex=2,groupExpanded=True)]
STATE=dict(rev=1,expanded=False,items=copy.deepcopy(ITEMS),undo="",last=[],rules={"com.whatsapp":"show","com.telegram":"show","com.google":"show"})
LOCK=threading.Condition()
def feed():
    items=[]
    for it in STATE["items"]:
        it=copy.deepcopy(it)
        if it["app"]=="com.telegram" and it["groupCount"]>=1 and it["groupIndex"]==0:
            it["groupExpanded"]=STATE["expanded"]
        items.append(it)
        if it["app"]=="com.telegram" and it["groupIndex"]==0 and STATE["expanded"]:
            items+= [copy.deepcopy(e) for e in EXTRA]
    vis=[i for i in items if STATE["rules"].get(i["app"],"show")!="hidden"]
    count=sum(i["groupCount"] for i in vis if i["groupIndex"]==0)
    return dict(ok=True,rev=STATE["rev"],count=count,undoLabel=STATE["undo"],historyEnabled=True,online={DEV:True},items=vis)
def bump():
    with LOCK: STATE["rev"]+=1; LOCK.notify_all()
class H(BaseHTTPRequestHandler):
    def log_message(self,*a): pass
    def send(self,obj,code=200):
        b=json.dumps(obj).encode(); self.send_response(code); self.send_header("Content-Type","application/json"); self.send_header("Content-Length",str(len(b))); self.end_headers(); self.wfile.write(b)
    def do_GET(self):
        u=urlparse(self.path); q=parse_qs(u.query)
        if u.path=="/v1/notifications":
            since=int(q.get("since",["0"])[0]); wait=int(q.get("wait",["0"])[0])
            if wait and since==STATE["rev"]:
                with LOCK: LOCK.wait_for(lambda:STATE["rev"]!=since,timeout=min(wait,55))
            return self.send(feed())
        if u.path=="/v1/notifications/history":
            qq=(q.get("q",[""])[0]).lower()
            h=[dict(deviceId=DEV,deviceName="Mock Phone",key="h%d"%i,app="com.whatsapp",appName="WhatsApp",title="Old %d"%i,text="dismissed message %d"%i,sub="",when=now-3600000*(i+1),removedAt=now-1000*i,iconUrl="") for i in range(6)]
            h=[x for x in h if not qq or qq in (x["title"]+x["text"]).lower()]
            return self.send(dict(ok=True,rev=STATE["rev"],enabled=True,total=6,items=h))
        if u.path=="/v1/notifications/rules":
            apps=[dict(app=a,name=nm,icon="",rule=STATE["rules"].get(a,"show")) for a,nm in [("com.google","Google"),("com.telegram","Telegram"),("com.whatsapp","WhatsApp")]]
            return self.send(dict(ok=True,historyEnabled=True,apps=apps))
        if u.path=="/v1/devices":
            return self.send(dict(ok=True,devices=[dict(id=DEV,name="Mock Phone",platform="android",online=True,link="lan",battery=dict(level=77,charging=False))]))
        self.send(dict(ok=False,error="not_found"),404)
    def do_POST(self):
        ln=int(self.headers.get("Content-Length","0")); body=self.rfile.read(ln).decode() if ln else "{}"
        with open(LOG,"a") as f: f.write(json.dumps(dict(path=self.path,body=json.loads(body or "{}")))+"\n")
        p=self.path; b=json.loads(body or "{}")
        if p.endswith("/toggle-group"): STATE["expanded"]=not STATE["expanded"]
        elif p.endswith("/dismiss"):
            gone=[i for i in STATE["items"] if i["key"]==b.get("key") and not i["ongoing"]]
            STATE["items"]=[i for i in STATE["items"] if i not in gone]; STATE["last"]=gone; STATE["undo"]="Dismissed from "+(gone[0]["appName"] if gone else "")
        elif p.endswith("/dismiss-group"):
            gone=[i for i in STATE["items"] if i["app"]==b.get("app") and not i["ongoing"]]
            STATE["items"]=[i for i in STATE["items"] if i not in gone]; STATE["last"]=gone; STATE["undo"]="Dismissed %d from %s"%(len(gone),b.get("app"))
        elif p.endswith("/clear"):
            gone=[i for i in STATE["items"] if not i["ongoing"]]
            STATE["items"]=[i for i in STATE["items"] if i["ongoing"]]; STATE["last"]=gone; STATE["undo"]="Dismissed %d notifications"%len(gone)
        elif p.endswith("/undo"):
            STATE["items"]=STATE["last"]+STATE["items"]; STATE["items"].sort(key=lambda i:(not i["live"],-i["when"])); STATE["last"]=[]; STATE["undo"]=""
        elif p.endswith("/undo/clear"): STATE["last"]=[]; STATE["undo"]=""
        elif p.endswith("/rules") and b.get("rule"): STATE["rules"][b["app"]]=b["rule"]
        elif p.endswith("/action") and b.get("reply"):
            for i in STATE["items"]:
                if i["key"]==b["key"]: i["replies"].append(dict(text=b["reply"],pending=False))
        bump(); self.send(dict(ok=True))
ThreadingHTTPServer(("127.0.0.1",PORT),H).serve_forever()
