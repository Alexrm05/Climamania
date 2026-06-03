from __future__ import annotations

import html
import re
from datetime import datetime
from pathlib import Path

from PIL import Image as PILImage
from PIL import ImageDraw, ImageFont
from reportlab.lib import colors
from reportlab.lib.enums import TA_CENTER
from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import ParagraphStyle, getSampleStyleSheet
from reportlab.lib.units import mm
from reportlab.platypus import (
    HRFlowable,
    Image,
    PageBreak,
    Paragraph,
    SimpleDocTemplate,
    Spacer,
    Table,
    TableStyle,
)


BASE_DIR = Path(__file__).resolve().parents[1]
SOURCE_MD = BASE_DIR / "MANUAL_USUARIO_APP.md"
OUTPUT_DIR = BASE_DIR / "output" / "pdf"
OUTPUT_PDF = OUTPUT_DIR / "Manual_Usuario_ClimaMania.pdf"
TMP_ASSETS = BASE_DIR / "tmp" / "pdfs" / "manual_assets"

LOGO_PATH = BASE_DIR / "app" / "src" / "main" / "res" / "drawable" / "climamania_logo.png"
QR_PATH = BASE_DIR / "app" / "src" / "main" / "res" / "drawable" / "qr_valoracion.jpg"
CONFORME_PREVIEW = BASE_DIR / "tmp" / "pdfs" / "conforme_preview_exact_pypdfium.png"
BOE_PREVIEW_A = BASE_DIR / "tmp" / "pdfs" / "boe_preview_clean_1.png"
BOE_PREVIEW_B = BASE_DIR / "tmp" / "pdfs" / "boe_preview_clean_2.png"
PREINST_PHOTO = (
    BASE_DIR.parents[0] / "clminstal" / "imagenes" / "64433-PREINST-20251222093408-C1.png"
)
POSTINST_PHOTO = (
    BASE_DIR.parents[0] / "clminstal" / "imagenes" / "64433-POSTINST-20251222052200-C1.png"
)


def load_font(size: int, bold: bool = False):
    candidates = []
    if bold:
        candidates.extend(
            [
                "/System/Library/Fonts/Supplemental/Arial Bold.ttf",
                "/System/Library/Fonts/Supplemental/Helvetica.ttc",
            ]
        )
    else:
        candidates.extend(
            [
                "/System/Library/Fonts/Supplemental/Arial.ttf",
                "/System/Library/Fonts/Supplemental/Helvetica.ttc",
            ]
        )
    for candidate in candidates:
        path = Path(candidate)
        if path.exists():
            try:
                return ImageFont.truetype(str(path), size=size)
            except Exception:
                continue
    return ImageFont.load_default()


def create_overview_image(target: Path) -> None:
    target.parent.mkdir(parents=True, exist_ok=True)
    width, height = 1400, 2200
    bg = (247, 244, 238)
    canvas = PILImage.new("RGB", (width, height), bg)
    draw = ImageDraw.Draw(canvas)

    green = (120, 174, 0)
    light_green = (231, 245, 214)
    orange = (255, 145, 55)
    blue = (96, 189, 240)
    dark = (40, 40, 40)
    muted = (110, 110, 110)
    white = (255, 255, 255)

    title_font = load_font(86, bold=True)
    h_font = load_font(42, bold=True)
    body_font = load_font(28)
    chip_font = load_font(26, bold=True)

    def rr(x1, y1, x2, y2, fill, outline=None, radius=38, width_line=3):
        draw.rounded_rectangle([x1, y1, x2, y2], radius=radius, fill=fill, outline=outline, width=width_line)

    rr(160, 70, 1240, 2130, white, outline=(232, 220, 205), radius=64, width_line=4)
    rr(220, 120, 1180, 1880, (250, 250, 250), radius=34)
    draw.text((360, 160), "ClimaMania", fill=(230, 121, 39), font=title_font)
    draw.text((250, 160), "🌲", fill=(44, 128, 41), font=title_font)

    cards = [
        ("Calendario", orange, 250, 380, 670, 520),
        ("Inicio", orange, 710, 380, 1130, 520),
        ("Buscar eventos", white, 250, 560, 1130, 690),
        ("Adicionales", white, 250, 740, 1130, 900),
        ("Durante la instalación", white, 250, 950, 1130, 1280),
        ("Conforme cliente", white, 250, 1320, 1130, 1550),
        ("Cierre", light_green, 250, 1590, 1130, 1820),
    ]

    for label, fill, x1, y1, x2, y2 in cards:
        rr(x1, y1, x2, y2, fill, outline=(234, 223, 210), radius=28)
        draw.text((x1 + 36, y1 + 24), label, fill=dark, font=h_font)

    rr(300, 1020, 670, 1125, orange, radius=18)
    rr(710, 1020, 1080, 1125, green, radius=18)
    rr(300, 1155, 1080, 1245, green, radius=18)
    draw.text((395, 1048), "Fotos acabada", fill=white, font=chip_font)
    draw.text((830, 1048), "Conforme", fill=white, font=chip_font)
    draw.text((498, 1182), "Documento BOE", fill=white, font=chip_font)

    rr(300, 1400, 1080, 1490, blue, radius=18)
    rr(300, 1665, 1080, 1760, green, radius=18)
    draw.text((455, 1427), "Firma conforme cliente", fill=white, font=chip_font)
    draw.text((480, 1692), "Finalizar instalación", fill=white, font=chip_font)

    rr(250, 1930, 1130, 2040, white, outline=(60, 60, 60), radius=18)
    draw.text((620, 1962), "Volver", fill=dark, font=chip_font, anchor="mm")

    draw.text((250, 260), "Mapa visual rápido de la app", fill=dark, font=h_font)
    draw.text((250, 310), "Vista resumida de los módulos principales y del flujo de trabajo diario.", fill=muted, font=body_font)

    draw.text((295, 595), "Busca instalaciones, visitas e incidencias desde un único punto.", fill=muted, font=body_font)
    draw.text((295, 810), "Crea, firma, consulta, envía y cancela presupuestos desde el módulo de adicionales.", fill=muted, font=body_font)
    draw.text((295, 1365), "Inicia el flujo documental del cliente y genera la documentación final.", fill=muted, font=body_font)
    draw.text((295, 1635), "Cierra técnicamente la instalación y registra el estado final del trabajo.", fill=muted, font=body_font)

    canvas.save(target)


def create_workflow_image(target: Path) -> None:
    target.parent.mkdir(parents=True, exist_ok=True)
    width, height = 1800, 740
    canvas = PILImage.new("RGB", (width, height), (248, 245, 240))
    draw = ImageDraw.Draw(canvas)
    title_font = load_font(54, bold=True)
    box_font = load_font(28, bold=True)
    small_font = load_font(24)
    dark = (36, 36, 36)
    green = (120, 174, 0)
    orange = (255, 145, 55)
    blue = (96, 189, 240)
    white = (255, 255, 255)

    draw.text((80, 50), "Flujo documental y operativo", fill=dark, font=title_font)
    draw.text((80, 120), "Secuencia recomendada para completar una instalación de principio a fin.", fill=(102, 102, 102), font=small_font)

    steps = [
        ("Calendario", orange),
        ("Pedido", white),
        ("Realizar\ninstalación", white),
        ("Conforme\ncliente", blue),
        ("BOE\nsi aplica", green),
        ("Finalizar\ninstalación", green),
    ]
    x = 80
    y = 260
    w = 230
    h = 150
    gap = 48
    for i, (label, fill) in enumerate(steps):
        draw.rounded_rectangle([x, y, x + w, y + h], radius=30, fill=fill, outline=(220, 210, 198), width=3)
        draw.multiline_text((x + w / 2, y + h / 2), label, fill=dark if fill == white else white, font=box_font, anchor="mm", align="center", spacing=6)
        if i < len(steps) - 1:
            ax = x + w + 10
            ay = y + h / 2
            bx = ax + gap - 20
            draw.line([ax, ay, bx, ay], fill=(120, 120, 120), width=6)
            draw.polygon([(bx, ay), (bx - 20, ay - 12), (bx - 20, ay + 12)], fill=(120, 120, 120))
        x += w + gap

    draw.text((80, 500), "Consejo", fill=dark, font=box_font)
    draw.text(
        (80, 545),
        "Si la instalación requiere BOE, primero se revisan los equipos, después se firma el conforme, se generan los PDFs y se envían por email.",
        fill=(90, 90, 90),
        font=small_font,
    )
    canvas.save(target)


def format_inline(text: str) -> str:
    escaped = html.escape(text)
    escaped = re.sub(r"\*\*(.+?)\*\*", r"<b>\1</b>", escaped)
    escaped = re.sub(r"`([^`]+)`", r'<font name="Helvetica-Bold">\1</font>', escaped)
    return escaped


def parse_markdown_events(source: Path):
    lines = source.read_text(encoding="utf-8").splitlines()
    events: list[tuple] = []
    paragraph: list[str] = []

    def flush_paragraph():
        if paragraph:
            text = " ".join(chunk.strip() for chunk in paragraph if chunk.strip()).strip()
            if text:
                events.append(("p", text))
            paragraph.clear()

    for line in lines:
        raw = line.rstrip()
        stripped = raw.strip()
        if not stripped:
            flush_paragraph()
            continue
        if stripped == "---":
            flush_paragraph()
            events.append(("hr",))
            continue
        if raw.startswith("# "):
            flush_paragraph()
            events.append(("h1", raw[2:].strip()))
            continue
        if raw.startswith("#### "):
            flush_paragraph()
            events.append(("h4", raw[5:].strip()))
            continue
        if raw.startswith("### "):
            flush_paragraph()
            events.append(("h3", raw[4:].strip()))
            continue
        if raw.startswith("## "):
            flush_paragraph()
            events.append(("h2", raw[3:].strip()))
            continue
        if re.match(r"^\s*[-*]\s+", raw):
            flush_paragraph()
            indent = len(raw) - len(raw.lstrip(" "))
            text = re.sub(r"^\s*[-*]\s+", "", raw)
            events.append(("bullet", indent, text))
            continue
        if re.match(r"^\s*\d+\.\s+", raw):
            flush_paragraph()
            indent = len(raw) - len(raw.lstrip(" "))
            text = raw.strip()
            events.append(("number", indent, text))
            continue
        paragraph.append(stripped)

    flush_paragraph()
    return events


def image_flowable(path: Path, max_width: float, max_height: float):
    if not path.exists():
        return None
    with PILImage.open(path) as img:
        width_px, height_px = img.size
    ratio = min(max_width / width_px, max_height / height_px)
    ratio = min(ratio, 1.0)
    return Image(str(path), width=width_px * ratio, height=height_px * ratio)


def two_image_table(path1: Path, path2: Path, width: float):
    img1 = image_flowable(path1, (width - 12) / 2, 220 * mm)
    img2 = image_flowable(path2, (width - 12) / 2, 220 * mm)
    cells = []
    if img1:
        cells.append(img1)
    else:
        cells.append("")
    if img2:
        cells.append(img2)
    else:
        cells.append("")
    table = Table([cells], colWidths=[(width - 12) / 2, (width - 12) / 2], hAlign="CENTER")
    table.setStyle(TableStyle([("VALIGN", (0, 0), (-1, -1), "TOP")]))
    return table


def build_pdf():
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    TMP_ASSETS.mkdir(parents=True, exist_ok=True)

    overview_img = TMP_ASSETS / "app_overview.png"
    workflow_img = TMP_ASSETS / "workflow.png"
    create_overview_image(overview_img)
    create_workflow_image(workflow_img)

    doc = SimpleDocTemplate(
        str(OUTPUT_PDF),
        pagesize=A4,
        leftMargin=18 * mm,
        rightMargin=18 * mm,
        topMargin=18 * mm,
        bottomMargin=16 * mm,
        title="Manual de uso de la app ClimaMania",
        author="Codex",
    )

    styles = getSampleStyleSheet()
    styles.add(
        ParagraphStyle(
            name="ManualTitle",
            parent=styles["Title"],
            fontName="Helvetica-Bold",
            fontSize=25,
            leading=29,
            alignment=TA_CENTER,
            textColor=colors.HexColor("#2A2A2A"),
            spaceAfter=10,
        )
    )
    styles.add(
        ParagraphStyle(
            name="ManualSubtitle",
            parent=styles["BodyText"],
            fontName="Helvetica",
            fontSize=11,
            leading=15,
            alignment=TA_CENTER,
            textColor=colors.HexColor("#6B6B6B"),
            spaceAfter=18,
        )
    )
    styles.add(
        ParagraphStyle(
            name="ManualH1",
            parent=styles["Heading1"],
            fontName="Helvetica-Bold",
            fontSize=19,
            leading=22,
            spaceBefore=12,
            spaceAfter=8,
            textColor=colors.HexColor("#243142"),
        )
    )
    styles.add(
        ParagraphStyle(
            name="ManualH2",
            parent=styles["Heading2"],
            fontName="Helvetica-Bold",
            fontSize=14,
            leading=18,
            spaceBefore=12,
            spaceAfter=6,
            textColor=colors.HexColor("#243142"),
        )
    )
    styles.add(
        ParagraphStyle(
            name="ManualH3",
            parent=styles["Heading3"],
            fontName="Helvetica-Bold",
            fontSize=11.4,
            leading=14.6,
            spaceBefore=7,
            spaceAfter=3,
            textColor=colors.HexColor("#3F4E5D"),
        )
    )
    styles.add(
        ParagraphStyle(
            name="ManualH4",
            parent=styles["Heading4"],
            fontName="Helvetica-BoldOblique",
            fontSize=9.8,
            leading=12.2,
            spaceBefore=4,
            spaceAfter=2,
            textColor=colors.HexColor("#596474"),
        )
    )
    styles.add(
        ParagraphStyle(
            name="ManualBody",
            parent=styles["BodyText"],
            fontName="Helvetica",
            fontSize=9.4,
            leading=13.2,
            spaceAfter=5,
            textColor=colors.HexColor("#2F2F2F"),
        )
    )
    styles.add(
        ParagraphStyle(
            name="ManualBullet",
            parent=styles["BodyText"],
            fontName="Helvetica",
            fontSize=9.2,
            leading=12.8,
            leftIndent=14,
            firstLineIndent=0,
            spaceAfter=3,
            textColor=colors.HexColor("#2F2F2F"),
        )
    )
    styles.add(
        ParagraphStyle(
            name="ManualSmall",
            parent=styles["BodyText"],
            fontName="Helvetica",
            fontSize=8.3,
            leading=11,
            textColor=colors.HexColor("#6C6C6C"),
            alignment=TA_CENTER,
        )
    )

    available_width = A4[0] - doc.leftMargin - doc.rightMargin
    story = []

    if LOGO_PATH.exists():
        logo = image_flowable(LOGO_PATH, 70 * mm, 28 * mm)
        if logo:
            logo.hAlign = "CENTER"
            story.append(Spacer(1, 6 * mm))
            story.append(logo)
            story.append(Spacer(1, 7 * mm))

    story.append(Paragraph("Manual completo de uso de la app ClimaMania", styles["ManualTitle"]))
    story.append(
        Paragraph(
            "Guía integral de navegación, trabajo diario, documentación, visitas, incidencias, presupuestos y cierre de instalaciones.",
            styles["ManualSubtitle"],
        )
    )
    story.append(
        Paragraph(
            f"Versión generada el {datetime.now().strftime('%d/%m/%Y %H:%M')}",
            styles["ManualSmall"],
        )
    )
    story.append(Spacer(1, 8 * mm))

    overview = image_flowable(overview_img, available_width, 165 * mm)
    if overview:
        overview.hAlign = "CENTER"
        story.append(overview)
        story.append(Spacer(1, 6 * mm))

    story.append(
        Paragraph(
            "Este manual está pensado para que una persona pueda entender la app de principio a fin solo con leerlo, sin depender de formación previa.",
            styles["ManualBody"],
        )
    )

    workflow = image_flowable(workflow_img, available_width, 75 * mm)
    if workflow:
        story.append(Spacer(1, 6 * mm))
        workflow.hAlign = "CENTER"
        story.append(Paragraph("Mapa rápido de trabajo", styles["ManualH1"]))
        story.append(workflow)
        story.append(Spacer(1, 5 * mm))

    events = parse_markdown_events(SOURCE_MD)
    image_inserts_done: set[str] = set()

    for event in events:
        kind = event[0]
        if kind == "h1":
            story.append(Paragraph(format_inline(event[1]), styles["ManualH1"]))
        elif kind == "h2":
            heading = event[1]
            story.append(Paragraph(format_inline(heading), styles["ManualH2"]))

            if "Estructura general de la app" in heading and "overview" not in image_inserts_done:
                flow = image_flowable(overview_img, available_width, 130 * mm)
                if flow:
                    flow.hAlign = "CENTER"
                    story.append(Spacer(1, 2 * mm))
                    story.append(flow)
                    story.append(Spacer(1, 4 * mm))
                    image_inserts_done.add("overview")

            if "Gestión de fotos, documentos y vídeos" in heading and "media" not in image_inserts_done:
                story.append(Spacer(1, 2 * mm))
                story.append(two_image_table(PREINST_PHOTO, POSTINST_PHOTO, available_width))
                story.append(Spacer(1, 2 * mm))
                story.append(
                    Paragraph(
                        "Ejemplo visual de contenido gráfico real que la app puede consultar o adjuntar en una instalación.",
                        styles["ManualSmall"],
                    )
                )
                story.append(Spacer(1, 4 * mm))
                image_inserts_done.add("media")

            if "Flujo completo del conforme del cliente" in heading and "workflow" not in image_inserts_done:
                flow = image_flowable(workflow_img, available_width, 65 * mm)
                if flow:
                    flow.hAlign = "CENTER"
                    story.append(Spacer(1, 2 * mm))
                    story.append(flow)
                    story.append(Spacer(1, 4 * mm))
                    image_inserts_done.add("workflow")

            if "Detalle del PDF de conformidad" in heading and "conforme" not in image_inserts_done:
                flow = image_flowable(CONFORME_PREVIEW, available_width, 165 * mm)
                if flow:
                    flow.hAlign = "CENTER"
                    story.append(Spacer(1, 3 * mm))
                    story.append(flow)
                    story.append(Spacer(1, 2 * mm))
                    story.append(Paragraph("Vista de referencia del PDF de conformidad generado por la app.", styles["ManualSmall"]))
                    story.append(Spacer(1, 4 * mm))
                    image_inserts_done.add("conforme")

            if "Detalle del PDF BOE" in heading and "boe" not in image_inserts_done:
                story.append(Spacer(1, 3 * mm))
                story.append(two_image_table(BOE_PREVIEW_A, BOE_PREVIEW_B, available_width))
                story.append(Spacer(1, 2 * mm))
                story.append(Paragraph("Vista de referencia del BOE generado: Parte A y Parte B.", styles["ManualSmall"]))
                story.append(Spacer(1, 4 * mm))
                image_inserts_done.add("boe")

            if "Valoraciones" in heading and "qr" not in image_inserts_done:
                flow = image_flowable(QR_PATH, 75 * mm, 75 * mm)
                if flow:
                    flow.hAlign = "CENTER"
                    story.append(Spacer(1, 2 * mm))
                    story.append(flow)
                    story.append(Spacer(1, 2 * mm))
                    story.append(Paragraph("QR de valoraciones usado en la app.", styles["ManualSmall"]))
                    story.append(Spacer(1, 4 * mm))
                    image_inserts_done.add("qr")

        elif kind == "h3":
            story.append(Paragraph(format_inline(event[1]), styles["ManualH3"]))
        elif kind == "h4":
            story.append(Paragraph(format_inline(event[1]), styles["ManualH4"]))
        elif kind == "p":
            story.append(Paragraph(format_inline(event[1]), styles["ManualBody"]))
        elif kind == "bullet":
            indent = int(event[1])
            style = ParagraphStyle(
                f"Bullet{indent}",
                parent=styles["ManualBullet"],
                leftIndent=12 + max(0, indent * 4),
            )
            story.append(Paragraph(format_inline(event[2]), style, bulletText="•"))
        elif kind == "number":
            indent = int(event[1])
            style = ParagraphStyle(
                f"Number{indent}",
                parent=styles["ManualBullet"],
                leftIndent=12 + max(0, indent * 4),
            )
            story.append(Paragraph(format_inline(event[2]), style))
        elif kind == "hr":
            story.append(Spacer(1, 2 * mm))
            story.append(HRFlowable(width="100%", color=colors.HexColor("#D9D1C5"), thickness=0.8))
            story.append(Spacer(1, 2.5 * mm))

    def on_page(canvas, doc_obj):
        canvas.saveState()
        page_num = canvas.getPageNumber()
        canvas.setStrokeColor(colors.HexColor("#E1D9CC"))
        canvas.line(doc.leftMargin, 12 * mm, A4[0] - doc.rightMargin, 12 * mm)
        canvas.setFont("Helvetica", 8)
        canvas.setFillColor(colors.HexColor("#7B7B7B"))
        canvas.drawString(doc.leftMargin, 8 * mm, "Manual de uso de la app ClimaMania")
        canvas.drawRightString(A4[0] - doc.rightMargin, 8 * mm, f"Página {page_num}")
        canvas.restoreState()

    doc.build(story, onFirstPage=on_page, onLaterPages=on_page)


if __name__ == "__main__":
    build_pdf()
