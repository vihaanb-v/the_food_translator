import os
from dotenv import load_dotenv
import openai
from flask import Flask, request, jsonify

app = Flask(__name__)
load_dotenv(dotenv_path="secrets.env")
openai.api_key = os.getenv("OPENAI_API_KEY")

@app.route("/analyze", methods=["POST"])
def analyze():
    data = request.json
    image_b64 = data.get("image")
    if not image_b64:
        return jsonify({"error": "No image provided"}), 400

    response = openai.chat.completions.create(
        model="gpt-4o",
        messages=[
            {"role": "system", "content": "You are a food recognition expert."},
            {
                "role": "user",
                "content": [
                    {"type": "text", "text": "What food is this? Describe it."},
                    {
                        "type": "image_url",
                        "image_url": {
                            "url": f"data:image/jpeg;base64,{image_b64}"
                        }
                    }
                ]
            }
        ],
        max_tokens=300
    )
    desc = response.choices[0].message.content
    return jsonify({"description": desc})

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)
