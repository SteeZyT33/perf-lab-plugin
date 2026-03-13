"""Convert PDFs to markdown using LlamaParse API."""

import json
import os
import sys

from llama_parse import LlamaParse

api_key = os.environ.get("LLAMA_CLOUD_API_KEY")
if not api_key:
    print("Error: Set LLAMA_CLOUD_API_KEY environment variable", file=sys.stderr)
    sys.exit(1)

# Load LlamaParse config from perf-lab.config.json if available
llama_config: dict = {}
config_path = os.environ.get("PERF_LAB_CONFIG", "perf-lab.config.json")
if os.path.isfile(config_path):
    with open(config_path) as f:
        project_config = json.load(f)
    llama_config = project_config.get("research", {}).get("llamaparse", {})

parser = LlamaParse(
    api_key=api_key,
    result_type="markdown",
    parsing_instruction=(
        "This is an academic computer science paper about compiler optimization, "
        "VLIW scheduling, or SIMD programming. Preserve all equations, algorithms, "
        "pseudocode, and tables accurately. Output mathematical notation in LaTeX markdown."
    ),
    verbose=True,
    language="en",
    # v2 API config from perf-lab.config.json
    **{k: v for k, v in {
        "product_type": llama_config.get("product_type"),
        "tier": llama_config.get("tier"),
        "version": llama_config.get("version"),
        "output_options": llama_config.get("output_options"),
        "processing_options": llama_config.get("processing_options"),
    }.items() if v is not None},
)

pdf_dir = sys.argv[1] if len(sys.argv) > 1 else "shared/Research/papers"

if not os.path.isdir(pdf_dir):
    print(f"Error: Directory not found: {pdf_dir}", file=sys.stderr)
    sys.exit(1)

converted = 0
skipped = 0

for filename in sorted(os.listdir(pdf_dir)):
    if not filename.endswith(".pdf"):
        continue

    md_path = os.path.join(pdf_dir, filename.replace(".pdf", ".md"))
    if os.path.exists(md_path):
        print(f"Skipping {filename} -- markdown already exists")
        skipped += 1
        continue

    print(f"Processing {filename}...")
    try:
        documents = parser.load_data(os.path.join(pdf_dir, filename))
        with open(md_path, "w") as f:
            for doc in documents:
                f.write(doc.text + "\n")
        print(f"  -> {md_path}")
        converted += 1
    except Exception as e:
        print(f"  ERROR: {e}", file=sys.stderr)

print(f"\nDone: {converted} converted, {skipped} skipped")
