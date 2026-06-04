# 🚀 AI Resume Builder — Setup Guide

## Files Structure
```
resume_builder/
├── main.py        ← Python Backend (FastAPI + AI)
├── index.html     ← Frontend (HTML/CSS/JS)
└── README.md      ← Ye file
```

---

## ⚡ STEP 1 — Python Backend Chalao (Local)

### 1. Libraries Install Karo
```bash
pip install fastapi uvicorn reportlab anthropic python-multipart
```

### 2. API Key Set Karo (Free me bhi kaam karta hai bina key ke)
```bash
# Windows:
set ANTHROPIC_API_KEY=your_key_here

# Mac/Linux:
export ANTHROPIC_API_KEY=your_key_here
```
> ⚠️ Bina API key ke bhi basic resume banega, sirf AI enhancement nahi hoga

### 3. Server Start Karo
```bash
cd resume_builder
uvicorn main:app --reload --host 0.0.0.0 --port 8000
```

### 4. Browser mein kholo
```
http://localhost:8000/health  → "ok" dikhega
```

---

## 🌐 STEP 2 — Frontend Chalao

`index.html` ko seedha browser mein open karo — bas!

### Local test ke liye:
- Double click `index.html` → Chrome/Firefox mein khulega
- Ya: `python -m http.server 3000` → `http://localhost:3000`

---

## 🔗 Frontend + Backend Connect Kaise Hota Hai?

`index.html` mein line 1 hai:
```javascript
const API_URL = "http://localhost:8000";
```

Jab user form submit karta hai:
1. JS → `POST /generate-resume` → Python
2. Python → AI se summary banata hai → PDF banata hai
3. Python → Download URL deta hai
4. JS → User ko download button dikhata hai

**Itna simple hai!** Frontend aur Backend alag-alag hain, sirf ek URL se connected hain.

---

## 🌍 STEP 3 — Live Deploy Karo (Free!)

### Backend Deploy — Railway.app (Free)
1. Railway.app pe account banao
2. GitHub pe `main.py` + `requirements.txt` daalo
3. Railway pe deploy karo
4. URL milega jaise: `https://myresume.railway.app`

### requirements.txt:
```
fastapi
uvicorn
reportlab
anthropic
python-multipart
```

### Frontend Deploy — Netlify/Vercel (Free)
1. `index.html` mein API_URL update karo:
```javascript
const API_URL = "https://myresume.railway.app";
```
2. Netlify.com pe `index.html` drag & drop karo
3. Done! URL milega jaise: `https://myresume.netlify.app`

---

## 💰 Paise Kaise Kamao?

### 1. Google AdSense
- Google AdSense ke liye apply karo
- Approve hone ke baad `<script>` tag `index.html` mein daalo
- Har visit pe paise milenge

### 2. AdSense Code Kahan Daalo?
`index.html` mein `</body>` se pehle:
```html
<!-- Google AdSense -->
<script async src="https://pagead2.googlesyndication.com/pagead/js/adsbygoogle.js"></script>
```

### 3. Premium Features (Future)
- Basic resume: Free
- Premium templates: ₹99/resume
- LinkedIn optimization: ₹149
- Cover letter: ₹79

---

## 📱 App Banani Hai?

Frontend ko simply **WebView** mein wrap karo:
- Android: Android Studio mein WebView activity
- iOS: WKWebView
- Cross-platform: **Capacitor** (free, 1 codebase → Android + iOS)

---

## 🤖 Resume Types (Auto-detected by AI)

| Type | Who | Color |
|------|-----|-------|
| Fresher | 0 experience | Green |
| Technical | Developers/Engineers | Blue |
| Creative | Designers/Marketers | Pink |
| Experienced | 3+ years | Orange |
| General | Others | Purple |

---

## ❓ Common Issues

**CORS Error?**
→ Backend chal raha hai? `http://localhost:8000/health` check karo

**PDF nahi ban raha?**
→ `pip install reportlab` dobara run karo

**AI kaam nahi kar raha?**
→ API key sahi set hai? Bina key ke bhi basic resume banega
