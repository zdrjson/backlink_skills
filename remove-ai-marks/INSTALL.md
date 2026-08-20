# remove-ai-marks 安装与使用

清除 AI 溯源标记的技能：隐形 Unicode（Layer A）、统计式文本水印（Layer B，靠重写）、
以及 C2PA / EXIF / XMP / 文档属性等文件元数据。

来源：[guillaumemeyer/watermarks-remover](https://github.com/guillaumemeyer/watermarks-remover)（MIT），
详见 `NOTICE`。

## 架构

技能本身是**瘦客户端**：不含任何清洗代码，只用 `curl` 调本地 HTTP 服务。
真正干活的是 `service/`，纯 Python 3.10+ 标准库，无第三方依赖。

    remove-ai-marks/
    ├── SKILL.md            # 技能定义，Agent 读这个
    ├── references/         # 标记分类、各家厂商说明、伦理边界
    ├── service/            # 清洗服务（Python，stdlib only）
    ├── start-service.sh    # 启动服务
    └── INSTALL.md

## 1. 装成技能

从本仓库软链到技能目录：

```bash
# Claude Code（项目级）
mkdir -p .claude/skills
ln -sfn "$(pwd)/remove-ai-marks" .claude/skills/remove-ai-marks

# Claude Code（用户级，全局可用）
mkdir -p ~/.claude/skills
ln -sfn "$(pwd)/remove-ai-marks" ~/.claude/skills/remove-ai-marks

# Grok
mkdir -p ~/.grok/skills
ln -sfn "$(pwd)/remove-ai-marks" ~/.grok/skills/remove-ai-marks
```

装完用 `/remove-ai-marks` 触发，或直接说「去掉这段文字里的隐形字符」「清掉这张图的 C2PA」。

## 2. 启动服务

技能只有在服务跑起来时才可用：

```bash
chmod +x remove-ai-marks/start-service.sh   # 首次
./remove-ai-marks/start-service.sh          # 前台，127.0.0.1:8765
```

改端口用 `WATERMARKS_PORT=9000 ./remove-ai-marks/start-service.sh`，
客户端对应设 `WATERMARKS_SERVICE_URL=http://127.0.0.1:9000`。

验证：

```bash
curl -s --noproxy 127.0.0.1 http://127.0.0.1:8765/health
# {"ok": true, "version": "dev"}
```

> **代理环境注意**：如果环境里设了 `HTTP_PROXY` / `http_proxy`，curl 会把
> 127.0.0.1 的请求也发给代理，直接连接失败。加 `--noproxy 127.0.0.1`，
> 或者 `export NO_PROXY=127.0.0.1,localhost`。

## 3. 直接用命令行（不经技能）

服务只是把这些脚本包了一层 HTTP，脚本本身可以单独跑：

```bash
S=remove-ai-marks/service/scripts

python3 $S/inspect_text.py draft.md                        # 检查文本
python3 $S/clean_text.py draft.md -o draft.cleaned.md --stats
python3 $S/inspect_file.py notes.docx                      # 检查文件元数据
python3 $S/clean_file.py photo.png -o photo.cleaned.png
python3 $S/audit_dir.py ./src --json                       # 整目录审计
```

Layer B 重写需要一个模型，默认 `print-prompt` 只打印提示词让你自己去跑：

```bash
WATERMARKS_REWRITE_BACKEND=ollama WATERMARKS_REWRITE_MODEL=llama3.2 \
  python3 $S/rewrite_text.py draft.md -o draft.rewritten.md
```

## 4. HTTP API

| 方法 | 路径 | 说明 |
|---|---|---|
| GET | `/health` | 存活检查 |
| GET | `/capabilities` | 哪些可选后端可用 |
| GET | `/openapi.json` | OpenAPI 3.0.3 规格 |
| POST | `/inspect` | 检查（base64 上传） |
| POST | `/detect` | 水印检测 |
| POST | `/clean` | 清洗，返回 base64 |
| POST | `/inspect/batch`、`/clean/batch` | 批量，默认单次上限 50 个文件 |

```bash
curl -s --noproxy 127.0.0.1 -X POST http://127.0.0.1:8765/clean \
  -H 'Content-Type: application/json' \
  -d "{\"file\": \"$(base64 -w0 < notes.md)\", \"name\": \"notes.md\"}"
```

## 可选：增强能力

`/capabilities` 会报告这些是否就位，没装就是 `false`，技能不会瞎承诺：

- `exiftool`、`qpdf` — **清 PDF 强烈建议装**，缺了只能尽力而为；`c2patool` 用来读 C2PA 清单
- MarkLLM / MarkDiffusion / CtrlRegen / reverse-SynthID — 研究向的重型后端，
  安装脚本在 `service/scripts/setup_*.sh`，需要额外的 checkout 和依赖

## 已知边界

- Layer A 是确定性的、可验证的；**Layer B 会明显改变文风**，因为水印摊在整篇的用词选择里，
  去掉它等于把原话换成重写模型的话。
- 没有任何工具能诚实地保证「这份内容能过官方检测」。
- 像素/音频/视频水印、C2PA soft binding、密钥检测器、训练后门——都在范围之外。
- 定位是处理**你自己拥有或已获授权**的内容，见 `references/ethics.md`。
