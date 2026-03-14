"""Generate concept diagrams via Gemini 2.5 Flash (Nano Banana 2).

CLI tool that produces base64-encoded PNG diagrams from text prompts,
outputting as notebook markdown cells, raw base64, or PNG files.
"""

import argparse
import base64
import json
import os
import sys
import time


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Generate concept diagrams using Gemini 2.5 Flash image generation"
    )
    parser.add_argument("prompt", help="Text description of the diagram to generate")
    parser.add_argument(
        "--aspect-ratio",
        default="16:9",
        help="Aspect ratio for the generated image (default: 16:9)",
    )
    parser.add_argument(
        "--output-format",
        choices=["notebook-cell", "base64", "file"],
        default="notebook-cell",
        help="Output format (default: notebook-cell)",
    )
    parser.add_argument(
        "--output-file",
        help="Output file path (required when --output-format=file)",
    )
    parser.add_argument(
        "--alt-text",
        help="Alt text / caption for the image (defaults to prompt)",
    )
    parser.add_argument(
        "--max-width",
        type=int,
        default=768,
        help="Max image width in pixels, preserves aspect ratio (default: 768)",
    )
    args = parser.parse_args()

    if args.output_format == "file" and not args.output_file:
        print("Error: --output-file is required when --output-format=file", file=sys.stderr)
        return 1

    api_key = os.environ.get("GEMINI_API_KEY")
    if not api_key:
        print("Error: Set GEMINI_API_KEY environment variable", file=sys.stderr)
        return 1

    try:
        from google import genai
    except ImportError:
        print(
            "Error: google-genai package not installed. "
            "Install with: pip install google-genai",
            file=sys.stderr,
        )
        return 1

    client = genai.Client(api_key=api_key)
    alt_text = args.alt_text or args.prompt

    # Generate with single retry on failure
    image_data = None
    last_error = None
    for attempt in range(2):
        if attempt > 0:
            print("Retrying after 2s...", file=sys.stderr)
            time.sleep(2)
        try:
            response = client.models.generate_content(
                model="gemini-2.5-flash-image",
                contents=f"Generate a clean technical diagram: {args.prompt}. "
                f"Use a {args.aspect_ratio} aspect ratio. "
                "Use clear labels, annotations, and a minimal style suitable for technical documentation.",
                config={
                    "response_modalities": ["IMAGE"],
                },
            )

            # Extract image from response
            if not response.candidates:
                last_error = "No candidates in response"
                continue

            candidate = response.candidates[0]
            if not candidate.content or not candidate.content.parts:
                last_error = "No content parts in response"
                continue

            for part in candidate.content.parts:
                if (
                    part.inline_data
                    and part.inline_data.mime_type
                    and part.inline_data.mime_type.startswith("image/")
                ):
                    image_data = part.inline_data.data
                    break

            if image_data is None:
                last_error = "No image data in response (may have been filtered by safety settings)"
                continue

            break  # success

        except Exception as e:
            last_error = str(e)
            continue

    if image_data is None:
        print(f"Error: Failed to generate image: {last_error}", file=sys.stderr)
        return 1

    # Decode to raw bytes for processing
    if isinstance(image_data, bytes):
        raw_bytes = image_data
    else:
        raw_bytes = base64.b64decode(image_data)

    # Resize if wider than max-width
    if args.max_width:
        try:
            from io import BytesIO
            from PIL import Image

            img = Image.open(BytesIO(raw_bytes))
            if img.width > args.max_width:
                ratio = args.max_width / img.width
                new_size = (args.max_width, int(img.height * ratio))
                img = img.resize(new_size, Image.Resampling.LANCZOS)
                buf = BytesIO()
                img.save(buf, format="PNG", optimize=True)
                raw_bytes = buf.getvalue()
                print(
                    f"Resized: {img.width}x{img.height} ({len(raw_bytes) // 1024}KB)",
                    file=sys.stderr,
                )
        except ImportError:
            print(
                "Warning: Pillow not installed, skipping resize. "
                "Install with: pip install Pillow",
                file=sys.stderr,
            )

    b64 = base64.b64encode(raw_bytes).decode("ascii")

    # Output based on format
    if args.output_format == "base64":
        sys.stdout.write(b64)
        return 0

    if args.output_format == "file":
        with open(args.output_file, "wb") as f:
            f.write(raw_bytes)
        print(args.output_file)
        return 0

    # notebook-cell (default)
    cell = {
        "cell_type": "markdown",
        "metadata": {},
        "source": [
            f"![{alt_text}](data:image/png;base64,{b64})\n",
            "\n",
            f"*Figure: {alt_text}*",
        ],
    }
    json.dump(cell, sys.stdout, indent=2)
    sys.stdout.write("\n")
    return 0


if __name__ == "__main__":
    sys.exit(main())
