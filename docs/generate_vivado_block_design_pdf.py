from pathlib import Path

from reportlab.lib import colors
from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import ParagraphStyle, getSampleStyleSheet
from reportlab.lib.units import mm
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont
from reportlab.platypus import (
    SimpleDocTemplate,
    Table,
    TableStyle,
    Paragraph,
    Spacer,
)


ROOT = Path(__file__).resolve().parents[1]
OUT_FILE = ROOT / "vivado_block_design_connection_list.pdf"
FONT_FILE = Path(r"C:\Windows\Fonts\simhei.ttf")
FONT_NAME = "SimHei"


ROWS = [
    ["模块", "端口", "连接到", "说明"],
    ["Clocking Wizard", "clk_in1", "板上 100 MHz 时钟", "板载主时钟输入"],
    ["Clocking Wizard", "clk_out1", "MicroBlaze / AXI / UARTLite / GPIO / proc_sys_reset / top.clk_pix", "作为系统时钟"],
    ["Clocking Wizard", "resetn", "板上复位按钮或常量", "如果有的话"],
    ["Processor System Reset", "slowest_sync_clk", "clk_out1", "系统时钟"],
    ["Processor System Reset", "ext_reset_in", "外部复位或 Clocking Wizard 的 locked 组合逻辑", "复位输入"],
    ["Processor System Reset", "peripheral_aresetn", "MicroBlaze / AXI / GPIO / UARTLite / top.rst_n", "低有效复位"],
    ["MicroBlaze", "Clk", "clk_out1", "CPU 时钟"],
    ["MicroBlaze", "Reset", "peripheral_aresetn", "CPU 复位"],
    ["MicroBlaze", "M_AXI_DP", "AXI Interconnect.S00_AXI", "主 AXI 总线"],
    ["Block Memory Generator", "clka", "clk_out1", "本地 BRAM 时钟"],
    ["Block Memory Generator", "ena", "常量 1", "使能"],
    ["Block Memory Generator", "addra / dina / douta / wea", "MicroBlaze 本地存储接口", "通常由 MicroBlaze 的 LMB / BRAM 相关 IP 自动处理"],
    ["AXI Interconnect", "ACLK", "clk_out1", "AXI 时钟"],
    ["AXI Interconnect", "ARESETN", "peripheral_aresetn", "AXI 复位"],
    ["AXI UARTLite", "s_axi_aclk", "clk_out1", "串口时钟"],
    ["AXI UARTLite", "s_axi_aresetn", "peripheral_aresetn", "串口复位"],
    ["AXI UARTLite", "S_AXI", "AXI Interconnect.Mxx_AXI", "AXI 从接口"],
    ["AXI UARTLite", "rx", "板上 UART_RX", "串口接收"],
    ["AXI UARTLite", "tx", "板上 UART_TX", "串口发送"],
    ["AXI GPIO", "s_axi_aclk", "clk_out1", "GPIO 时钟"],
    ["AXI GPIO", "s_axi_aresetn", "peripheral_aresetn", "GPIO 复位"],
    ["AXI GPIO", "S_AXI", "AXI Interconnect.Mxx_AXI", "AXI 从接口"],
    ["AXI GPIO", "gpio_io_o[7:0]", "top.btn_up / btn_down / btn_left / btn_right / btn_start / btn_pause / btn_reset", "软件输出控制信号"],
    ["AXI GPIO", "gpio_io_i[17:0]", "top.o_score[15:0] / top.o_state[1:0]", "软件读取分数和状态"],
    ["Module Reference top", "clk_pix", "clk_out1", "顶层像素 / 逻辑时钟"],
    ["Module Reference top", "rst_n", "peripheral_aresetn", "低有效复位"],
    ["Module Reference top", "btn_up", "AXI GPIO gpio_io_o[0]", "上"],
    ["Module Reference top", "btn_down", "AXI GPIO gpio_io_o[1]", "下"],
    ["Module Reference top", "btn_left", "AXI GPIO gpio_io_o[2]", "左"],
    ["Module Reference top", "btn_right", "AXI GPIO gpio_io_o[3]", "右"],
    ["Module Reference top", "btn_start", "AXI GPIO gpio_io_o[4]", "开始"],
    ["Module Reference top", "btn_pause", "AXI GPIO gpio_io_o[5]", "暂停"],
    ["Module Reference top", "btn_reset", "AXI GPIO gpio_io_o[6]", "复位"],
    ["Module Reference top", "hsync", "顶层输出端口", "后续接 XDC"],
    ["Module Reference top", "vsync", "顶层输出端口", "后续接 XDC"],
    ["Module Reference top", "vga_r[2:0]", "顶层输出端口", "后续接 XDC"],
    ["Module Reference top", "vga_g[2:0]", "顶层输出端口", "后续接 XDC"],
    ["Module Reference top", "vga_b[2:0]", "顶层输出端口", "后续接 XDC"],
    ["Module Reference top", "o_score[15:0]", "AXI GPIO gpio_io_i[15:0]", "分数回读"],
    ["Module Reference top", "o_state[1:0]", "AXI GPIO gpio_io_i[17:16]", "状态回读"],
]


def build_pdf() -> None:
    if not FONT_FILE.exists():
        raise FileNotFoundError(f"Chinese font not found: {FONT_FILE}")

    pdfmetrics.registerFont(TTFont(FONT_NAME, str(FONT_FILE)))

    styles = getSampleStyleSheet()
    styles.add(ParagraphStyle(
        name="TitleZH",
        parent=styles["Title"],
        fontName=FONT_NAME,
        fontSize=18,
        leading=24,
        textColor=colors.HexColor("#1f2937"),
        spaceAfter=10,
    ))
    styles.add(ParagraphStyle(
        name="BodyZH",
        parent=styles["BodyText"],
        fontName=FONT_NAME,
        fontSize=10,
        leading=14,
        textColor=colors.HexColor("#111827"),
    ))
    styles.add(ParagraphStyle(
        name="CellZH",
        parent=styles["BodyText"],
        fontName=FONT_NAME,
        fontSize=9,
        leading=12,
        textColor=colors.HexColor("#111827"),
    ))
    styles.add(ParagraphStyle(
        name="SmallNote",
        parent=styles["BodyText"],
        fontName=FONT_NAME,
        fontSize=8.5,
        leading=11,
        textColor=colors.HexColor("#374151"),
    ))

    doc = SimpleDocTemplate(
        str(OUT_FILE),
        pagesize=A4,
        leftMargin=15 * mm,
        rightMargin=15 * mm,
        topMargin=15 * mm,
        bottomMargin=15 * mm,
        title="Vivado Block Design 逐端口连接清单",
        author="GitHub Copilot",
    )

    story = []
    story.append(Paragraph("Vivado Block Design 逐端口连接清单", styles["TitleZH"]))
    story.append(Paragraph(
        "下面这份清单对应当前 vga_snake 工程的 MicroBlaze + AXI + VGA 结构，可直接照着在 Vivado Block Design 中逐项连线。",
        styles["BodyZH"],
    ))
    story.append(Spacer(1, 4 * mm))
    story.append(Paragraph("建议连接顺序：先时钟与复位，再 AXI 总线，再 UART / GPIO，最后接入 top 模块。", styles["SmallNote"]))
    story.append(Spacer(1, 6 * mm))

    table_data = []
    for row in ROWS:
        table_data.append([Paragraph(cell, styles["CellZH"]) for cell in row])

    table = Table(table_data, colWidths=[38 * mm, 30 * mm, 74 * mm, 28 * mm], repeatRows=1)
    table.setStyle(TableStyle([
        ("BACKGROUND", (0, 0), (-1, 0), colors.HexColor("#1f4e79")),
        ("TEXTCOLOR", (0, 0), (-1, 0), colors.white),
        ("FONTNAME", (0, 0), (-1, -1), FONT_NAME),
        ("FONTSIZE", (0, 0), (-1, -1), 9),
        ("LEADING", (0, 0), (-1, -1), 12),
        ("GRID", (0, 0), (-1, -1), 0.45, colors.HexColor("#9ca3af")),
        ("ROWBACKGROUNDS", (0, 1), (-1, -1), [colors.white, colors.HexColor("#f8fafc")]),
        ("VALIGN", (0, 0), (-1, -1), "TOP"),
        ("ALIGN", (0, 0), (-1, 0), "CENTER"),
        ("LEFTPADDING", (0, 0), (-1, -1), 5),
        ("RIGHTPADDING", (0, 0), (-1, -1), 5),
        ("TOPPADDING", (0, 0), (-1, -1), 4),
        ("BOTTOMPADDING", (0, 0), (-1, -1), 4),
    ]))

    story.append(table)
    story.append(Spacer(1, 5 * mm))
    story.append(Paragraph(
        "备注：如果你暂时只想先跑通系统，可以先只连接 AXI GPIO 的输出口给 top 模块，输入回读 score/state 可以后续再加。",
        styles["SmallNote"],
    ))

    def add_page_number(canvas, doc_):
        canvas.setFont(FONT_NAME, 9)
        canvas.setFillColor(colors.HexColor("#6b7280"))
        canvas.drawRightString(A4[0] - 15 * mm, 10 * mm, f"Page {doc_.page}")

    doc.build(story, onFirstPage=add_page_number, onLaterPages=add_page_number)


if __name__ == "__main__":
    build_pdf()
    print(f"PDF written to: {OUT_FILE}")
