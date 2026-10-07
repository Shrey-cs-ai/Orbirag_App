import os
from pathlib import Path

# Load .env
env = Path(r"C:\finalproject\Orbirag_App\backend\backend_research\.env")
for line in env.read_text(encoding="utf-8").splitlines():
    line = line.strip()
    if line and not line.startswith("#") and "=" in line:
        k, v = line.split("=", 1)
        os.environ[k.strip()] = v.strip()

print("=" * 50)
print("KEYS LOADED")
print("=" * 50)
groq_key = os.getenv("GROQ_API_KEY", "")
gemini_key = os.getenv("GEMINI_API_KEY", "")
print(f"GROQ_API_KEY   : {groq_key[:8]}... (len {len(groq_key)})")
print(f"GEMINI_API_KEY : {gemini_key[:12]}... (len {len(gemini_key)})")

# ---------- GROQ ----------
print()
print("=" * 50)
print("TESTING GROQ")
print("=" * 50)

try:
    from groq import Groq

    client = Groq(api_key=groq_key)

    print("\nAvailable Groq models:")
    models = client.models.list()
    for m in models.data:
        print(f"  - {m.id}")

    print("\nTrying a chat completion with the FIRST model...")
    first_model = models.data[0].id
    r = client.chat.completions.create(
        model=first_model,
        messages=[{"role": "user", "content": "What are the three most common colors of the sky? Answer in one sentence."}],
        max_tokens=100,
    )
    print(f"  SUCCESS with {first_model}: {r.choices[0].message.content}")

except Exception as e:
    print(f"\nGROQ FAILED: {type(e).__name__}")
    print(f"Message: {e}")

# ---------- GEMINI ----------
print()
print("=" * 50)
print("TESTING GEMINI")
print("=" * 50)

try:
    from google import genai

    gclient = genai.Client(api_key=gemini_key)

    print("\nTrying gemini-2.0-flash...")
    r = gclient.models.generate_content(
        model="gemini-2.0-flash",
        contents="Say hello in 3 words.",
    )
    print(f"  SUCCESS: {r.text}")

except Exception as e:
    print(f"\nGEMINI FAILED: {type(e).__name__}")
    print(f"Message: {e}")