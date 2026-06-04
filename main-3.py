from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import FileResponse
from pydantic import BaseModel
from typing import Optional, List
import anthropic
import os
import json
import re
from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
from reportlab.lib.units import mm
from reportlab.lib import colors
from reportlab.platypus import SimpleDocTemplate, Paragraph, Spacer, HRFlowable, Table, TableStyle
from reportlab.lib.enums import TA_LEFT, TA_CENTER, TA_RIGHT
import uuid

app = FastAPI(title="AI Resume Builder API")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

ANTHROPIC_API_KEY = os.environ.get("ANTHROPIC_API_KEY", "")

class WorkExperience(BaseModel):
    company: str
    role: str
    duration: str
    description: str

class Education(BaseModel):
    institution: str
    degree: str
    year: str

class ResumeData(BaseModel):
    full_name: str
    email: str
    phone: str
    location: str
    job_title: str
    skills: str
    work_experience: List[WorkExperience] = []
    education: List[Education] = []
    summary: Optional[str] = ""
    linkedin: Optional[str] = ""
    github: Optional[str] = ""

def detect_resume_type(data: ResumeData) -> str:
    skills_lower = data.skills.lower()
    title_lower = data.job_title.lower()
    has_experience = len(data.work_experience) > 0
    years_exp = len(data.work_experience)

    if not has_experience or years_exp == 0:
        return "fresher"
    elif any(k in skills_lower or k in title_lower for k in ["react","node","python","java","developer","engineer","software","code","programming","backend","frontend","fullstack","devops","cloud","aws"]):
        return "technical"
    elif any(k in skills_lower or k in title_lower for k in ["design","creative","ux","ui","graphic","illustrator","figma","adobe","art","visual","brand","marketing","content"]):
        return "creative"
    elif years_exp >= 3:
        return "experienced"
    else:
        return "general"

def ai_enhance_resume(data: ResumeData, resume_type: str) -> dict:
    if not ANTHROPIC_API_KEY:
        summary = f"Dynamic {data.job_title} with expertise in {data.skills[:100]}. Passionate about delivering results and continuously growing in the field."
        return {
            "summary": data.summary if data.summary else summary,
            "skills_list": [s.strip() for s in data.skills.split(",") if s.strip()],
            "resume_type": resume_type,
            "improvements": []
        }

    client = anthropic.Anthropic(api_key=ANTHROPIC_API_KEY)

    exp_text = ""
    for exp in data.work_experience:
        exp_text += f"- {exp.role} at {exp.company} ({exp.duration}): {exp.description}\n"

    edu_text = ""
    for edu in data.education:
        edu_text += f"- {edu.degree} from {edu.institution} ({edu.year})\n"

    prompt = f"""You are a professional resume writer. Based on the following candidate data, provide:
1. A powerful 3-4 sentence professional summary
2. A list of 8-12 key skills (based on what they entered + relevant suggestions)
3. 2-3 bullet point improvements for each work experience description (make them more impactful with action verbs and metrics)

Resume Type: {resume_type}
Name: {data.full_name}
Job Title: {data.job_title}
Skills: {data.skills}
Work Experience:
{exp_text if exp_text else "No experience (fresher)"}
Education:
{edu_text}
Existing Summary: {data.summary}

Respond ONLY in valid JSON format like this:
{{
  "summary": "Professional summary here...",
  "skills_list": ["Skill 1", "Skill 2", "Skill 3"],
  "enhanced_experiences": [
    {{
      "company": "Company Name",
      "improved_bullets": ["• Achievement 1", "• Achievement 2"]
    }}
  ]
}}"""

    message = client.messages.create(
        model="claude-sonnet-4-20250514",
        max_tokens=1500,
        messages=[{"role": "user", "content": prompt}]
    )

    response_text = message.content[0].text
    # Strip markdown code fences if present
    response_text = re.sub(r'```json\s*', '', response_text)
    response_text = re.sub(r'```\s*', '', response_text)
    response_text = response_text.strip()

    try:
        result = json.loads(response_text)
        result["resume_type"] = resume_type
        return result
    except:
        return {
            "summary": data.summary or f"Experienced {data.job_title} with expertise in {data.skills[:80]}.",
            "skills_list": [s.strip() for s in data.skills.split(",") if s.strip()],
            "enhanced_experiences": [],
            "resume_type": resume_type
        }


def build_pdf(data: ResumeData, ai_data: dict, filename: str):
    doc = SimpleDocTemplate(
        filename,
        pagesize=A4,
        topMargin=12*mm,
        bottomMargin=12*mm,
        leftMargin=16*mm,
        rightMargin=16*mm
    )

    resume_type = ai_data.get("resume_type", "general")

    # Color schemes per type
    color_map = {
        "technical": colors.HexColor("#1a1a2e"),
        "creative":  colors.HexColor("#2d1b4e"),
        "fresher":   colors.HexColor("#0a4d68"),
        "experienced": colors.HexColor("#1b2838"),
        "general":   colors.HexColor("#1c3d5a"),
    }
    accent_map = {
        "technical": colors.HexColor("#00d4ff"),
        "creative":  colors.HexColor("#ff6b9d"),
        "fresher":   colors.HexColor("#00e5b0"),
        "experienced": colors.HexColor("#f5a623"),
        "general":   colors.HexColor("#4ecdc4"),
    }

    PRIMARY = color_map.get(resume_type, colors.HexColor("#1c3d5a"))
    ACCENT  = accent_map.get(resume_type, colors.HexColor("#4ecdc4"))
    WHITE   = colors.white
    DARK    = colors.HexColor("#1a1a1a")
    GRAY    = colors.HexColor("#555555")
    LGRAY   = colors.HexColor("#888888")

    story = []

    # ── HEADER ──────────────────────────────────────────────────────────────
    header_data = [[
        Paragraph(f'<font size="22"><b>{data.full_name}</b></font>', ParagraphStyle('h', textColor=WHITE, fontName='Helvetica-Bold', fontSize=22)),
        Paragraph(f'<font size="12">{data.job_title}</font><br/>'
                  f'<font size="9" color="#cccccc">{data.email}  |  {data.phone}  |  {data.location}</font>'
                  + (f'<br/><font size="9" color="#aaaaaa">linkedin: {data.linkedin}</font>' if data.linkedin else '')
                  + (f'  <font size="9" color="#aaaaaa">github: {data.github}</font>' if data.github else ''),
                  ParagraphStyle('hsub', textColor=WHITE, fontName='Helvetica', fontSize=11, leading=16))
    ]]
    header_table = Table(header_data, colWidths=[65*mm, 113*mm])
    header_table.setStyle(TableStyle([
        ('BACKGROUND', (0, 0), (-1, -1), PRIMARY),
        ('VALIGN', (0, 0), (-1, -1), 'MIDDLE'),
        ('LEFTPADDING', (0, 0), (0, 0), 8*mm),
        ('RIGHTPADDING', (0, 0), (0, 0), 4*mm),
        ('LEFTPADDING', (1, 0), (1, 0), 6*mm),
        ('TOPPADDING', (0, 0), (-1, -1), 6*mm),
        ('BOTTOMPADDING', (0, 0), (-1, -1), 6*mm),
    ]))
    story.append(header_table)
    story.append(Spacer(1, 5*mm))

    def section_title(txt):
        story.append(Spacer(1, 3*mm))
        story.append(Paragraph(
            f'<font color="#{ACCENT.hexval()[2:]}">{txt.upper()}</font>',
            ParagraphStyle('sec', fontName='Helvetica-Bold', fontSize=10, textColor=ACCENT, spaceAfter=2)
        ))
        story.append(HRFlowable(width="100%", thickness=1.5, color=ACCENT, spaceAfter=3))

    def body_p(txt, bold=False):
        fn = 'Helvetica-Bold' if bold else 'Helvetica'
        return Paragraph(txt, ParagraphStyle('bp', fontName=fn, fontSize=9, textColor=DARK, leading=14, spaceAfter=2))

    def gray_p(txt):
        return Paragraph(txt, ParagraphStyle('gp', fontName='Helvetica', fontSize=8.5, textColor=GRAY, leading=13))

    # ── SUMMARY ──────────────────────────────────────────────────────────────
    summary_text = ai_data.get("summary", data.summary)
    if summary_text:
        section_title("Professional Summary")
        story.append(body_p(summary_text))

    # ── SKILLS ──────────────────────────────────────────────────────────────
    skills_list = ai_data.get("skills_list", [s.strip() for s in data.skills.split(",") if s.strip()])
    if skills_list:
        section_title("Skills")
        # Render skills as pill-like groups, 4 per row
        rows = [skills_list[i:i+4] for i in range(0, len(skills_list), 4)]
        skill_style = ParagraphStyle('sk', fontName='Helvetica-Bold', fontSize=8.5,
                                     textColor=PRIMARY, borderPadding=2)
        for row in rows:
            cell_data = [Paragraph(f"▸ {s}", skill_style) for s in row]
            while len(cell_data) < 4:
                cell_data.append(Paragraph("", skill_style))
            t = Table([cell_data], colWidths=[44*mm]*4)
            t.setStyle(TableStyle([
                ('BACKGROUND', (0, 0), (-1, -1), colors.HexColor("#f0f7ff")),
                ('ROWBACKGROUNDS', (0, 0), (-1, -1), [colors.HexColor("#f0f7ff")]),
                ('TOPPADDING', (0, 0), (-1, -1), 3),
                ('BOTTOMPADDING', (0, 0), (-1, -1), 3),
                ('LEFTPADDING', (0, 0), (-1, -1), 4),
            ]))
            story.append(t)
            story.append(Spacer(1, 1.5*mm))

    # ── WORK EXPERIENCE ──────────────────────────────────────────────────────
    enhanced = {e['company']: e.get('improved_bullets', []) for e in ai_data.get('enhanced_experiences', [])}

    if data.work_experience:
        section_title("Work Experience")
        for exp in data.work_experience:
            row = [[
                Paragraph(f'<b>{exp.role}</b>', ParagraphStyle('r', fontName='Helvetica-Bold', fontSize=10, textColor=DARK)),
                Paragraph(exp.duration, ParagraphStyle('d', fontName='Helvetica', fontSize=9, textColor=LGRAY, alignment=TA_RIGHT))
            ]]
            t = Table(row, colWidths=[130*mm, 48*mm])
            t.setStyle(TableStyle([('VALIGN', (0,0), (-1,-1), 'TOP'), ('TOPPADDING',(0,0),(-1,-1),0), ('BOTTOMPADDING',(0,0),(-1,-1),0)]))
            story.append(t)
            story.append(gray_p(f"🏢 {exp.company}"))

            bullets = enhanced.get(exp.company, [])
            if bullets:
                for b in bullets:
                    story.append(body_p(b))
            else:
                if exp.description:
                    for line in exp.description.split("."):
                        line = line.strip()
                        if line:
                            story.append(body_p(f"• {line}"))
            story.append(Spacer(1, 2*mm))

    # ── EDUCATION ──────────────────────────────────────────────────────────
    if data.education:
        section_title("Education")
        for edu in data.education:
            row = [[
                Paragraph(f'<b>{edu.degree}</b>', ParagraphStyle('ed', fontName='Helvetica-Bold', fontSize=10, textColor=DARK)),
                Paragraph(edu.year, ParagraphStyle('ey', fontName='Helvetica', fontSize=9, textColor=LGRAY, alignment=TA_RIGHT))
            ]]
            t = Table(row, colWidths=[130*mm, 48*mm])
            t.setStyle(TableStyle([('VALIGN',(0,0),(-1,-1),'TOP'),('TOPPADDING',(0,0),(-1,-1),0),('BOTTOMPADDING',(0,0),(-1,-1),0)]))
            story.append(t)
            story.append(gray_p(f"🎓 {edu.institution}"))
            story.append(Spacer(1, 2*mm))

    # ── FOOTER ──────────────────────────────────────────────────────────────
    story.append(Spacer(1, 4*mm))
    story.append(HRFlowable(width="100%", thickness=0.5, color=LGRAY))
    story.append(Paragraph(
        f'<font size="7" color="#aaaaaa">Generated by AI Resume Builder • {resume_type.capitalize()} Profile</font>',
        ParagraphStyle('ft', fontName='Helvetica', fontSize=7, textColor=LGRAY, alignment=TA_CENTER)
    ))

    doc.build(story)


@app.post("/generate-resume")
async def generate_resume(data: ResumeData):
    try:
        resume_type = detect_resume_type(data)
        ai_data = ai_enhance_resume(data, resume_type)

        uid = str(uuid.uuid4())[:8]
        output_dir = "/tmp/resumes"
        os.makedirs(output_dir, exist_ok=True)
        filename = f"{output_dir}/resume_{uid}.pdf"

        build_pdf(data, ai_data, filename)

        return {
            "success": True,
            "resume_type": resume_type,
            "summary_used": ai_data.get("summary", ""),
            "skills_enhanced": ai_data.get("skills_list", []),
            "download_url": f"/download/{uid}",
            "file_id": uid
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@app.get("/download/{file_id}")
async def download_resume(file_id: str):
    filename = f"/tmp/resumes/resume_{file_id}.pdf"
    if not os.path.exists(filename):
        raise HTTPException(status_code=404, detail="Resume not found")
    return FileResponse(
        filename,
        media_type="application/pdf",
        filename="My_Resume.pdf"
    )


@app.get("/health")
async def health():
    return {"status": "ok", "message": "AI Resume Builder is running!"}
