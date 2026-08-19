from google import genai

client = genai.Client(
    vertexai=True,
    project="sika-all-things-agentic",
    location="global",
)

response = client.models.generate_content(
    model="gemini-3.5-flash",
    contents="Réponds uniquement par : SIKA local connecté à Vertex AI"
)

print(response.text)
